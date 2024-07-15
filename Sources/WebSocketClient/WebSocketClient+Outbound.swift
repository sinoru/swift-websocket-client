//
//  WebSocketClient+Outbound.swift
//
//
//  Created by Jaehong Kang on 7/12/24.
//

import NIOCore
import NIOWebSocket

extension WebSocketClient.CloseCode {
    var webSocketErrorCode: WebSocketErrorCode {
        .init(codeNumber: Int(self.rawValue))
    }
}

extension ByteBuffer {
    init(_ webSocketData: WebSocketClient.Data) {
        switch webSocketData {
        case .ping(let string):
            self.init(string: string)
        case .text(let string):
            self.init(string: string)
        case .binary(let data):
            self.init(bytes: data)
        case .close(let closeCode):
            self.init()
            write(webSocketErrorCode: closeCode.webSocketErrorCode)
        }
    }
}

extension WebSocketFrame {
    init(_ webSocketData: WebSocketClient.Data) {
        self.init(
            fin: true,
            opcode: {
                switch webSocketData {
                case .ping:
                    return .ping
                case .text:
                    return .text
                case .binary:
                    return .binary
                case .close:
                    return .connectionClose
                }
            }(),
            maskKey: .random(),
            data: ByteBuffer(webSocketData)
        )
    }
}

extension WebSocketClient {
    public struct Outbound: Sendable {
        private let asyncChannelOutboundWriter: NIOAsyncChannelOutboundWriter<WebSocketFrame>

        init(asyncChannelOutboundWriter: NIOAsyncChannelOutboundWriter<WebSocketFrame>) {
            self.asyncChannelOutboundWriter = asyncChannelOutboundWriter
        }

        public func write(_ data: Data) async throws {
            try await asyncChannelOutboundWriter.write(WebSocketFrame(data))
        }

        public func write<Writes: Sequence>(contentsOf sequence: Writes) async throws where Writes.Element == Data {
            try await asyncChannelOutboundWriter.write(contentsOf: sequence.map { WebSocketFrame($0) })
        }

        public func write<Writes: AsyncSequence>(contentsOf sequence: Writes) async throws where Writes.Element == Data {
            try await asyncChannelOutboundWriter.write(contentsOf: sequence.map { WebSocketFrame($0) })
        }
    }
}
