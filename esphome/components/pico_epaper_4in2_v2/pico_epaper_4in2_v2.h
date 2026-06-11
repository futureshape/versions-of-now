#pragma once

#include <cstddef>
#include <cstdint>

#include "esphome/components/display/display_buffer.h"
#include "esphome/components/spi/spi.h"
#include "esphome/core/component.h"
#include "esphome/core/gpio.h"

namespace esphome {
namespace pico_epaper_4in2_v2 {

class PicoEPaper4In2V2 : public display::DisplayBuffer,
                          public spi::SPIDevice<spi::BIT_ORDER_MSB_FIRST, spi::CLOCK_POLARITY_LOW,
                                                spi::CLOCK_PHASE_LEADING, spi::DATA_RATE_2MHZ> {
 public:
  void set_dc_pin(GPIOPin *dc_pin) { this->dc_pin_ = dc_pin; }
  void set_reset_pin(GPIOPin *reset_pin) { this->reset_pin_ = reset_pin; }
  void set_busy_pin(GPIOPin *busy_pin) { this->busy_pin_ = busy_pin; }
  void set_clear_on_setup(bool clear_on_setup) { this->clear_on_setup_ = clear_on_setup; }
  void set_partial_refresh(bool partial_refresh) { this->partial_refresh_ = partial_refresh; }
  void set_full_refresh_next(bool full_refresh_next = true) { this->full_refresh_next_ = full_refresh_next; }
  void set_partial_window(uint16_t x, uint16_t y, uint16_t width, uint16_t height) {
    this->partial_window_.x = x;
    this->partial_window_.y = y;
    this->partial_window_.width = width;
    this->partial_window_.height = height;
    this->has_partial_window_ = true;
  }

  void setup() override;
  void update() override;
  void dump_config() override;
  void on_safe_shutdown() override;
  float get_setup_priority() const override;

  void fill(Color color) override;
  display::DisplayType get_display_type() override { return display::DisplayType::DISPLAY_TYPE_BINARY; }

 protected:
  static constexpr uint16_t WIDTH = 400;
  static constexpr uint16_t HEIGHT = 300;
  static constexpr uint16_t BYTES_PER_ROW = WIDTH / 8;
  static constexpr uint32_t BUFFER_LENGTH = WIDTH * HEIGHT / 8;
  static constexpr uint32_t IDLE_TIMEOUT_MS = 15000;

  struct PartialWindow {
    uint16_t x;
    uint16_t y;
    uint16_t width;
    uint16_t height;
  };

  int get_width_internal() override { return WIDTH; }
  int get_height_internal() override { return HEIGHT; }
  void draw_absolute_pixel_internal(int x, int y, Color color) override;

  GPIOPin *dc_pin_{nullptr};
  GPIOPin *reset_pin_{nullptr};
  GPIOPin *busy_pin_{nullptr};
  PartialWindow partial_window_{0, 0, WIDTH, HEIGHT};
  bool clear_on_setup_{false};
  bool partial_refresh_{true};
  bool full_refresh_next_{true};
  bool has_previous_frame_{false};
  bool has_partial_window_{false};

  void setup_pins_();
  void reset_();
  bool wait_until_idle_();
  void initialize_();
  bool display_full_();
  bool display_partial_();
  void deep_sleep_();
  bool turn_on_display_();
  bool turn_on_display_partial_();
  void set_window_(uint16_t x_start, uint16_t y_start, uint16_t x_end, uint16_t y_end);
  void set_cursor_(uint16_t x_start, uint16_t y_start);
  void send_command_(uint8_t command);
  void send_data_(uint8_t data);
  void send_data_buffer_(const uint8_t *data, size_t length);
  void start_data_();
  void end_data_();
};

}  // namespace pico_epaper_4in2_v2
}  // namespace esphome
