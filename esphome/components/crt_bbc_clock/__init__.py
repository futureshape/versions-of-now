import esphome.codegen as cg
from esphome.components import esp32, time
import esphome.config_validation as cv
from esphome.const import CONF_ID
from esphome.core import CORE

DEPENDENCIES = ["esp32"]
AUTO_LOAD = ["time"]

CONF_TIME_ID = "time_id"

crt_bbc_clock_ns = cg.esphome_ns.namespace("crt_bbc_clock")
CrtBbcClock = crt_bbc_clock_ns.class_("CrtBbcClock", cg.Component)

CONFIG_SCHEMA = cv.Schema(
    {
        cv.GenerateID(): cv.declare_id(CrtBbcClock),
        cv.Required(CONF_TIME_ID): cv.use_id(time.RealTimeClock),
    }
).extend(cv.COMPONENT_SCHEMA)


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await cg.register_component(var, config)

    time_var = await cg.get_variable(config[CONF_TIME_ID])
    cg.add(var.set_time(time_var))

    component_path = CORE.relative_config_path("components/esp32_composite_video_lib")
    esp32.add_idf_component(name="esp32_composite_video_lib", path=component_path)
    esp32.include_builtin_idf_component("driver")
    esp32.include_builtin_idf_component("esp_driver_dac")
    esp32.include_builtin_idf_component("esp_driver_i2s")

    esp32.add_idf_sdkconfig_option("CONFIG_VIDEO_ENABLE_LVGL_SUPPORT", False)
    esp32.add_idf_sdkconfig_option("CONFIG_VIDEO_DIAG_DISPLAY_TEST_FUNC", True)
    esp32.add_idf_sdkconfig_option("CONFIG_VIDEO_DIAG_ENABLE_INTERRUPT_STATS", False)
    esp32.add_idf_sdkconfig_option("CONFIG_VIDEO_ENABLE_DIAG_PIN", False)
