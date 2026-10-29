package smartfox.crossbyte;

import haxe.io.Bytes;

/** Incremental, bounded frame reader. Works across split headers and joined frames. */
class PacketReader {
    final framing:PacketFraming;
    final header:Bytes = Bytes.alloc(5);
    var headerUsed:Int = 0;
    var headerSize:Int = 0;
    var body:Bytes;
    var bodyUsed:Int = 0;

    public function new(framing:PacketFraming) this.framing = framing;

    public function reset():Void {
        headerUsed = headerSize = bodyUsed = 0;
        body = null;
    }

    public function push(chunk:Bytes):Array<SmartFoxPacket> {
        if (chunk == null) throw "Missing packet bytes";
        var result:Array<SmartFoxPacket> = [];
        var at = 0;
        try {
            while (at < chunk.length) {
                if (headerUsed == 0) {
                    header.set(0, chunk.get(at++));
                    headerUsed = 1;
                    headerSize = (header.get(0) & framing.longLengthFlag) != 0 ? 5 : 3;
                }
                if (headerUsed < headerSize) {
                    var count = Std.int(Math.min(headerSize - headerUsed, chunk.length - at));
                    header.blit(headerUsed, chunk, at, count);
                    headerUsed += count;
                    at += count;
                    if (headerUsed < headerSize) break;
                }
                if (body == null) {
                    // Use Float while parsing the unsigned length: avoid Int overflow before the limit check.
                    var size:Float = 0.0;
                    for (i in 1...headerSize) size = size * 256.0 + header.get(i);
                    if (size > framing.maxFrameSize) throw "Incoming packet exceeds frame limit";
                    body = Bytes.alloc(Std.int(size));
                }
                var count = Std.int(Math.min(body.length - bodyUsed, chunk.length - at));
                body.blit(bodyUsed, chunk, at, count);
                bodyUsed += count;
                at += count;
                if (bodyUsed == body.length) {
                    result.push(new SmartFoxPacket(header.get(0), body));
                    reset();
                }
            }
        } catch (error:Dynamic) {
            reset();
            throw error;
        }
        return result;
    }
}
