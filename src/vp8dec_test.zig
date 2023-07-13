const std = @import("std");
const testing = std.testing;
const IVF = @import("ivf.zig");
const VP8Dec = @import("vp8dec.zig").VP8Dec;

test "decode test" {
    const alc = std.heap.page_allocator;
    const input_file = "testfiles/sample01.ivf";
    const output_file = "testfiles/output.i420";

    var ivf_file = try std.fs.cwd().openFile(input_file, .{});
    defer ivf_file.close();

    var outfile = try std.fs.cwd().createFile(output_file, .{});
    defer outfile.close();
    try decode(alc, ivf_file, outfile);
}

test "decode test vp9" {
    const alc = std.heap.page_allocator;
    const input_file = "testfiles/sample02.ivf";
    const output_file = "testfiles/output2.i420";

    var ivf_file = try std.fs.cwd().openFile(input_file, .{});
    defer ivf_file.close();

    var outfile = try std.fs.cwd().createFile(output_file, .{});
    defer outfile.close();
    try decode(alc, ivf_file, outfile);
}

fn decode(alc: std.mem.Allocator, ivf_file: std.fs.File, outfile: std.fs.File) !void {
    var reader = try IVF.IVFReader.init(ivf_file);
    defer reader.deinit();

    try testing.expect(reader.header.width == 160);
    try testing.expect(reader.header.height == 120);
    try testing.expect(reader.header.framerate_num == 15);
    try testing.expect(reader.header.framerate_den == 1);
    try testing.expect(reader.header.num_frames == 75);

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
