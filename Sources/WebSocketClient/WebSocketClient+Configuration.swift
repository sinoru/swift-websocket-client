//
//  WebSocketClient+Configuration.swift
//
//
//  Created by Jaehong Kang on 7/10/24.
//

import NIOCore

extension WebSocketClient {
    public struct Configuration {
        public let eventLoopGroup: (any EventLoopGroup)?
        public var maxFrameSize: Int

        public init(
            eventLoopGroup: (any EventLoopGroup)? = nil,
            maxFrameSize: Int = 1 << 14
        ) {
            self.eventLoopGroup = eventLoopGroup
            self.maxFrameSize = maxFrameSize
        }
    }
}
