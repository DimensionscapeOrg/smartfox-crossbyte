import haxe.io.Bytes;
import smartfox.crossbyte.MessageTransport;
import smartfox.crossbyte.PacketFraming;
import smartfox.crossbyte.PacketReader;
import smartfox.crossbyte.SmartFoxConnection;
import smartfox.crossbyte.SmartFoxPacket;

class PacketTests {
    static function expect(value:Bool, message:String):Void {
        if (!value) throw message;
    }

    static function rejected(action:Void->Void):Void {
        var failed = false;
        try action() catch (_:Dynamic) failed = true;
        expect(failed, "Expected rejection");
    }

    static function joined(a:Bytes, b:Bytes):Bytes {
        var output = Bytes.alloc(a.length + b.length);
        output.blit(0, a, 0, a.length);
        output.blit(a.length, b, 0, b.length);
        return output;
    }

    static function main():Void {
        try run() catch (error:Dynamic) {
            Sys.println(Std.string(error));
            Sys.println(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            Sys.exit(1);
        }
    }

    static function run():Void {
        Sys.println("Checking short frames");
        var framing = new PacketFraming(0x20, 100000);
        // Fixed, independently spelled wire vectors: flags + big-endian size + payload.
        expect(framing.encode(new SmartFoxPacket(0x10, Bytes.ofHex("000001"))).toHex() == "100003000001", "Small wire vector");
        expect(framing.encode(new SmartFoxPacket(0x80, Bytes.ofHex("aabb"))).toHex() == "800002aabb", "Opaque compression flag");
        expect(framing.encode(new SmartFoxPacket(0x20, Bytes.alloc(0))).toHex() == "000000", "Normalize long flag on empty body");
        var small = Bytes.ofHex("100003000001");
        for (split in 0...small.length + 1) {
            var reader = new PacketReader(framing);
            var packets = reader.push(small.sub(0, split)).concat(reader.push(small.sub(split, small.length - split)));
            expect(packets.length == 1 && packets[0].flags == 0x10 && packets[0].payload.toHex() == "000001", 'Split at $split');
        }
        var reader = new PacketReader(framing);
        Sys.println("Checking byte-by-byte and joined frames");
        var bytePackets = [];
        for (i in 0...small.length) bytePackets = bytePackets.concat(reader.push(small.sub(i, 1)));
        expect(bytePackets.length == 1, "Byte-by-byte assembly");
        var packets = reader.push(joined(small, small));
        expect(packets.length == 2, "Coalesced frames");
        reader.push(small.sub(0, 4));
        reader.reset();
        expect(reader.push(small).length == 1, "Reset discards partial frame");
        for (size in [65535, 65536]) {
            Sys.println('Checking length $size');
            var payload = Bytes.alloc(size);
            for (i in 0...size) payload.set(i, i & 255);
            var encoded = framing.encode(new SmartFoxPacket(0x40, payload));
            var prefix = size == 65535 ? "40ffff" : "6000010000";
            expect(encoded.sub(0, prefix.length >> 1).toHex() == prefix, "Length boundary header");
            reader.reset();
            var output:Array<SmartFoxPacket> = [];
            var at = 0;
            while (at < encoded.length) {
                var count = Std.int(Math.min(17, encoded.length - at));
                output = output.concat(reader.push(encoded.sub(at, count)));
                at += count;
            }
            expect(output.length == 1 && output[0].payload.compare(payload) == 0, "Long fragmented payload");
        }
        Sys.println("Checking rejected lengths");
        rejected(() -> reader.push(Bytes.ofHex("20ffffffff")));
        rejected(() -> reader.push(Bytes.ofHex("20000186a1")));
        expect(reader.push(small).length == 1, "Reset after invalid header");
        rejected(() -> framing.encode(new SmartFoxPacket(256, Bytes.alloc(1))));
        rejected(() -> framing.encode(new SmartFoxPacket(0, Bytes.alloc(100001))));
        rejected(() -> new PacketFraming(3));
        var otherLayout = new PacketFraming(0x08, 100000);
        expect(otherLayout.encode(new SmartFoxPacket(0, Bytes.alloc(65536))).get(0) == 8, "Caller selects dialect");

        var transport = new TestTransport();
        Sys.println("Checking connection lifecycle");
        var connection = new SmartFoxConnection(transport, framing);
        var errors = 0;
        var delivered = 0;
        connection.onError = _ -> errors++;
        connection.onPacket = _ -> delivered++;
        connection.connect("localhost/smartfox", 8080, false);
        transport.onMessage(small.sub(0, 4), false);
        transport.onClose(1000, "closed");
        connection.connect("localhost/smartfox", 8080, false);
        transport.onMessage(small, false);
        expect(delivered == 1, "Reconnect resets partial frame");
        transport.onMessage(Bytes.ofString("invalid text"), true);
        expect(errors == 1 && transport.disposed, "Text frame reports protocol error and releases transport");
        connection.connect("localhost/smartfox", 8080, false);
        connection.onPacket = _ -> { delivered++; connection.dispose(); };
        transport.onMessage(joined(small, small), false);
        expect(delivered == 2, "Dispose from callback stops remaining packet delivery");
        trace("Packet framing and adapter lifecycle checks passed");
    }
}

private class TestTransport implements MessageTransport {
    public var onOpen:Void->Void = () -> {};
    public var onMessage:(Bytes, Bool)->Void = (_, _) -> {};
    public var onClose:(Int, String)->Void = (_, _) -> {};
    public var onError:String->Void = _ -> {};
    public var disposed:Bool = false;
    public function new() {}
    public function connect(host:String, port:Int, secure:Bool):Void disposed = false;
    public function sendBinary(bytes:Bytes):Void {}
    public function sendText(text:String):Void {}
    public function dispose():Void disposed = true;
}
