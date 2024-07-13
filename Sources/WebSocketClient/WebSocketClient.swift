//
//  WebSocketClient.swift
//
//
//  Created by Jaehong Kang on 7/10/24.
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

public struct WebSocketClient {
    public let url: URL
    public let configuration: Configuration

    public init(
        url: URL,
        configuration: Configuration
    ) {
        self.url = url
        self.configuration = configuration
    }

    public func connect<Result>(
        _ body: (_ inbound: Inbound, _ outbound: Outbound) async throws -> Result
    ) async throws -> Result {
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

        let channel = try await bootstrap
            .connect(
                host: url.host!,
                port: url.port ?? 443
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

                    var headers = HTTPHeaders()
                    headers.add(name: "Host", value: url.host!)
                    headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
                    headers.add(name: "Content-Length", value: "0")

                    let requestHead = HTTPRequestHead(
                        version: .http1_1,
                        method: .GET,
                        uri: "/",
                        headers: headers
                    )

                    var upgradableHTTPClientPipelineConfiguration = NIOUpgradableHTTPClientPipelineConfiguration(
                        upgradeConfiguration: .init(
                            upgradeRequestHead: requestHead,
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
