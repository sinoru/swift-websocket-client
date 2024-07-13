//
//  WebSocketClient+CloseCode.swift
//
//
//  Created by Jaehong Kang on 7/12/24.
//

extension WebSocketClient {
    public enum CloseCode: Equatable, Hashable, Sendable {
        case normalClosure
        case goingAway
        case protocolError
        case unsupportedData
        case noStatusReceived
        case abnormalClosure
        case invalidFramePayloadData
        case policyViolation
        case messageTooBig
        case mandatoryExtensionMissing
        case internalServerError
        case tlsHandshakeFailure
        case unknown(RawValue)
    }
}

extension WebSocketClient.CloseCode: RawRepresentable {
    public typealias RawValue = UInt16

    public init(rawValue: UInt16) {
        let knownCode = KnownCodes(rawValue: rawValue)

        switch knownCode {
        case .normalClosure:
            self = .normalClosure
        case .goingAway:
            self = .goingAway
        case .protocolError:
            self = .protocolError
        case .unsupportedData:
            self = .unsupportedData
        case .noStatusReceived:
            self = .noStatusReceived
        case .abnormalClosure:
            self = .abnormalClosure
        case .invalidFramePayloadData:
            self = .invalidFramePayloadData
        case .policyViolation:
            self = .policyViolation
        case .messageTooBig:
            self = .messageTooBig
        case .mandatoryExtensionMissing:
            self = .mandatoryExtensionMissing
        case .internalServerError:
            self = .internalServerError
        case .tlsHandshakeFailure:
            self = .tlsHandshakeFailure
        case nil:
            self = .unknown(rawValue)
        }
    }

    public var rawValue: UInt16 {
        switch self {
        case .normalClosure:
            KnownCodes.normalClosure.rawValue
        case .goingAway:
            KnownCodes.goingAway.rawValue
        case .protocolError:
            KnownCodes.protocolError.rawValue
        case .unsupportedData:
            KnownCodes.unsupportedData.rawValue
        case .noStatusReceived:
            KnownCodes.noStatusReceived.rawValue
        case .abnormalClosure:
            KnownCodes.abnormalClosure.rawValue
        case .invalidFramePayloadData:
            KnownCodes.invalidFramePayloadData.rawValue
        case .policyViolation:
            KnownCodes.policyViolation.rawValue
        case .messageTooBig:
            KnownCodes.messageTooBig.rawValue
        case .mandatoryExtensionMissing:
            KnownCodes.mandatoryExtensionMissing.rawValue
        case .internalServerError:
            KnownCodes.internalServerError.rawValue
        case .tlsHandshakeFailure:
            KnownCodes.tlsHandshakeFailure.rawValue
        case .unknown(let rawValue):
            rawValue
        }
    }
}

extension WebSocketClient.CloseCode {
    enum KnownCodes: UInt16 {
        case normalClosure = 1000
        case goingAway = 1001
        case protocolError = 1002
        case unsupportedData = 1003
        case noStatusReceived = 1005
        case abnormalClosure = 1006
        case invalidFramePayloadData = 1007
        case policyViolation = 1008
        case messageTooBig = 1009
        case mandatoryExtensionMissing = 1010
        case internalServerError = 1011
        case tlsHandshakeFailure = 1015
    }
}
