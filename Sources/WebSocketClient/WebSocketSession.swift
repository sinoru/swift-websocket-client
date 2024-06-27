//
//  WebSocketSession.swift
//  
//
//  Created by Jaehong Kang on 2022/07/22.
//

import Foundation
import NIOCore
import NIOHTTP1
import NIOWebSocket
import NIOPosix
#if canImport(NIOTransportServices)
import NIOTransportServices
import Network
#endif
#if canImport(NIOSSL)
import NIOSSL
#endif

public class WebSocketSession {
    public typealias Delegate = WebSocketSessionDelegate

    public let url: URL
    public let configuration: Configuration
    public private(set) weak var delegate: Delegate?

    private var channel: Channel?

    public init(url: URL, configuration: Configuration, delegate: WebSocketSessionDelegate) {
        self.url = url
        self.configuration = configuration
        self.delegate = delegate
    }

    deinit {
        channel?.close(mode: .all, promise: nil)
    }
}

extension WebSocketSession {
    public func connect() async throws {
        #if canImport(NIOTransportServices)
        var bootstrap = NIOTSConnectionBootstrap(group: configuration.threadPool.eventLoopGroup)
        #else
        let bootstrap = ClientBootstrap(group: configuration.threadPool.eventLoopGroup)
        #endif

        #if canImport(NIOTransportServices)
        if url.scheme == "wss" {
            bootstrap = bootstrap.tlsOptions(NWProtocolTLS.Options())
        }
        #elseif canImport(NIOSSL)
        let sslContext = url.scheme == "wss" ? try NIOSSLContext(configuration: .clientDefault) : nil
        #endif

        self.channel = try await bootstrap
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                let httpHandler = HTTPInitialRequestHandler(url: self.url)

                let websocketUpgrader = NIOWebSocketClientUpgrader(
                    upgradePipelineHandler: { (channel: NIOCore.Channel, _: HTTPResponseHead) in
                        channel.pipeline.addHandler(WebSocketHandler(webSocketSession: self))
                    }
                )

                let config: NIOHTTPClientUpgradeConfiguration = (
                    upgraders: [ websocketUpgrader ],
                    completionHandler: { _ in
                        channel.pipeline.removeHandler(httpHandler, promise: nil)
                    }
                )

                let sslPromise: EventLoopFuture<Void>
                #if canImport(NIOSSL) && !canImport(NIOTransportServices)
                if let sslContext = sslContext {
                    do {
                        let sslClientHandler = try NIOSSLClientHandler(context: sslContext, serverHostname: self.url.host)

                        sslPromise = channel.pipeline.addHandler(sslClientHandler)
                    } catch {
                        sslPromise = channel.eventLoop.makeFailedFuture(error)
                    }
                } else {
                    sslPromise = channel.eventLoop.makeSucceededVoidFuture()
                }
                #else
                sslPromise = channel.eventLoop.makeSucceededVoidFuture()
                #endif

                return sslPromise
                    .flatMap {
                        channel.pipeline.addHTTPClientHandlers(leftOverBytesStrategy: .forwardBytes, withClientUpgrade: config)
                    }
                    .flatMap {
                        channel.pipeline.addHandler(httpHandler)
                    }
            }
            .connect(host: self.url.host!, port: self.url.port ?? 443)
            .get()
    }

    public func send(_ message: Message) async throws {
        guard let channel = channel else {
            return
        }

        let buffer = channel.allocator.buffer(webSocketSessionMessage: message)
        let frame = WebSocketFrame(
            fin: true,
            opcode: {
                switch message {
                case .string:
                    return .text
                case .data:
                    return .binary
                }
            }(),
            maskKey: .random(),
            data: buffer
        )

        return try await channel.writeAndFlush(frame)
    }

    public func disconnect() async throws {
        try await close()
    }
}

extension WebSocketSession {
    func close(frame: WebSocketFrame, context: ChannelHandlerContext) async throws {
        var data = frame.unmaskedData

        let closeCode = data.readInteger(as: UInt16.self) ?? 0

        delegate?.didReceiveClose(
            code: .init(rawValue: closeCode),
            reason: .init(data.readableBytesView),
            context: .init(session: self, channelHandlerContext: context, frame: frame)
        )

        try await close(code: nil)
    }

    func close(code: CloseCode? = .normalClosure, context: ChannelHandlerContext? = nil) async throws {
        guard let channel = context?.channel ?? channel else {
            return
        }

        if let closeCode = code {
            var data = channel.allocator.buffer(capacity: 2)
            data.write(webSocketErrorCode: closeCode.webSocketErrorCode)
            let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
            try? await channel.writeAndFlush(frame).get()
        }

        try await channel.close()

        delegate?.didClose(context: .init(session: self, channelHandlerContext: nil, frame: nil))
    }
}

extension WebSocketSession {
    func receivedFrame(_ frame: WebSocketFrame, context: ChannelHandlerContext) {
        switch frame.opcode {
        case .text:
            var data = frame.unmaskedData
            guard let string = data.readString(length: data.readableBytes) else {
                delegate?.didReceiveMessage(
                    .data(.init(frame.unmaskedData.readableBytesView)),
                    context: .init(session: self, channelHandlerContext: context, frame: frame)
                )
                break
            }

            delegate?.didReceiveMessage(
                .string(string),
                context: .init(session: self, channelHandlerContext: context, frame: frame)
            )
        case .binary:
            delegate?.didReceiveMessage(
                .data(.init(frame.unmaskedData.readableBytesView)),
                context: .init(session: self, channelHandlerContext: context, frame: frame)
            )
        case .connectionClose:
            Task {
                try await self.close(frame: frame, context: context)
            }
        default:
            break
        }
    }
}
