package smartfox.crossbyte;

import haxe.io.Bytes;

/** Message boundaries are preserved. Callbacks receive owned, retainable bytes. */
interface MessageTransport {
    public var onOpen:Void->Void;
    public var onMessage:(Bytes, Bool)->Void;
    public var onClose:(Int, String)->Void;
    public var onError:String->Void;
    public function connect(host:String, port:Int, secure:Bool):Void;
    public function sendBinary(bytes:Bytes):Void;
    public function sendText(text:String):Void;
    public function dispose():Void;
}
