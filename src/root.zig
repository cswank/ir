const std = @import("std");

const tolerance: u32 = 100;

const frame1: u32 = 9000;
const frame2: u32 = 4500;
const bitStart: u32 = 563;
const bitOne: u32 = 1688;
const bitMask: u64 = 1;

pub const message = struct {
    address: u8,
    command: u8,
};

pub const IR = struct {
    val: u64 = 0,
    i: u6 = 0,
    prev: u64 = 0,
    state: u2 = 0,

    pub fn put(self: *IR, duration: u64) bool {
        switch (self.state) {
            0 => {
                if (closeTo(duration, frame1)) {
                    self.state += 1;
                }
            },
            1 => {
                if (closeTo(duration, frame2)) {
                    self.state += 1;
                } else {
                    self.state = 0;
                    self.i = 0;
                    self.val = 0;
                }
            },
            2 => {
                if (closeTo(duration, bitStart)) {
                    self.state += 1;
                } else {
                    self.state = 0;
                    self.i = 0;
                    self.val = 0;
                }
            },
            3 => {
                if (closeTo(duration, bitStart)) {
                    //this bit is already zero
                    self.i += 1;
                    self.state = 2;
                } else if (closeTo(duration, bitOne)) {
                    self.val |= (bitMask << self.i);
                    self.i += 1;
                    self.state = 2;
                } else {
                    self.state = 0;
                    self.i = 0;
                    self.val = 0;
                }
            },
        }

        return self.i == 32;
    }

    pub fn value(self: *IR) !message {
        const addr: u8 = @truncate(self.val);
        const iaddr: u8 = @truncate(self.val >> 8);
        const cmd: u8 = @truncate(self.val >> 16);
        const icmd: u8 = @truncate(self.val >> 24);

        self.val = 0;
        self.i = 0;
        self.state = 0;

        if (addr != ~iaddr) {
            return error.Invalid;
        }

        if (cmd != ~icmd) {
            return error.Invalid;
        }

        return message{ .address = addr, .command = cmd };
    }
};

fn closeTo(d: u64, val: u64) bool {
    return (d >= (val - tolerance)) and (d <= (val + tolerance));
}

test "usage" {
    const pulses = [_]u64{ 39631, 9038, 4481, 579, 1689, 580, 554, 582, 1686, 581, 554, 582, 1686, 580, 1689, 579, 556, 579, 554, 580, 555, 577, 1691, 579, 555, 579, 1689, 580, 554, 580, 555, 579, 1690, 579, 1690, 579, 555, 579, 557, 578, 557, 577, 557, 554, 580, 578, 557, 578, 1689, 579, 556, 579, 1689, 578, 1690, 580, 1689, 578, 1689, 580, 1688, 579, 1690, 577, 558, 577, 1692, 554, 39631 };
    var ir = IR{};
    for (pulses, 0..) |_, i| {
        if (ir.put(pulses[i])) {
            break;
        }
    }
    const msg = try ir.value();
    std.debug.assert(msg.address == 0x35);
    std.debug.assert(msg.command == 0x40);
}
