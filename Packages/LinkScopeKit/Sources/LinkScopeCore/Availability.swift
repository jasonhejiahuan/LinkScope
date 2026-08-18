import Foundation

public enum AvailabilityCode: String, Codable, CaseIterable, Sendable {
    case available
    case notExposed
    case notReported
    case permissionDenied
    case unsupported
    case stale
    case providerFailure
}

public enum ParameterAvailability: Codable, Hashable, Sendable {
    case available
    case notExposed(detail: String?)
    case notReported(detail: String?)
    case permissionDenied(detail: String?)
    case unsupported(detail: String?)
    case stale(lastObservedAt: Date, detail: String?)
    case providerFailure(code: String?, detail: String)

    public var code: AvailabilityCode {
        switch self {
        case .available: .available
        case .notExposed: .notExposed
        case .notReported: .notReported
        case .permissionDenied: .permissionDenied
        case .unsupported: .unsupported
        case .stale: .stale
        case .providerFailure: .providerFailure
        }
    }

    public var detail: String? {
        switch self {
        case .available:
            nil
        case let .notExposed(detail),
             let .notReported(detail),
             let .permissionDenied(detail),
             let .unsupported(detail),
             let .stale(_, detail):
            detail
        case let .providerFailure(_, detail):
            detail
        }
    }
}

