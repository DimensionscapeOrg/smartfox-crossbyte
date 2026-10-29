# smartfox-crossbyte

Haxe adapter package for Crossbyte-backed SmartFox clients. Provides WebSocket transport, configurable packet framing, and connection lifecycle management without a rendering framework dependency.

## API

- `MessageTransport`: replaceable text/binary transport with owned message bytes.
- `CrossbyteWebSocketTransport`: native Crossbyte WebSocket implementation, connection/error/close events, listener cleanup and copies of borrowed buffers.
- `PacketFraming` / `PacketReader`: flag byte plus big-endian 16/32-bit length fields, incremental parsing across chunks, configurable long-length bit, default 8 MiB wire-payload limit.
- `SmartFoxConnection`: composes binary transport and framing, delivers owned packets, resets partial frames between sessions, and releases the transport on malformed input.

Flags and payload bytes remain opaque. Compression, transport encryption, SFSObject/SFSArray serialization, controller dispatch, handshake/login, room/user models, and game extension envelopes are not implemented here. This is a transport/framing adapter, not a complete SmartFox SDK. Only native Windows has been integration-tested; TCP/UDP transports are not included.

## Consume

Install from haxelib and add `-lib smartfox-crossbyte` to your build:

```sh
haxelib install smartfox-crossbyte
```

To use the Git checkout instead:

```sh
haxelib git smartfox-crossbyte https://github.com/DimensionscapeOrg/smartfox-crossbyte.git
```

The package declares Crossbyte as its dependency.

The host must initialize Crossbyte before connecting. A Graphaxe/Lime host owns a Crossbyte `HostApplication` and calls `advance(deltaSeconds, 0.0)` once per frame. This package does not create a runtime or take over the main loop. Native builds require the hxcpp fork supported by Crossbyte.

```haxe
import smartfox.crossbyte.CrossbyteWebSocketTransport;
import smartfox.crossbyte.PacketFraming;
import smartfox.crossbyte.SmartFoxConnection;

// Example dialect: select this bit from the SDK/protocol you are adapting.
var connection = new SmartFoxConnection(new CrossbyteWebSocketTransport(), new PacketFraming(0x20));
connection.onPacket = packet -> decodePayload(packet.flags, packet.payload);
connection.onError = message -> reportError(message);
connection.connect("your-server.example/websocket", 8443, true);
// Send pre-serialized protocol bytes with connection.send(new SmartFoxPacket(flags, bytes)).
// Dispose the connection before shutting down the host runtime.
```

`SmartFoxConnection` owns its transport's callbacks. Callbacks run on the runtime thread; payload bytes can be retained after delivery. Disposing/reconnecting inside a callback suppresses remaining packets from the prior session. Text frames are a protocol error for the framed connection, though the raw transport supports them.

The long-length flag is required explicitly. Select it from the SDK/protocol being adapted, since header bits and WebSocket framing can differ between versions. This package does not decompress or decrypt flagged bytes; a decompression layer must separately bound its output.

## Validation

Run `haxe test.hxml` from this package directory. Checks cover fixed wire vectors, split headers/bodies, combined frames, empty payloads, 65,535/65,536-byte lengths, oversized/unsigned-overflow lengths, alternate dialect bits, parser reset, reconnect, error cleanup, and disposal from callbacks.

Native Windows integration checks also cover loopback WebSocket I/O with small and 65,536-byte framed payloads, retained buffers, remote close, and host-driven timers. WSS/TLS and game-server login are not covered by those checks.
