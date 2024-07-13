//
//  WebSocketClient+Data.swift
//
//
//  Created by Jaehong Kang on 7/12/24.
//

extension WebSocketClient {
    public enum Data: Sendable {
        case ping(String)
        case text(String)
        case binary([UInt8])
        case close(CloseCode)
    }
}
