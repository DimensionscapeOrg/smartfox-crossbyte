package smartfox.crossbyte;

import haxe.io.Bytes;

/** Composes a transport with framed binary packets; owns that transport's callbacks. */
class SmartFoxConnection {
    public var onOpen:Void->Void = () -> {};
    public var onPacket:SmartFoxPacket->Void = _ -> {};
    public var onClose:(Int, String)->Void = (_, _) -> {};
    public var onError:String->Void = _ -> {};
    final transport:MessageTransport;
    final framing:PacketFraming;
    final reader:PacketReader;
    var generation:Int = 0;

    public function new(transport:MessageTransport, framing:PacketFraming) {
        this.transport = transport;
        this.framing = framing;
        reader = new PacketReader(framing);
    }

    public function connect(host:String, port:Int, secure:Bool = true):Void {
        generation++;
        reader.reset();
        transport.onOpen = () -> onOpen();
        transport.onClose = (code, reason) -> {
            generation++;
            reader.reset();
            onClose(code, reason);
        };
        transport.onError = error -> onError(error);
        transport.onMessage = received;
        transport.connect(host, port, secure);
    }

    function received(bytes:Bytes, text:Bool):Void {
        var packets:Array<SmartFoxPacket>;
        try {
            if (text) throw "SmartFox binary transport received a text frame";
            packets = reader.push(bytes);
        } catch (error:Dynamic) {
            generation++;
            reader.reset();
            transport.dispose();
            onError(Std.string(error));
            return;
        }
        var current = generation;
        for (packet in packets) {
            if (generation != current) break;
            onPacket(packet);
        }
    }

    public function send(packet:SmartFoxPacket):Void transport.sendBinary(framing.encode(packet));

    public function dispose():Void {
        generation++;
        reader.reset();
        transport.dispose();
        onOpen = () -> {};
        onPacket = _ -> {};
        onClose = (_, _) -> {};
        onError = _ -> {};
    }
}
