const std = @import("std");
const microzig = @import("microzig");
const ir = @import("ir");
const rp2040 = microzig.hal;
const time = rp2040.time;

const pin_config = rp2040.pins.GlobalConfiguration{
    .GPIO16 = .{ .name = "pwm", .function = .PWM0_A },
    .GPIO25 = .{ .name = "led", .direction = .out },
};

const pins = pin_config.pins();
const led = pins.led;
const pwm = pins.pwm;

pub fn main() !void {
    pin_config.apply();

    // For 38kHz:
    // System clock is 125MHz
    // PWM frequency = 125MHz / (DIV * (WRAP + 1))
    // For 38kHz: 125000000 / 38000 ≈ 3289.47
    // Using DIV=1.0, WRAP=3288 gives ~38.02kHz

    const top: u16 = 3288;
    const slice = pwm.slice();
    slice.set_clk_div(1, 0);
    slice.set_wrap(top);
    pwm.set_level(top / 2); // 50% duty cycle

    var packet: [67]u32 = undefined;
    var nec = ir.NEC{};
    nec.generate(ir.message{ .address = 0x04, .command = 0x08 }, &packet);

    var toggle: u16 = 0;
    while (true) {
        slice.enable();
        led.toggle();
        toggle = 0;
        for (packet) |duration| {
            toggle = 1 - toggle;
            pwm.set_level((top / 2) * toggle);
            time.sleep_us(duration);
        }

        slice.disable();
        time.sleep_ms(5000);
    }
}
