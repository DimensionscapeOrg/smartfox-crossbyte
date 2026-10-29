package smartfox.crossbyte;

import haxe.io.Bytes;

/** Flags and wire payload remain opaque; codecs above this layer interpret them. */
class SmartFoxPacket {
    public final flags:Int;
    public final payload:Bytes;

    public function new(flags:Int, payload:Bytes) {
        this.flags = flags;
        this.payload = payload;
    }
}
