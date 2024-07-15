//
//  WebSocketClient.swift
//
//
//  Created by Jaehong Kang on 7/10/24.
//

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

public struct WebSocketClient {
    public let host: String
    public let port: Int
    public let isSecure: Bool
    public let configuration: Configuration

    private var upgradeRequestHTTPHeaders: HTTPHeaders {
        .init([
            ("Host", host),
            ("Content-Type", "text/plain; charset=utf-8"),
            ("Content-Length", "0"),
        ])
    }

    private var upgradeRequestHTTPRequestHead: HTTPRequestHead {
        .init(
            version: .http1_1,
            method: .GET,
            uri: "/",
            headers: upgradeRequestHTTPHeaders
        )
    }

    public init(
        host: String,
        port: Int,
        isSecure: Bool,
        configuration: Configuration
    ) {
        self.host = host
        self.port = port
        self.isSecure = isSecure
        self.configuration = configuration
    }

    public func connect<Result>(
        _ body: (_ inbound: Inbound, _ outbound: Outbound) async throws -> Result
    ) async throws -> Result {
        #if canImport(NIOTransportServices)
        let bootstrap = {
            var bootstrap = NIOTSConnectionBootstrap(group: configuration.threadPool.eventLoopGroup)
            if isSecure {
                bootstrap = bootstrap.tlsOptions(NWProtocolTLS.Options())
            }
            return bootstrap
        }()
        #else
        let bootstrap = ClientBootstrap(group: configuration.threadPool.eventLoopGroup)
        #if canImport(NIOSSL)
        let sslContext = url.scheme == "wss" ? try NIOSSLContext(configuration: .clientDefault) : nil
        #endif
        #endif

        let channel = try await bootstrap
            .connect(
                host: host,
                port: port
            ) { channel in
                channel.eventLoop.makeCompletedFuture {
                    #if canImport(NIOSSL) && !canImport(NIOTransportServices)
                    if let sslContext = sslContext {
                        let sslClientHandler = try NIOSSLClientHandler(context: sslContext, serverHostname: self.url.host)

                        channel.pipeline.addHandler(sslClientHandler)
                    }
                    #endif

                    let upgrader = NIOTypedWebSocketClientUpgrader<NIOAsyncChannel<WebSocketFrame, WebSocketFrame>?>(
                        maxFrameSize: configuration.maxFrameSize,
                        upgradePipelineHandler: { (channel, _) in
                            channel.eventLoop.makeCompletedFuture {
                                try NIOAsyncChannel<WebSocketFrame, WebSocketFrame>(wrappingChannelSynchronously: channel)
                            }
                        }
                    )

                    var upgradableHTTPClientPipelineConfiguration = NIOUpgradableHTTPClientPipelineConfiguration(
                        upgradeConfiguration: .init(
                            upgradeRequestHead: upgradeRequestHTTPRequestHead,
                            upgraders: [upgrader],
                            notUpgradingCompletionHandler: { channel in
                                channel.eventLoop.makeCompletedFuture {
                                    return nil
                                }
                            }
                        )
                    )
                    upgradableHTTPClientPipelineConfiguration.leftOverBytesStrategy = .forwardBytes

                    return try channel.pipeline.syncOperations.configureUpgradableHTTPClientPipeline(
                        configuration: upgradableHTTPClientPipelineConfiguration
                    )
                }
            }

        guard let channel = try await channel.get() else {
            throw Error.cannotUpgrade
        }

        return try await channel.executeThenClose { inbound, outbound in
            return try await body(
                Inbound(asyncChannelInboundStream: inbound),
                Outbound(asyncChannelOutboundWriter: outbound)
            )
        }
    }
}
