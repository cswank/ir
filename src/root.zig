const std = @import("std");

const tolerance: u32 = 100;
const bit_mask: u64 = 1;

pub const message = struct {
    address: u8,
    command: u8,
};

const frames: []const []const u64 = &[_][]const u64{
    &[_]u64{9000},
    &[_]u64{4500},
    &[_]u64{563},
    &[_]u64{ 563, 1688 },
};

pub const NEC = struct {
    val: u64 = 0,
    i: u6 = 0,
    j: u3 = 0,

    pub fn put(self: *NEC, duration: u64) bool {
        const close = closeTo(duration, frames[self.j]);
        if (close.success) {
            if (self.j == 3) {
                if (close.i == 0) {
                    //this bit is already 0;
                } else {
                    self.val |= (bit_mask << self.i);
                }
                self.i += 1;
            }

            self.j += 1;
            if (self.j == 4) {
                self.j = 2;
            }
        } else {
            self.reset();
        }

        return self.i == 32;
    }

    pub fn value(self: *NEC) !message {
        const addr: u8 = @truncate(self.val);
        const iaddr: u8 = @truncate(self.val >> 8);
        const cmd: u8 = @truncate(self.val >> 16);
        const icmd: u8 = @truncate(self.val >> 24);

        self.reset();

        if (addr != ~iaddr) {
            return error.Invalid;
        }

        if (cmd != ~icmd) {
            return error.Invalid;
        }

        return message{ .address = addr, .command = cmd };
    }

    fn reset(self: *NEC) void {
        self.val = 0;
        self.i = 0;
        self.j = 0;
    }
};

fn closeTo(d: u64, vals: []const u64) struct { success: bool, i: usize } {
    for (vals, 0..) |val, index| {
        if ((d >= (val - tolerance)) and (d <= (val + tolerance))) {
            return .{ .success = true, .i = index };
        }
    }
    return .{ .success = false, .i = 0 };
}

test "usage" {
    const pulses = [_]u64{ 39631, 9038, 4481, 579, 1689, 580, 554, 582, 1686, 581, 554, 582, 1686, 580, 1689, 579, 556, 579, 554, 580, 555, 577, 1691, 579, 555, 579, 1689, 580, 554, 580, 555, 579, 1690, 579, 1690, 579, 555, 579, 557, 578, 557, 577, 557, 554, 580, 578, 557, 578, 1689, 579, 556, 579, 1689, 578, 1690, 580, 1689, 578, 1689, 580, 1688, 579, 1690, 577, 558, 577, 1692, 554, 39631 };
    var ir = NEC{};
    for (pulses, 0..) |_, i| {
        if (ir.put(pulses[i])) {
            break;
        }
    }
    const msg = try ir.value();
    std.debug.assert(msg.address == 0x35);
    std.debug.assert(msg.command == 0x40);
}
