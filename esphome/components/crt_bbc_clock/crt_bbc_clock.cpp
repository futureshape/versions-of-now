#include "crt_bbc_clock.h"

#include <algorithm>
#include <cmath>

#include "esphome/core/hal.h"
#include "esphome/core/log.h"

namespace esphome {
namespace crt_bbc_clock {

static const char *const TAG = "crt_bbc_clock";

static constexpr float SOURCE_CENTER_X = 960.0f;
static constexpr float SOURCE_CENTER_Y = 383.0f;
static constexpr float PI_F = 3.14159265358979323846f;

void CrtBbcClock::setup() {
  ESP_LOGCONFIG(TAG, "Starting composite video output on ESP32 GPIO25 DAC");
  if (this->time_ != nullptr && this->time_->now().is_valid()) {
    this->start_clock_output_();
  } else {
    this->show_waiting_pattern_();
  }
}

void CrtBbcClock::loop() {
  if (!this->clock_started_) {
    if (this->time_ != nullptr && this->time_->now().is_valid())
      this->start_clock_output_();
    return;
  }

  const uint32_t now_ms = millis();
  if (now_ms - this->last_render_ms_ < 40)
    return;

  video_wait_frame();
  const uint32_t render_ms = millis();
  this->last_render_ms_ = render_ms;
  this->render_(render_ms);
}

void CrtBbcClock::dump_config() {
  ESP_LOGCONFIG(TAG, "CRT BBC Clock:");
  ESP_LOGCONFIG(TAG, "  Video: PAL 384x288 1bpp composite");
  ESP_LOGCONFIG(TAG, "  Output: ESP32 GPIO25 DAC through composite video circuit");
}

float CrtBbcClock::get_setup_priority() const { return setup_priority::HARDWARE; }

int16_t CrtBbcClock::sx(float source_x) const { return (int16_t) std::lround((source_x - SOURCE_VIEW_X) * SOURCE_SCALE_X); }

int16_t CrtBbcClock::sy(float source_y) const { return (int16_t) std::lround((source_y - SOURCE_VIEW_Y) * SOURCE_SCALE_Y); }

void CrtBbcClock::render_(uint32_t now_ms) {
  if (this->frame_buffer_words_ == nullptr)
    return;

  int hour = 12;
  int minute = 0;
  int second = 0;
  const uint16_t millisecond = now_ms % 1000;

  if (this->time_ != nullptr) {
    auto now = this->time_->now();
    if (now.is_valid()) {
      hour = now.hour;
      minute = now.minute;
      second = now.second;
    } else if (!this->logged_time_wait_) {
      ESP_LOGI(TAG, "Waiting for shared NTP time; rendering noon placeholder");
      this->logged_time_wait_ = true;
    }
  }

  this->clear_();
  this->draw_markers_();
  this->draw_hands_(hour, minute, second, millisecond);
  this->fill_circle_(this->sx(SOURCE_CENTER_X), this->sy(SOURCE_CENTER_Y), this->sx(SOURCE_CENTER_X + 53) - this->sx(SOURCE_CENTER_X), true);
  this->fill_circle_(this->sx(SOURCE_CENTER_X), this->sy(SOURCE_CENTER_Y), this->sx(SOURCE_CENTER_X + 41) - this->sx(SOURCE_CENTER_X), false);
  this->fill_rect_(0, this->sy(713), WIDTH, std::max<int16_t>(1, this->sy(727) - this->sy(713)), true);
  this->draw_logo_();
}

void CrtBbcClock::show_waiting_pattern_() {
  ESP_LOGI(TAG, "Waiting for shared NTP time; showing PAL 384x288 PM5544 test pattern");
  video_test_pal(VIDEO_TEST_PM5544);
  this->frame_buffer_words_ = nullptr;
  this->clock_started_ = false;
  this->logged_time_wait_ = true;
}

void CrtBbcClock::start_clock_output_() {
  ESP_LOGI(TAG, "Shared NTP time is valid; switching to CRT BBC clock");
  video_graphics(PAL_384x288, FB_FORMAT_GREY_1BPP);
  this->frame_buffer_words_ = reinterpret_cast<uint32_t *>(video_get_frame_buffer_address());
  this->clock_started_ = true;
  this->last_render_ms_ = millis();
  this->clear_();
  this->render_(this->last_render_ms_);
}

void CrtBbcClock::clear_() {
  for (uint32_t i = 0; i < FRAME_BUFFER_WORDS; i++)
    this->frame_buffer_words_[i] = 0;
}

void CrtBbcClock::set_pixel_(int16_t x, int16_t y, bool on) {
  if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT)
    return;

