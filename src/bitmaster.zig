// Copyright (c) 2026 Shubham LaV. All Rights Reserved.
//
// Email: lav@brainiacs.in
// GitHub: ShubhamLaV

const std = @import("std");

pub const BitmaskError = error{NoSetBit};
pub const BitSet = std.bit_set.Dynamic;

const Allocator = std.mem.Allocator;
const MapType = std.AutoHashMap(usize, BitSet);

pub const NeighborMap = struct {
    map: MapType,

    const Self = @This();

    pub fn initAndFill(allocator: Allocator, bitmask: BitSet, img_w: u32, img_h: u32, radius: u32) Allocator.Error!Self {
        // Get the neighbors of the set bits represented as another bitmask
        var neighbor_map: MapType = .init(allocator);
        try neighbor_map.ensureTotalCapacity(@intCast(bitmask.count()));

        // If (x, y) is a set bit, then draw a square around it, all the set bits inside that
        // square is its neighbors.

        var iter = bitmask.iterator(.{ .kind = .set });
        while (iter.next()) |pixel_idx| {
            // TODO: make this be fetched from app_state.
            const dist_x = radius;
            const dist_y = radius;

            const pix_y = pixel_idx / img_w;
            const pix_x = pixel_idx % img_w;

            const min_x = if (dist_x >= pix_x) 0 else pix_x - dist_x;
            const max_x = @min(pix_x + dist_x, img_w - 1);

            const min_y = if (dist_y >= pix_y) 0 else pix_y - dist_y;
            const max_y = @min(pix_y + dist_y, img_h - 1);

            // Thanks to [lambda-abstraction on GitHub] aka [programming_enjoyer on Discord] for
            // fixing the left-bias bug in zig 0.15!
            var neighbor_bitmask: BitSet = try .initEmpty(allocator, img_w * img_h);
            for (min_y..max_y + 1) |y| {
                for (min_x..max_x + 1) |x| {
                    const idx = x + y * img_w;
                    if (idx != pixel_idx and bitmask.isSet(idx)) {
                        neighbor_bitmask.set(idx);
                    }
                }
            }

            neighbor_map.putAssumeCapacity(pixel_idx, neighbor_bitmask);
        }

        return .{ .map = neighbor_map };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        var map_iter = self.map.iterator();
        while (map_iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        self.map.deinit();
    }

    pub fn get(self: Self, key: usize) ?BitSet {
        return self.map.get(key);
    }
};

pub fn randomBitmaskIndex(rng: std.Random, bitmask: BitSet) BitmaskError!usize {
    if (bitmask.count() == 0) {
        return BitmaskError.NoSetBit;
    }

    const idx = rng.intRangeLessThan(usize, 0, bitmask.count());
    var iter = bitmask.iterator(.{ .kind = .set });
    for (0..idx) |_| {
        _ = iter.next();
    }

    return iter.next().?;
}
