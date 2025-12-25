const std = @import("std");
const microzig = @import("microzig");
const ir = @import("ir");
const rp2040 = microzig.hal;
const rptime = rp2040.time;
const gpio = rp2040.gpio;
const pwm = rp2040.pwm;

const pin_config = rp2040.pins.GlobalConfiguration{
    .GPIO16 = .{ .name = "gpio16", .function = .PWM0_A },
};

const pins = pin_config.pins();

pub fn main() !void {
    pin_config.apply();

    // For 38kHz:
    // System clock is 125MHz
    // PWM frequency = 125MHz / (DIV * (WRAP + 1))
    // For 38kHz: 125000000 / 38000 ≈ 3289.47
    // Using DIV=1.0, WRAP=3288 gives ~38.02kHz

    const div_int: u8 = 1;
    const div_frac: u8 = 0;
    const top: u16 = 3288;

    const slice = pins.gpio16.slice();
    slice.set_clk_div(div_int, div_frac);
    slice.set_wrap(top);
    pins.gpio16.set_level(top / 2); // 50% duty cycle

    var packet: [66]u32 = undefined;
    var nec = ir.NEC{};
    nec.generate(ir.message{ .address = 0x16, .command = 0x04 }, &packet);

    while (true) {
        for (packet, 0..) |duration, i| {
            if (i % 2 == 0) {
                slice.enable();
            } else {
                slice.disable();
            }
            rptime.sleep_us(duration);
        }

        rptime.sleep_ms(2000);
    }
}
