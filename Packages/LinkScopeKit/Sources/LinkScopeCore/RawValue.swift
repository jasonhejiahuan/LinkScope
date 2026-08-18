import Foundation

public indirect enum RawValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case signedInt(Int64)
    case unsignedInt(UInt64)
    case double(Double)
    case decimal(String)
    case string(String)
    case data(Data)
    case date(Date)
    case uuid(UUID)
    case array([RawValue])
    case dictionary([String: RawValue])

    public enum ValueType: String, Codable, CaseIterable, Sendable {
        case null
        case bool
        case signedInt
        case unsignedInt
        case double
        case decimal
        case string
        case data
        case date
        case uuid
        case array
        case dictionary
    }

    public var valueType: ValueType {
        switch self {
        case .null: .null
        case .bool: .bool
        case .signedInt: .signedInt
        case .unsignedInt: .unsignedInt
        case .double: .double
        case .decimal: .decimal
        case .string: .string
        case .data: .data
        case .date: .date
        case .uuid: .uuid
        case .array: .array
        case .dictionary: .dictionary
        }
    }

    public var compactDescription: String {
        switch self {
        case .null:
            "null"
        case let .bool(value):
            value ? "true" : "false"
        case let .signedInt(value):
            String(value)
        case let .unsignedInt(value):
            String(value)
        case let .double(value):
            value.formatted(.number.precision(.fractionLength(0...4)))
        case let .decimal(value):
            value
        case let .string(value):
            value
        case let .data(value):
            value.base64EncodedString()
        case let .date(value):
            value.formatted(.iso8601)
        case let .uuid(value):
            value.uuidString.lowercased()
        case let .array(value):
            "[\(value.map(\.compactDescription).joined(separator: ", "))]"
        case let .dictionary(value):
            "{" + value.keys.sorted().map { key in
                "\(key): \(value[key]?.compactDescription ?? "null")"
            }.joined(separator: ", ") + "}"
        }
    }

    public static func from(propertyListValue value: Any) -> RawValue {
        switch value {
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .signedInt(Int64(value))
        case let value as Int8:
            return .signedInt(Int64(value))
        case let value as Int16:
            return .signedInt(Int64(value))
        case let value as Int32:
            return .signedInt(Int64(value))
        case let value as Int64:
            return .signedInt(value)
        case let value as UInt:
            return .unsignedInt(UInt64(value))
        case let value as UInt8:
            return .unsignedInt(UInt64(value))
        case let value as UInt16:
            return .unsignedInt(UInt64(value))
        case let value as UInt32:
            return .unsignedInt(UInt64(value))
        case let value as UInt64:
            return .unsignedInt(value)
        case let value as Float:
            return .double(Double(value))
        case let value as Double:
            return .double(value)
        case let value as NSNumber:
            return .double(value.doubleValue)
        case let value as String:
            return .string(value)
        case let value as Data:
            return .data(value)
        case let value as Date:
            return .date(value)
        case let value as UUID:
            return .uuid(value)
        case let value as [Any]:
            return .array(value.map(RawValue.from(propertyListValue:)))
        case let value as [String: Any]:
            return .dictionary(value.mapValues(RawValue.from(propertyListValue:)))
        default:
            return .string(String(describing: value))
        }
    }
}

