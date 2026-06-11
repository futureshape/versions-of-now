#include "pico_epaper_4in2_v2.h"

#include "esphome/core/application.h"
#include "esphome/core/hal.h"
#include "esphome/core/log.h"

namespace esphome {
namespace pico_epaper_4in2_v2 {

static const char *const TAG = "pico_epaper_4in2_v2";

void PicoEPaper4In2V2::setup() {
  this->init_internal_(BUFFER_LENGTH);
  if (this->buffer_ == nullptr) {
    this->mark_failed();
    return;
  }

  this->setup_pins_();
  if (this->is_failed()) {
    return;
  }

  this->spi_setup();
  this->initialize_();

  if (this->clear_on_setup_) {
    this->fill(display::COLOR_OFF);
    this->has_previous_frame_ = this->display_full_();
  }
}

void PicoEPaper4In2V2::setup_pins_() {
  if (this->dc_pin_ == nullptr || this->reset_pin_ == nullptr || this->busy_pin_ == nullptr) {
    ESP_LOGE(TAG, "DC, reset, and busy pins are required");
    this->mark_failed();
    return;
  }

  this->dc_pin_->setup();
  this->dc_pin_->digital_write(false);

  this->reset_pin_->setup();
  this->reset_pin_->digital_write(true);

  this->busy_pin_->setup();
}

float PicoEPaper4In2V2::get_setup_priority() const { return setup_priority::PROCESSOR; }

void PicoEPaper4In2V2::update() {
  if (this->buffer_ == nullptr) {
    ESP_LOGE(TAG, "Display buffer unavailable");
    return;
  }

  this->do_update_();

  if (this->full_refresh_next_ || !this->partial_refresh_ || !this->has_previous_frame_ || !this->has_partial_window_) {
    this->full_refresh_next_ = false;
    this->has_previous_frame_ = this->display_full_();
    return;
  }

  this->display_partial_();
}

void PicoEPaper4In2V2::dump_config() {
  LOG_DISPLAY("", "Pico ePaper 4.2in V2", this);
  ESP_LOGCONFIG(TAG, "  Driver: Waveshare EPD_4in2_V2 command sequence");
  ESP_LOGCONFIG(TAG, "  Partial Refresh: %s", YESNO(this->partial_refresh_));
  if (this->has_partial_window_) {
    ESP_LOGCONFIG(TAG, "  Partial Window: x=%u, y=%u, width=%u, height=%u", this->partial_window_.x,
                  this->partial_window_.y, this->partial_window_.width, this->partial_window_.height);
  }
  LOG_PIN("  CS Pin: ", this->cs_);
  LOG_PIN("  DC Pin: ", this->dc_pin_);
  LOG_PIN("  Reset Pin: ", this->reset_pin_);
  LOG_PIN("  Busy Pin: ", this->busy_pin_);
  LOG_UPDATE_INTERVAL(this);
}

void PicoEPaper4In2V2::on_safe_shutdown() { this->deep_sleep_(); }

void PicoEPaper4In2V2::fill(Color color) {
  if (this->buffer_ == nullptr) {
    return;
  }

  if (this->get_clipping().is_set()) {
    display::Display::fill(color);
    return;
  }

  const uint8_t fill = color.is_on() ? 0x00 : 0xFF;
  for (uint32_t i = 0; i < BUFFER_LENGTH; i++) {
    this->buffer_[i] = fill;
  }
}

void PicoEPaper4In2V2::draw_absolute_pixel_internal(int x, int y, Color color) {
  if (this->buffer_ == nullptr || x < 0 || y < 0 || x >= WIDTH || y >= HEIGHT) {
    return;
  }

  const uint32_t pos = (x + y * WIDTH) / 8u;
  const uint8_t bit = 0x80 >> (x & 0x07);
  if (color.is_on()) {
    this->buffer_[pos] &= ~bit;
  } else {
    this->buffer_[pos] |= bit;
  }
}

void PicoEPaper4In2V2::reset_() {
  this->reset_pin_->digital_write(true);
  delay(100);
  this->reset_pin_->digital_write(false);
  delay(2);
  this->reset_pin_->digital_write(true);
  delay(100);
}

bool PicoEPaper4In2V2::wait_until_idle_() {
  const uint32_t start = millis();
  while (this->busy_pin_->digital_read()) {
    if (millis() - start > IDLE_TIMEOUT_MS) {
      ESP_LOGE(TAG, "Timeout waiting for display busy pin to release");
      return false;
    }
    delay(10);
    App.feed_wdt();
  }
  return true;
}

void PicoEPaper4In2V2::initialize_() {
  this->reset_();

  this->wait_until_idle_();
  this->send_command_(0x12);  // SWRESET
  this->wait_until_idle_();

  this->send_command_(0x21);  // Display update control
  this->send_data_(0x40);
  this->send_data_(0x00);

  this->send_command_(0x3C);  // Border waveform
  this->send_data_(0x05);

  this->send_command_(0x11);  // Data entry mode
  this->send_data_(0x03);     // X and Y increment

  this->set_window_(0, 0, WIDTH - 1, HEIGHT - 1);
  this->set_cursor_(0, 0);

  this->wait_until_idle_();
}

bool PicoEPaper4In2V2::display_full_() {
  if (this->buffer_ == nullptr) {
    ESP_LOGE(TAG, "Display buffer unavailable");
    return false;
  }

  this->send_command_(0x21);  // Display update control
  this->send_data_(0x40);
  this->send_data_(0x00);

  this->send_command_(0x3C);  // Border waveform
  this->send_data_(0x05);

  this->send_command_(0x11);  // Data entry mode
  this->send_data_(0x03);

  this->set_window_(0, 0, WIDTH - 1, HEIGHT - 1);
  this->set_cursor_(0, 0);

  this->send_command_(0x24);
  this->send_data_buffer_(this->buffer_, BUFFER_LENGTH);

  this->send_command_(0x26);
  this->send_data_buffer_(this->buffer_, BUFFER_LENGTH);

  return this->turn_on_display_();
}

bool PicoEPaper4In2V2::display_partial_() {
  if (this->buffer_ == nullptr) {
    ESP_LOGE(TAG, "Display buffer unavailable");
    return false;
  }

  const uint16_t x_start = this->partial_window_.x;
  const uint16_t y_start = this->partial_window_.y;
  const uint16_t x_end = x_start + this->partial_window_.width - 1;
  const uint16_t y_end = y_start + this->partial_window_.height - 1;
  const uint16_t start_byte_x = x_start / 8;
  const uint16_t width_bytes = this->partial_window_.width / 8;

  this->send_command_(0x3C);  // Border waveform for partial refresh
  this->send_data_(0x80);

  this->send_command_(0x21);  // Display update control
  this->send_data_(0x00);
  this->send_data_(0x00);

  this->send_command_(0x3C);  // Waveshare sends this again before the partial RAM window.
  this->send_data_(0x80);

  this->set_window_(x_start, y_start, x_end, y_end);
  this->set_cursor_(x_start, y_start);

  this->send_command_(0x24);
  this->start_data_();
  for (uint16_t y = y_start; y <= y_end; y++) {
    const uint32_t offset = y * BYTES_PER_ROW + start_byte_x;
    this->write_array(this->buffer_ + offset, width_bytes);
    App.feed_wdt();
  }
  this->end_data_();

  return this->turn_on_display_partial_();
}

bool PicoEPaper4In2V2::turn_on_display_() {
  this->send_command_(0x22);
  this->send_data_(0xF7);
  this->send_command_(0x20);
  return this->wait_until_idle_();
}

bool PicoEPaper4In2V2::turn_on_display_partial_() {
  this->send_command_(0x22);
  this->send_data_(0xFF);
  this->send_command_(0x20);
  return this->wait_until_idle_();
}

void PicoEPaper4In2V2::deep_sleep_() {
  if (this->is_failed()) {
    return;
  }
  this->send_command_(0x10);
  this->send_data_(0x01);
  delay(100);
}

void PicoEPaper4In2V2::set_window_(uint16_t x_start, uint16_t y_start, uint16_t x_end, uint16_t y_end) {
  this->send_command_(0x44);
  this->send_data_((x_start >> 3) & 0xFF);
  this->send_data_((x_end >> 3) & 0xFF);

  this->send_command_(0x45);
  this->send_data_(y_start & 0xFF);
  this->send_data_((y_start >> 8) & 0xFF);
  this->send_data_(y_end & 0xFF);
  this->send_data_((y_end >> 8) & 0xFF);
}

void PicoEPaper4In2V2::set_cursor_(uint16_t x_start, uint16_t y_start) {
  this->send_command_(0x4E);
  this->send_data_((x_start >> 3) & 0xFF);

  this->send_command_(0x4F);
  this->send_data_(y_start & 0xFF);
  this->send_data_((y_start >> 8) & 0xFF);
}

void PicoEPaper4In2V2::send_command_(uint8_t command) {
  this->dc_pin_->digital_write(false);
  this->enable();
  this->write_byte(command);
  this->disable();
}

void PicoEPaper4In2V2::send_data_(uint8_t data) {
  this->dc_pin_->digital_write(true);
  this->enable();
  this->write_byte(data);
  this->disable();
}

void PicoEPaper4In2V2::send_data_buffer_(const uint8_t *data, size_t length) {
  this->dc_pin_->digital_write(true);
  this->enable();
  this->write_array(data, length);
  this->disable();
}

void PicoEPaper4In2V2::start_data_() {
  this->dc_pin_->digital_write(true);
  this->enable();
}

void PicoEPaper4In2V2::end_data_() { this->disable(); }

}  // namespace pico_epaper_4in2_v2
}  // namespace esphome
