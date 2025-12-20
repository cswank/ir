const std = @import("std");

pub const message = struct {
    address: u8,
    command: u8,
};

const nec_frames: []const []const u32 = &.{
    &.{9000},
    &.{4500},
    &.{563},
    &.{ 563, 1688 }, //if this pulse is close to 563 the current bit is zero, if close to 1688 the current bit is one.
};

pub const NEC = struct {
    tolerance: u32 = 100,
    val: u32 = 0,
    bit: u5 = 0,
    i: u3 = 0,

    pub fn put(self: *NEC, duration: u64) bool {
        const close = self.closeTo(@truncate(duration), nec_frames[self.i]);

        if (!close.success) {
            self.reset();
            return false;
        }

        if (self.i == 3) {
            self.val |= (close.mask << self.bit);
            if (self.bit == 31) {
                return true;
            }
            self.bit += 1;
        }

        self.i += 1;
        if (self.i == 4) {
            self.i = 2;
        }

        return false;
    }

    pub fn value(self: *NEC) !message {
        const addr: u8 = @truncate(self.val);
        const iaddr: u8 = @truncate(self.val >> 8);
        const cmd: u8 = @truncate(self.val >> 16);
        const icmd: u8 = @truncate(self.val >> 24);

        self.reset();

        if (addr != ~iaddr) {
            return error.InvalidAddress;
        }

        if (cmd != ~icmd) {
            return error.InvalidCommand;
        }

        return message{ .address = addr, .command = cmd };
    }

    fn reset(self: *NEC) void {
        self.val = 0;
        self.bit = 0;
        self.i = 0;
    }

    fn closeTo(self: *NEC, d: u32, vals: []const u32) struct { success: bool, mask: u32 } {
        for (vals, 0..) |val, index| {
            if ((d >= (val - self.tolerance)) and (d <= (val + self.tolerance))) {
                return .{ .success = true, .mask = @truncate(index) };
            }
        }
        return .{ .success = false, .mask = 0 };
    }
};

test "usage" {
    //                     [rubbish ] [start of valid signal ..]
    const pulses = [_]u32{ 33, 39631, 9038, 4481, 579, 1689, 580, 554, 582, 1686, 581, 554, 582, 1686, 580, 1689, 579, 556, 579, 554, 580, 555, 577, 1691, 579, 555, 579, 1689, 580, 554, 580, 555, 579, 1690, 579, 1690, 579, 555, 579, 557, 578, 557, 577, 557, 554, 580, 578, 557, 578, 1689, 579, 556, 579, 1689, 578, 1690, 580, 1689, 578, 1689, 580, 1688, 579, 1690, 577, 558, 577, 1692, 554, 39631 };

    var ir = NEC{ .tolerance = 50 };
    for (pulses, 0..) |_, i| {
        if (ir.put(pulses[i])) {
            break;
        }
    }

    const msg = try ir.value();
    std.debug.assert(msg.address == 0x35);
    std.debug.assert(msg.command == 0x40);
}
