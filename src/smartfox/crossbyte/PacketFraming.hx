package smartfox.crossbyte;

import haxe.io.Bytes;

/** One flag byte, then a big-endian unsigned 16- or 32-bit wire payload size. */
class PacketFraming {
    public final longLengthFlag:Int;
    public final maxFrameSize:Int;

    /** The SDK-specific long-length bit must be selected explicitly by the caller. */
    public function new(longLengthFlag:Int, maxFrameSize:Int = 8 * 1024 * 1024) {
        if (longLengthFlag <= 0 || longLengthFlag > 128 || (longLengthFlag & (longLengthFlag - 1)) != 0)
            throw "Long-length flag must be one header bit";
        if (maxFrameSize < 1 || maxFrameSize > 0x7ffffffa) throw "Frame limit must fit within a Haxe byte buffer";
        this.longLengthFlag = longLengthFlag;
        this.maxFrameSize = maxFrameSize;
    }

    public function encode(packet:SmartFoxPacket):Bytes {
        if (packet.flags < 0 || packet.flags > 255) throw "Packet flags must fit in one byte";
        if (packet.payload == null || packet.payload.length > maxFrameSize) throw "Packet exceeds frame limit";
        var flags = packet.flags & ~longLengthFlag;
        var longSize = packet.payload.length > 65535;
        if (longSize) flags |= longLengthFlag;
        var lengthBytes = longSize ? 4 : 2;
        var output = Bytes.alloc(1 + lengthBytes + packet.payload.length);
        output.set(0, flags);
        for (i in 0...lengthBytes)
            output.set(1 + i, (packet.payload.length >>> ((lengthBytes - 1 - i) * 8)) & 255);
        output.blit(1 + lengthBytes, packet.payload, 0, packet.payload.length);
        return output;
    }
}
