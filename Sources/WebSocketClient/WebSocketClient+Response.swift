//
//  WebSocketClient+Response.swift
//
//
//  Created by Jaehong Kang on 7/12/24.
//

import NIOWebSocket

extension WebSocketClient {
    public struct Response {
        public let data: Data?
        public let frame: WebSocketFrame
    }
}
