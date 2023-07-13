const std = @import("std");
const testing = std.testing;
const IVF = @import("ivf.zig");
const VP8Dec = @import("vp8dec.zig").VP8Dec;

pub fn decode(alc: std.mem.Allocator, input_file: []const u8, output_file: []const u8, width: u32, height: u32) !void {
    var ivf_file = try std.fs.cwd().openFile(input_file, .{});
    defer ivf_file.close();

    var outfile = try std.fs.cwd().createFile(output_file, .{});
    defer outfile.close();

    var reader = try IVF.IVFReader.init(ivf_file);
    defer reader.deinit();

    try testing.expectEqualSlices(u8, &reader.header.fourcc, "VP80");
    try testing.expect(reader.header.width == width);
    try testing.expect(reader.header.height == height);

    var frame_index: usize = 0;
    var frame_buffer = try alc.alloc(u8, 0);
    defer alc.free(frame_buffer);
    var vp8dec = try VP8Dec.init(&reader.header.fourcc);
    defer vp8dec.deinit();

    while (true) {
        var ivf_frame_header: IVF.IVFFrameHeader = undefined;
        reader.readIVFFrameHeader(&ivf_frame_header) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        const frame_size = ivf_frame_header.frame_size;
        try testing.expect(ivf_frame_header.timestamp == frame_index);
        if (frame_buffer.len < frame_size) {
            frame_buffer = try alc.realloc(frame_buffer, frame_size);
        }
        _ = try reader.readFrame(frame_buffer[0..frame_size]);
        try vp8dec.decode(frame_buffer[0..frame_size]);
        while (vp8dec.getFrame()) |img| {
            var ptr = img.planes[0];
            for (0..img.d_h) |_| {
                try outfile.writeAll(ptr[0..img.d_w]);
                ptr += @as(usize, @intCast(img.stride[0]));
            }
            ptr = img.planes[1];
            for (0..(img.d_h / 2)) |_| {
                try outfile.writeAll(ptr[0..(img.d_w / 2)]);
                ptr += @as(usize, @intCast(img.stride[1]));
            }
            ptr = img.planes[2];
            for (0..(img.d_h / 2)) |_| {
                try outfile.writeAll(ptr[0..(img.d_w / 2)]);
                ptr += @as(usize, @intCast(img.stride[2]));
            }

            frame_index += 1;
        }
    }
}

pub fn main() !void {
    const usage = "Usage: {s} input_file output_file width height\n";
    const alc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alc);
    defer std.process.argsFree(alc, args);

    if (args.len < 4) {
        std.debug.print(usage, .{args[0]});
        std.os.exit(1);
    }
    const input_file = args[1];
    const output_file = args[2];
    const width = try std.fmt.parseInt(u32, args[3], 10);
    const height = try std.fmt.parseInt(u32, args[4], 10);
    decode(alc, input_file, output_file, width, height) catch |err| {
        if (err != error.BrokenPipe) {
            return err;
        }
    };
}
