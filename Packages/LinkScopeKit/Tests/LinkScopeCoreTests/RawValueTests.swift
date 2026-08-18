import Foundation
import Testing
@testable import LinkScopeCore

@Test func recursiveRawValueRoundTrips() throws {
    let original = RawValue.dictionary([
        "battery": .double(0.74),
        "flags": .array([.bool(true), .null]),
        "identifier": .uuid(UUID(uuidString: "9B4E59A2-A5DB-4E70-A4FA-4F7BC3B2292C")!),
        "payload": .data(Data([0x00, 0x7F, 0xFF]))
    ])

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(RawValue.self, from: data)
    #expect(decoded == original)
}

@Test func availabilityStatesRemainDistinct() throws {
    let values: [ParameterAvailability] = [
        .available,
        .notExposed(detail: "macOS does not expose this field"),
        .notReported(detail: "device omitted the report"),
        .permissionDenied(detail: "Bluetooth denied"),
        .unsupported(detail: "not supported on this Mac"),
        .stale(lastObservedAt: Date(timeIntervalSince1970: 42), detail: nil),
        .providerFailure(code: "E_TEST", detail: "fixture failure")
    ]

    let data = try JSONEncoder().encode(values)
    let decoded = try JSONDecoder().decode([ParameterAvailability].self, from: data)
    #expect(decoded.map(\.code) == AvailabilityCode.allCases)
}

