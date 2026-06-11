from esphome import pins
import esphome.codegen as cg
from esphome.components import display, spi
import esphome.config_validation as cv
from esphome.const import (
    CONF_BUSY_PIN,
    CONF_DC_PIN,
    CONF_ID,
    CONF_LAMBDA,
    CONF_PAGES,
    CONF_RESET_PIN,
)

DEPENDENCIES = ["spi"]

CONF_CLEAR_ON_SETUP = "clear_on_setup"
CONF_PARTIAL_REFRESH = "partial_refresh"
CONF_PARTIAL_WINDOW = "partial_window"
CONF_X = "x"
CONF_Y = "y"
CONF_WIDTH = "width"
CONF_HEIGHT = "height"

pico_epaper_4in2_v2_ns = cg.esphome_ns.namespace("pico_epaper_4in2_v2")
PicoEPaper4In2V2 = pico_epaper_4in2_v2_ns.class_(
    "PicoEPaper4In2V2",
    cg.PollingComponent,
    spi.SPIDevice,
    display.DisplayBuffer,
)


def validate_partial_window(config):
    if config[CONF_X] % 8 != 0:
        raise cv.Invalid("partial_window x must be divisible by 8")
    if config[CONF_WIDTH] % 8 != 0:
        raise cv.Invalid("partial_window width must be divisible by 8")
    if config[CONF_X] + config[CONF_WIDTH] > 400:
        raise cv.Invalid("partial_window must fit within the 400 pixel display width")
    if config[CONF_Y] + config[CONF_HEIGHT] > 300:
        raise cv.Invalid("partial_window must fit within the 300 pixel display height")
    return config


PARTIAL_WINDOW_SCHEMA = cv.All(
    cv.Schema(
        {
            cv.Required(CONF_X): cv.int_range(min=0, max=399),
            cv.Required(CONF_Y): cv.int_range(min=0, max=299),
            cv.Required(CONF_WIDTH): cv.int_range(min=8, max=400),
            cv.Required(CONF_HEIGHT): cv.int_range(min=1, max=300),
        }
    ),
    validate_partial_window,
)

CONFIG_SCHEMA = cv.All(
    display.FULL_DISPLAY_SCHEMA.extend(
        {
            cv.GenerateID(): cv.declare_id(PicoEPaper4In2V2),
            cv.Required(CONF_DC_PIN): pins.gpio_output_pin_schema,
            cv.Required(CONF_RESET_PIN): pins.gpio_output_pin_schema,
            cv.Required(CONF_BUSY_PIN): pins.gpio_input_pin_schema,
            cv.Optional(CONF_CLEAR_ON_SETUP, default=False): cv.boolean,
            cv.Optional(CONF_PARTIAL_REFRESH, default=True): cv.boolean,
            cv.Optional(CONF_PARTIAL_WINDOW): PARTIAL_WINDOW_SCHEMA,
        }
    )
    .extend(cv.polling_component_schema("never"))
    .extend(spi.spi_device_schema()),
    cv.has_at_most_one_key(CONF_PAGES, CONF_LAMBDA),
)

FINAL_VALIDATE_SCHEMA = spi.final_validate_device_schema(
    "pico_epaper_4in2_v2", require_miso=False, require_mosi=True
)


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await display.register_display(var, config)
    await spi.register_spi_device(var, config, write_only=True)

    dc = await cg.gpio_pin_expression(config[CONF_DC_PIN])
    cg.add(var.set_dc_pin(dc))

    reset = await cg.gpio_pin_expression(config[CONF_RESET_PIN])
    cg.add(var.set_reset_pin(reset))

    busy = await cg.gpio_pin_expression(config[CONF_BUSY_PIN])
    cg.add(var.set_busy_pin(busy))

    cg.add(var.set_clear_on_setup(config[CONF_CLEAR_ON_SETUP]))
    cg.add(var.set_partial_refresh(config[CONF_PARTIAL_REFRESH]))
    if CONF_PARTIAL_WINDOW in config:
        window = config[CONF_PARTIAL_WINDOW]
        cg.add(
            var.set_partial_window(
                window[CONF_X],
                window[CONF_Y],
                window[CONF_WIDTH],
                window[CONF_HEIGHT],
            )
        )

    if CONF_LAMBDA in config:
        lambda_ = await cg.process_lambda(
            config[CONF_LAMBDA], [(display.DisplayRef, "it")], return_type=cg.void
        )
        cg.add(var.set_writer(lambda_))
