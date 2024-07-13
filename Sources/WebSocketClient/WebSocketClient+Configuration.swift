//
//  WebSocketClient+Configuration.swift
//
//
//  Created by Jaehong Kang on 7/10/24.
//

import NIOCore
#if canImport(NIOTransportServices)
import NIOTransportServices
#else
import NIOPosix
#endif

extension WebSocketClient {
    public actor ThreadPool {
        let eventLoopGroup: EventLoopGroup

        public init(
            threadCount: Int = 1
        ) {
            #if canImport(NIOTransportServices)
            self.init(eventLoopGroup: NIOTSEventLoopGroup(loopCount: threadCount, defaultQoS: .default))
            #else
            self.init(eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: threadCount))
            #endif
        }

        public init(
            eventLoopGroup: EventLoopGroup
        ) {
            self.eventLoopGroup = eventLoopGroup
        }

        deinit {
            Task.detached(priority: .utility) { [eventLoopGroup] in
                try await eventLoopGroup.shutdownGracefully()
            }
        }
    }

    public struct Configuration {
        public var threadPool: ThreadPool
        public var maxFrameSize: Int

        public init(
            threadPool: ThreadPool = ThreadPool(),
            maxFrameSize: Int = 1 << 14
        ) {
            self.threadPool = threadPool
            self.maxFrameSize = maxFrameSize
        }
    }
}
