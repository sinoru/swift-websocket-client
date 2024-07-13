//
//  WebSocketClient.Data+Context.swift
//
//
//  Created by Jaehong Kang on 7/12/24.
//

import NIOWebSocket

extension WebSocketClient.Data {
    public struct Context: Sendable {
        public let webSocketFrame: WebSocketFrame?
    }
}
