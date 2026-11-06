// Copyright (c) 2026 Shubham LaV. All Rights Reserved.
//
// Email: lav@brainiacs.in
// GitHub: ShubhamLaV

const std = @import("std");

const zigimg = @import("zigimg");

const bitmaster = @import("bitmaster.zig");
const img_proc = @import("img_proc.zig");
const physics = @import("physics.zig");

const Allocator = std.mem.Allocator;

pub const AnimationStatus = enum {
    playing,
    paused,
    none,
};

pub const AppState = struct {
    // Image specific
    img: ?zigimg.Image = null,
    img_w: u32,
    img_h: u32,
    edge_bitmask: ?bitmaster.BitSet = null,
    max_img_len: u32 = 400,

    // Particles specific
    particles: ?physics.ParticleSystem = null,
    particle_count: u32,
    edge_tolerance: u8 = 220,
    dist_delta_sq: f32 = 10.0,
    neighbors_map: ?bitmaster.NeighborMap = null,
    radius: u32 = 2,

    // UI config
    show_outline: bool = false,
    anim_status: AnimationStatus = .none,
    footer_msg: ?[:0]const u8 = null, // TODO: move this out

    // Non-UI App config
    canvas_w: u32,
    canvas_h: u32,
    fps: u8 = 30,

    const Self = @This();

    pub fn init(canvas_w: u32, canvas_h: u32, particle_count: u32) Self {
        return .{
            .canvas_w = canvas_w,
            .canvas_h = canvas_h,
            .particle_count = particle_count,
            .img_w = undefined,
            .img_h = undefined,
        };
    }

    pub fn loadResizedImage(self: *Self, allocator: Allocator, io: std.Io, path: []const u8) img_proc.Error!void {
        var image = img_proc.loadImage(allocator, io, path) catch |err| switch (err) {
            img_proc.LoadError.Unsupported,
            img_proc.LoadError.FileNotFound,
            img_proc.LoadError.AccessDenied,
            img_proc.LoadError.OutOfMemory,
            => {
                return err;
            },
            else => return img_proc.LoadError.Failed,
        }; // will be deinited after potential resizing

        if (image.width != image.height) {
            var len: usize = undefined;
            var x: usize = undefined;
            var y: usize = undefined;

            if (image.width < image.height) {
                len = image.width;
                x = 0;
                y = (image.height - len) / 2;
            } else {
                len = image.height;
                x = (image.width - len) / 2;
                y = 0;
            }

            const cropped_img = try image.crop(allocator, .{
                .x = x,
                .y = y,
                .width = len,
                .height = len,
            });
            image.deinit(allocator);
            image = cropped_img;
        }

        // NOTE: IMAGE WILL BE SQUARE FROM HERE ONWARDS

        if (image.width > self.max_img_len) {
            const new_w: usize = self.max_img_len;
            const new_h: usize = new_w;

            const resized_img = try img_proc.resizeSmall(allocator, &image, new_w, new_h);
            image.deinit(allocator);
            image = resized_img;
        }

        self.img = image;
        self.img_w = @intCast(self.img.?.width);
        self.img_h = @intCast(self.img.?.height);
    }

    pub fn loadNeighbors(self: *Self, allocator: Allocator) img_proc.LoadError!void {
        var bitmask = try img_proc.edgeFilteredBitmask(allocator, &self.img.?, self.edge_tolerance);
        errdefer bitmask.deinit(allocator);

        if (bitmask.count() == 0) {
            return img_proc.LoadError.NoEdges;
        }

        const neighbors_map: bitmaster.NeighborMap = try .initAndFill(
            allocator,
            bitmask,
            self.img_w,
            self.img_h,
            self.radius,
        );
        self.edge_bitmask = bitmask;
        self.neighbors_map = neighbors_map;
    }

    pub fn loadParticles(self: *Self, allocator: Allocator, rng: std.Random) Allocator.Error!void {
        const particle_system: physics.ParticleSystem = try .init(allocator, rng, self);
        self.particles = particle_system;
    }

    /// Attempts to unload the particles' system.
    ///
    /// Safe to call even if no particle system is loaded.
    pub fn unloadParticles(self: *Self, allocator: Allocator) void {
        if (self.particles) |*p| {
            p.deinit(allocator);
            self.particles = null;
        }
    }

    pub fn unloadEdgeBitmask(self: *Self, allocator: Allocator) void {
        if (self.edge_bitmask) |*b| {
            b.deinit(allocator);
            self.edge_bitmask = null;
        }
    }

    /// Attempts to unload an image.
    ///
    /// Safe to call even if no image is loaded.
    pub fn unloadImage(self: *Self, allocator: Allocator) void {
        if (self.img) |*img| {
            img.deinit(allocator);
            self.img = null;
        }
    }

    pub fn unloadNeighbors(self: *Self, allocator: Allocator) void {
        if (self.neighbors_map) |*n| {
            n.deinit(allocator);
            self.neighbors_map = null;
        }
    }
};
