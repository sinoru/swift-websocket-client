//
//  WebSocketClient+URL.swift
//
//
//  Created by Jaehong Kang on 7/15/24.
//

import Foundation
import WebSocketClient

extension WebSocketClient {
    @usableFromInline
    static let allowedURLSchemes: Set<String?> = .init(["http", "https", "ws", "wss", nil])

    @usableFromInline
    static let secureURLSchemes: Set<String?> = .init(["wss", "https"])

    @inlinable
    public init?(url: URL, configuration: Configuration) {
        guard
            let host = url.host,
            Self.allowedURLSchemes.contains(url.scheme)
        else {
            return nil
        }

        let isSecure = Self.secureURLSchemes.contains(url.scheme)
        let port = url.port ?? (isSecure ? 443 : 80)

        self.init(
            host: host,
            port: port,
            isSecure: isSecure,
            configuration: configuration
        )
    }
}