  const uint32_t offset = y * WORDS_PER_LINE + x / 32;
  const uint32_t mask = 1UL << (31 - (x & 31));
  if (on) {
    this->frame_buffer_words_[offset] |= mask;
  } else {
    this->frame_buffer_words_[offset] &= ~mask;
  }
}

void CrtBbcClock::fill_rect_(int16_t x, int16_t y, int16_t width, int16_t height, bool on) {
  for (int16_t yy = y; yy < y + height; yy++) {
    for (int16_t xx = x; xx < x + width; xx++)
      this->set_pixel_(xx, yy, on);
  }
}

void CrtBbcClock::fill_circle_(int16_t cx, int16_t cy, int16_t radius, bool on) {
  const int16_t radius_sq = radius * radius;
  for (int16_t y = cy - radius; y <= cy + radius; y++) {
    for (int16_t x = cx - radius; x <= cx + radius; x++) {
      const int16_t dx = x - cx;
      const int16_t dy = y - cy;
      if (dx * dx + dy * dy <= radius_sq)
        this->set_pixel_(x, y, on);
    }
  }
}

void CrtBbcClock::fill_polygon_(const Point *points, uint8_t count, bool on) {
  if (count < 3)
    return;

  int16_t min_y = points[0].y;
  int16_t max_y = points[0].y;
  for (uint8_t i = 1; i < count; i++) {
    min_y = std::min(min_y, points[i].y);
    max_y = std::max(max_y, points[i].y);
  }

  int16_t nodes[8];
  for (int16_t y = min_y; y <= max_y; y++) {
    uint8_t node_count = 0;
    uint8_t j = count - 1;
    for (uint8_t i = 0; i < count; i++) {
      const Point &pi = points[i];
      const Point &pj = points[j];
      if ((pi.y < y && pj.y >= y) || (pj.y < y && pi.y >= y)) {
        nodes[node_count++] = pi.x + (int32_t) (y - pi.y) * (pj.x - pi.x) / (pj.y - pi.y);
      }
      j = i;
    }

    for (uint8_t i = 1; i < node_count; i++) {
      const int16_t value = nodes[i];
      int8_t scan = i - 1;
      while (scan >= 0 && nodes[scan] > value) {
        nodes[scan + 1] = nodes[scan];
        scan--;
      }
      nodes[scan + 1] = value;
    }

    for (uint8_t i = 0; i + 1 < node_count; i += 2) {
      for (int16_t x = nodes[i]; x <= nodes[i + 1]; x++)
        this->set_pixel_(x, y, on);
    }
  }
}

void CrtBbcClock::fill_rotated_rect_(float source_x1, float source_y1, float source_x2, float source_y2, float degrees,
                                     bool on) {
  const float radians = degrees * PI_F / 180.0f;
  const float cs = std::cos(radians);
  const float sn = std::sin(radians);
  const float source_points[4][2] = {
      {source_x1, source_y1},
      {source_x2, source_y1},
      {source_x2, source_y2},
      {source_x1, source_y2},
  };
  Point points[4];

  for (uint8_t i = 0; i < 4; i++) {
    const float dx = source_points[i][0] - SOURCE_CENTER_X;
    const float dy = source_points[i][1] - SOURCE_CENTER_Y;
    const float rx = SOURCE_CENTER_X + dx * cs - dy * sn;
    const float ry = SOURCE_CENTER_Y + dx * sn + dy * cs;
    points[i] = Point{this->sx(rx), this->sy(ry)};
  }

  this->fill_polygon_(points, 4, on);
}

void CrtBbcClock::draw_markers_() {
  for (uint8_t hour = 1; hour <= 12; hour++) {
    const float angle = hour * 30.0f;
    const float thickness = 4.0f + hour * 1.65f;
    const float gap = 7.0f + hour * 0.45f;

    for (int8_t side = -1; side <= 1; side += 2) {
      const float x1 = SOURCE_CENTER_X + side * (gap + thickness) / 2.0f - thickness / 2.0f;
      this->fill_rotated_rect_(x1, 106.0f, x1 + thickness, 179.0f, angle, true);
    }
  }
}

void CrtBbcClock::draw_hands_(int hour, int minute, int second, uint16_t millisecond) {
  const int twelve_hour = hour % 12;
  const float second_angle = 6.0f * second + this->second_tick_offset_(millisecond);
  const float minute_angle = 6.0f * minute + 0.1f * second;
  const float hour_angle = 30.0f * twelve_hour + minute / 2.0f + second / 120.0f;

  this->fill_rotated_rect_(950.0f, 177.127f, 970.0f, 383.0f, hour_angle, true);
  this->fill_rotated_rect_(952.0f, 103.0f, 968.0f, 383.0f, minute_angle, true);
  this->fill_rotated_rect_(955.0f, 104.02f, 965.0f, 490.0f, second_angle, true);
}

void CrtBbcClock::draw_logo_() {
  struct Tile {
    char glyph;
    uint8_t width;
    uint8_t gap_after;
    uint8_t glyph_width;
    uint8_t scale_x;
  };

  // The 20-unit shear and 79-unit height mirror the 1969 BBC 1 rhombus tiles.
  static constexpr Tile TILES[] = {
      {'E', 76, 14, 5, 3},
      {'M', 88, 14, 7, 3},
      {'F', 76, 44, 5, 3},
      {'2', 76, 14, 5, 3},
      {'6', 76, 0, 5, 3},
  };
  static constexpr uint16_t MARK_WIDTH = 498;
  static constexpr float MARK_X = SOURCE_CENTER_X - MARK_WIDTH / 2.0f;
  static constexpr float MARK_Y = 794.0f;
  static constexpr float TILE_HEIGHT = 79.0f;
  static constexpr float TILE_SLANT = 20.0f;

  float cursor = 0.0f;
  for (const auto &tile : TILES) {
    Point box[4] = {
        {this->sx(MARK_X + cursor + TILE_SLANT), this->sy(MARK_Y)},
        {this->sx(MARK_X + cursor + tile.width + TILE_SLANT), this->sy(MARK_Y)},
        {this->sx(MARK_X + cursor + tile.width), this->sy(MARK_Y + TILE_HEIGHT)},
        {this->sx(MARK_X + cursor), this->sy(MARK_Y + TILE_HEIGHT)},
    };
    this->fill_polygon_(box, 4, true);

    const int16_t tile_x = this->sx(MARK_X + cursor);
    const int16_t tile_y = this->sy(MARK_Y);
    const int16_t tile_width = this->sx(MARK_X + cursor + tile.width + TILE_SLANT) - tile_x;
    const int16_t glyph_pixel_width = tile.glyph_width * tile.scale_x + 6;
    const int16_t glyph_x = tile_x + (tile_width - glyph_pixel_width) / 2;
    const int16_t glyph_y = tile_y + 2;
    this->draw_glyph_(tile.glyph, glyph_x, glyph_y, tile.scale_x, 3, false);

    cursor += tile.width + tile.gap_after;
  }
}

void CrtBbcClock::draw_glyph_(char glyph, int16_t x, int16_t y, uint8_t scale_x, uint8_t scale_y, bool on) {
  struct Glyph {
    char id;
    uint8_t width;
    uint8_t rows[7];
  };

  static constexpr Glyph GLYPHS[] = {
      {'E', 5, {0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111}},
      {'M', 7, {0b1000001, 0b1100011, 0b1010101, 0b1001001, 0b1000001, 0b1000001, 0b1000001}},
      {'F', 5, {0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000}},
      {'2', 5, {0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111}},
      {'6', 5, {0b01110, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110}},
  };

  const Glyph *selected = nullptr;
  for (const auto &candidate : GLYPHS) {
    if (candidate.id == glyph) {
      selected = &candidate;
      break;
    }
  }
  if (selected == nullptr)
    return;

  for (uint8_t row = 0; row < 7; row++) {
    const int16_t italic_shift = (6 - row);
    for (uint8_t col = 0; col < selected->width; col++) {
      const uint8_t mask = 1U << (selected->width - 1 - col);
      if (selected->rows[row] & mask) {
        this->fill_rect_(x + italic_shift + col * scale_x, y + row * scale_y, scale_x, scale_y, on);
      }
    }
  }
}

float CrtBbcClock::second_tick_offset_(uint16_t millisecond) const {
  static constexpr float OFFSETS[] = {-5.915291132f, -3.512368126f, -1.292272628f, 0.751891177f,
                                      -0.493091273f, 0.258782998f,  -0.247417696f};
  if (millisecond >= 280)
    return 0.0f;
  return OFFSETS[millisecond / 40];
}

}  // namespace crt_bbc_clock
}  // namespace esphome
