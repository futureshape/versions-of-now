#pragma once

#include <cstdint>

#include "esphome/components/time/real_time_clock.h"
#include "esphome/core/component.h"

extern "C" {
#include "video.h"
}

namespace esphome {
namespace crt_bbc_clock {

class CrtBbcClock : public Component {
 public:
  void set_time(time::RealTimeClock *time) { this->time_ = time; }

  void setup() override;
  void loop() override;
  void dump_config() override;
  float get_setup_priority() const override;

 protected:
  struct Point {
    int16_t x;
    int16_t y;
  };

  static constexpr uint16_t WIDTH = 384;
  static constexpr uint16_t HEIGHT = 288;
  static constexpr uint16_t WORDS_PER_LINE = WIDTH / 32;
  static constexpr uint32_t FRAME_BUFFER_WORDS = WORDS_PER_LINE * HEIGHT;
  static constexpr uint16_t SOURCE_VIEW_X = 360;
  static constexpr uint16_t SOURCE_VIEW_Y = 40;
  static constexpr float SOURCE_SCALE_X = WIDTH / 1200.0f;
  static constexpr float SOURCE_SCALE_Y = HEIGHT / 900.0f;

  time::RealTimeClock *time_{nullptr};
  uint32_t *frame_buffer_words_{nullptr};
  uint32_t last_render_ms_{0};
  int last_second_{-1};
  bool logged_time_wait_{false};
  bool clock_started_{false};

  int16_t sx(float source_x) const;
  int16_t sy(float source_y) const;

  void render_(uint32_t now_ms);
  void show_waiting_pattern_();
  void start_clock_output_();
  void clear_();
  void set_pixel_(int16_t x, int16_t y, bool on);
  void fill_rect_(int16_t x, int16_t y, int16_t width, int16_t height, bool on);
  void fill_circle_(int16_t cx, int16_t cy, int16_t radius, bool on);
  void fill_polygon_(const Point *points, uint8_t count, bool on);
  void fill_rotated_rect_(float source_x1, float source_y1, float source_x2, float source_y2, float degrees, bool on);
  void draw_markers_();
  void draw_hands_(int hour, int minute, int second, uint16_t millisecond);
  void draw_logo_();
  void draw_glyph_(char glyph, int16_t x, int16_t y, uint8_t scale_x, uint8_t scale_y, bool on);
  float second_tick_offset_(uint16_t millisecond) const;
};

}  // namespace crt_bbc_clock
}  // namespace esphome
