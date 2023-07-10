const std = @import("std");
const c = @cImport({
    @cInclude("vpx/vpx_decoder.h");
    @cInclude("vpx/vp8dx.h");
});

pub const VP8Dec = struct {
    codec: c.vpx_codec_ctx_t,
    iter: c.vpx_codec_iter_t,

    const Self = @This();

    pub fn init() !VP8Dec {
        //const iface = c.vpx_codec_vp8_dx();
        if (c.vpx_codec_vp8_dx()) |iface| {
            var codec: c.vpx_codec_ctx_t = undefined;
            const res = c.vpx_codec_dec_init(&codec, iface, null, 0);
            if (res != c.VPX_CODEC_OK) {
                return error.FailedToInitializeVp8Decoder;
            }
            return VP8Dec{ .codec = codec, .iter = null };
        } else {
            return error.Vp8DecoderInterface;
        }
    }

    pub fn deinit(self: *Self) void {
        _ = c.vpx_codec_destroy(&self.codec);
    }

    pub fn decode(self: *Self, frame_buffer: []u8) !void {
        const res = c.vpx_codec_decode(&self.codec, @ptrCast(frame_buffer.ptr), @intCast(frame_buffer.len), null, 0);
        if (res != c.VPX_CODEC_OK) {
            return error.FailedToDecodeFrame;
        }
        self.iter = null;
    }

    pub fn getFrame(self: *Self) ?*c.vpx_image_t {
        return c.vpx_codec_get_frame(&self.codec, &self.iter);
    }
};
