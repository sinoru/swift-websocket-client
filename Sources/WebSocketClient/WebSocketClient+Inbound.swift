//
//  WebSocketClient+Inbound.swift
//
//
//  Created by Jaehong Kang on 7/12/24.
//

import NIOCore
import NIOWebSocket

extension WebSocketClient.Response {
    init(_ webSocketFrame: WebSocketFrame) {
        switch webSocketFrame.opcode {
        case .text:
            var data = webSocketFrame.unmaskedData
            guard let string = data.readString(length: data.readableBytes) else {
                self.init(
                    data: .binary(.init(webSocketFrame.unmaskedData.readableBytesView)),
                    frame: webSocketFrame
                )
                return
            }

            self.init(
                data: .text(string),
                frame: webSocketFrame
            )
        case .binary:
            self.init(
                data: .binary(.init(webSocketFrame.unmaskedData.readableBytesView)),
                frame: webSocketFrame
            )
        case .connectionClose:
            var data = webSocketFrame.unmaskedData
            let closeCode = WebSocketClient.CloseCode(rawValue: data.readInteger(as: UInt16.self) ?? 0)

            self.init(
                data: .close(closeCode),
                frame: webSocketFrame
            )
        default:
            self.init(data: nil, frame: webSocketFrame)
        }
    }
}

extension WebSocketClient {
    public struct Inbound: AsyncSequence {
        public typealias AsyncIterator = AsyncMapSequence<NIOAsyncChannelInboundStream<WebSocketFrame>, WebSocketClient.Response>.Iterator
        public typealias Element = Response

        let asyncChannelInboundStream: NIOAsyncChannelInboundStream<WebSocketFrame>

        public func makeAsyncIterator() -> AsyncIterator {
            asyncChannelInboundStream
                .map { Response($0) }
                .makeAsyncIterator()
        }
    }
}
