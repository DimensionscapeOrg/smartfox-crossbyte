package smartfox.crossbyte;

import crossbyte.events.Event;
import crossbyte.events.IOErrorEvent;
import crossbyte.events.WebSocketCloseEvent;
import crossbyte.events.WebSocketMessageEvent;
import crossbyte.io.ByteArray;
import crossbyte.net.WebSocket;
import haxe.io.Bytes;

/** Raw transport; SmartFox framing and the extension envelope belong above it. */
class CrossbyteWebSocketTransport implements MessageTransport {
    public var onOpen:Void->Void = () -> {};
    public var onMessage:(Bytes, Bool)->Void = (_, _) -> {};
    public var onClose:(Int, String)->Void = (_, _) -> {};
    public var onError:String->Void = _ -> {};
    var socket:WebSocket;

    public function new() {}

    public function connect(host:String, port:Int, secure:Bool):Void {
        disposeSocket();
        socket = new WebSocket();
        socket.secure = secure;
        socket.connectTimeout = 10;
        socket.addEventListener(Event.CONNECT, opened);
        socket.addEventListener(WebSocketMessageEvent.MESSAGE, received);
        socket.addEventListener(Event.CLOSE, closed);
        socket.addEventListener(IOErrorEvent.IO_ERROR, failed);
        try {
            socket.connect(host, port);
        } catch (error:Dynamic) {
            detach(socket);
            socket = null;
            throw error;
        }
    }

    function opened(_):Void onOpen();

    function received(event:WebSocketMessageEvent):Void {
        // Crossbyte reuses event.data after this call. Give the client its own bytes.
        var borrowed:Bytes = event.data;
        onMessage(borrowed.sub(0, borrowed.length), event.isText);
    }

    function closed(event:Event):Void {
        var details:WebSocketCloseEvent = cast event;
        if (socket != null) detach(socket);
        socket = null;
        onClose(details.code, details.reason);
    }
    function failed(event:IOErrorEvent):Void onError(event.text);

    public function sendBinary(bytes:Bytes):Void {
        requireOpen();
        socket.sendBinary(ByteArray.fromBytes(bytes));
    }

    public function sendText(text:String):Void {
        requireOpen();
        socket.sendText(text);
    }

    function requireOpen():Void {
        if (socket == null || !socket.connected) throw "WebSocket is not connected";
    }

    function disposeSocket():Void {
        if (socket == null) return;
        var previous = socket;
        socket = null;
        detach(previous);
        previous.close();
    }

    function detach(previous:WebSocket):Void {
        previous.removeEventListener(Event.CONNECT, opened);
        previous.removeEventListener(WebSocketMessageEvent.MESSAGE, received);
        previous.removeEventListener(Event.CLOSE, closed);
        previous.removeEventListener(IOErrorEvent.IO_ERROR, failed);
    }

    public function dispose():Void {
        disposeSocket();
        onOpen = () -> {};
        onMessage = (_, _) -> {};
        onClose = (_, _) -> {};
        onError = _ -> {};
    }
}
