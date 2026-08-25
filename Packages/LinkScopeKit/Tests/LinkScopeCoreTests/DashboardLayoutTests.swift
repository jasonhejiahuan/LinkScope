import Foundation
import Testing
@testable import LinkScopeCore

private let firstDashboardWidgetID = UUID(
    uuidString: "00000000-0000-0000-0000-000000000001"
)!
private let secondDashboardWidgetID = UUID(
    uuidString: "00000000-0000-0000-0000-000000000002"
)!

private func dashboardWidget(
    id: UUID,
    kind: DashboardWidget.Kind = .currentValue,
    placement: GridPlacement
) -> DashboardWidget {
    DashboardWidget(
        id: id,
        kind: kind,
        sourceIDs: [],
        placement: placement
    )
}

@Test func dashboardNormalizationEnforcesTwelveColumnsAndResolvesCollisions() {
    let document = DashboardDocument(
        name: "Legacy Layout",
        columns: 4,
        widgets: [
            dashboardWidget(
                id: firstDashboardWidgetID,
                placement: GridPlacement(
                    column: -4,
                    row: -2,
                    columnSpan: 40,
                    rowSpan: 0
                )
            ),
            dashboardWidget(
                id: secondDashboardWidgetID,
                placement: GridPlacement(
                    column: 0,
                    row: 0,
                    columnSpan: 12,
                    rowSpan: 1
                )
            )
        ]
    )

    let normalized = DashboardLayoutEngine.normalized(document)

    #expect(normalized.columns == 12)
    #expect(normalized.widgets[0].placement == GridPlacement(
        column: 0,
        row: 0,
        columnSpan: 12,
        rowSpan: 1
    ))
    #expect(normalized.widgets[1].placement == GridPlacement(
        column: 0,
        row: 1,
        columnSpan: 12,
        rowSpan: 1
    ))
    #expect(DashboardLayoutEngine.isCollisionFree(normalized))
}

@Test func dashboardDefaultLayoutUsesKindSizesAndDeterministicFirstFit() {
    let empty = DashboardDocument(name: "Defaults")
    let withValue = DashboardLayoutEngine.addingWidget(
        id: firstDashboardWidgetID,
        kind: .currentValue,
        to: empty
    )
    let withChart = DashboardLayoutEngine.addingWidget(
        id: secondDashboardWidgetID,
        kind: .timeSeries,
        to: withValue
    )

    #expect(withValue.widgets[0].placement == GridPlacement(
        column: 0,
        row: 0,
        columnSpan: 3,
        rowSpan: 2
    ))
    #expect(withChart.widgets[1].placement == GridPlacement(
        column: 3,
        row: 0,
        columnSpan: 6,
        rowSpan: 4
    ))
}

@Test func dashboardMoveResizeAndPlaceholderUseTheSameCollisionRules() throws {
    let document = DashboardDocument(
        name: "Keyboard Layout",
        widgets: [
            dashboardWidget(
                id: firstDashboardWidgetID,
                placement: GridPlacement(column: 0, row: 0, columnSpan: 3, rowSpan: 2)
            ),
            dashboardWidget(
                id: secondDashboardWidgetID,
                placement: GridPlacement(column: 3, row: 0, columnSpan: 3, rowSpan: 2)
            )
        ]
    )

    #expect(throws: DashboardLayoutError.self) {
        _ = try DashboardLayoutEngine.movingWidget(
            id: firstDashboardWidgetID,
            direction: .right,
            in: document
        )
    }
    #expect(throws: DashboardLayoutError.self) {
        _ = try DashboardLayoutEngine.resizingWidget(
            id: firstDashboardWidgetID,
            direction: .wider,
            in: document
        )
    }

    let moved = try DashboardLayoutEngine.movingWidget(
        id: firstDashboardWidgetID,
        direction: .right,
        collisionPolicy: .nextAvailable,
        in: document
    )
    #expect(moved.widgets[0].placement.column == 6)

    let resized = try DashboardLayoutEngine.resizingWidget(
        id: firstDashboardWidgetID,
        direction: .wider,
        collisionPolicy: .nextAvailable,
        in: document
    )
    #expect(resized.widgets[0].placement == GridPlacement(
        column: 6,
        row: 0,
        columnSpan: 4,
        rowSpan: 2
    ))

    let placeholder = DashboardLayoutEngine.placeholder(
        for: GridPlacement(column: 1, row: 0, columnSpan: 3, rowSpan: 2),
        in: document
    )
    #expect(placeholder.column == 6)
}

@Test func dashboardTwoAxisDeltasValidateOnlyTheFinalSnappedRectangle() throws {
    let mover = dashboardWidget(
        id: firstDashboardWidgetID,
        placement: GridPlacement(column: 0, row: 0, columnSpan: 2, rowSpan: 2)
    )
    let moveBlocker = dashboardWidget(
        id: secondDashboardWidgetID,
        placement: GridPlacement(column: 2, row: 0, columnSpan: 2, rowSpan: 2)
    )
    let moveDocument = DashboardDocument(
        name: "Atomic Move",
        widgets: [mover, moveBlocker]
    )
    #expect(throws: DashboardLayoutError.self) {
        _ = try DashboardLayoutEngine.movingWidget(
            id: mover.id,
            direction: .right,
            steps: 2,
            in: moveDocument
        )
    }
    let moved = try DashboardLayoutEngine.movingWidget(
        id: mover.id,
        columns: 2,
        rows: 2,
        in: moveDocument
    )
    #expect(moved.widgets[0].placement == GridPlacement(
        column: 2,
        row: 2,
        columnSpan: 2,
        rowSpan: 2
    ))

    let resizer = dashboardWidget(
        id: firstDashboardWidgetID,
        placement: GridPlacement(column: 0, row: 0, columnSpan: 4, rowSpan: 4)
    )
    let resizeBlocker = dashboardWidget(
        id: secondDashboardWidgetID,
        placement: GridPlacement(column: 4, row: 3, columnSpan: 1, rowSpan: 1)
    )
    let resizeDocument = DashboardDocument(
        name: "Atomic Resize",
        widgets: [resizer, resizeBlocker]
    )
    #expect(throws: DashboardLayoutError.self) {
        _ = try DashboardLayoutEngine.resizingWidget(
            id: resizer.id,
            direction: .wider,
            steps: 2,
            in: resizeDocument
        )
    }
    let resized = try DashboardLayoutEngine.resizingWidget(
        id: resizer.id,
        columns: 2,
        rows: -1,
        in: resizeDocument
    )
    #expect(resized.widgets[0].placement == GridPlacement(
        column: 0,
        row: 0,
        columnSpan: 6,
        rowSpan: 3
    ))
}

@Test func dashboardDuplicatePreservesOpaqueWidgetDataAndFindsAFreeSlot() throws {
    let source = WidgetSourceID(rawValue: "opaque-source")
    let original = DashboardWidget(
        id: firstDashboardWidgetID,
        kind: DashboardWidget.Kind(rawValue: "futureSpectrum"),
        sourceIDs: [source],
        placement: GridPlacement(
            column: 0,
            row: 0,
            columnSpan: 4,
            rowSpan: 3,
            extensionFields: ["futureLayer": .signedInteger(7)]
        ),
        configuration: ["scale": .string("log")],
        opaqueConfiguration: .object(["futureScale": .string("perceptual")]),
        extensionFields: ["future": .object(["enabled": .bool(true)])]
    )
    let blocker = dashboardWidget(
        id: secondDashboardWidgetID,
        placement: GridPlacement(column: 4, row: 0, columnSpan: 4, rowSpan: 3)
    )
    let duplicateID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    let result = try DashboardLayoutEngine.duplicatingWidget(
        id: original.id,
        newID: duplicateID,
        in: DashboardDocument(name: "Duplicate", widgets: [original, blocker])
    )
    let duplicate = try #require(result.widgets.first { $0.id == duplicateID })

    #expect(duplicate.kind == original.kind)
    #expect(duplicate.sourceIDs == original.sourceIDs)
    #expect(duplicate.configuration == original.configuration)
    #expect(duplicate.opaqueConfiguration == original.opaqueConfiguration)
    #expect(duplicate.extensionFields == original.extensionFields)
    #expect(duplicate.placement.extensionFields == original.placement.extensionFields)
    #expect(duplicate.placement.column == 8)
    #expect(DashboardLayoutEngine.isCollisionFree(result))
}

@Test func dashboardDecimatorIsBoundedDeterministicAndPreservesAVisibleSpike() {
    let sourceID = WidgetSourceID(rawValue: "fixture-source")
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let spikeID = UUID(uuidString: "00000000-0000-0000-0000-000000000500")!
    var points: [DashboardTimeSeriesPoint] = []
    points.reserveCapacity(1_000)
    for index in 0..<1_000 {
        let identifier = index == 500
            ? spikeID
            : UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                index
            ))!
        let value = index == 500 ? 10_000 : sin(Double(index) / 25)
        points.append(DashboardTimeSeriesPoint(
            observationID: identifier,
            sourceID: sourceID,
            timestamp: start.addingTimeInterval(Double(index)),
            value: value
        ))
    }

    let first = DashboardTimeSeriesDecimator.decimate(
        Array(points.reversed()),
        maximumPointCount: 300
    )
    let second = DashboardTimeSeriesDecimator.decimate(
        points,
        maximumPointCount: 300
    )

    #expect(first == second)
    #expect(first.count == 300)
    #expect(first.first == points.first)
    #expect(first.last == points.last)
    #expect(first.contains { $0.observationID == spikeID })
    #expect(DashboardTimeSeriesDecimator.decimate(points, maximumPointCount: 0).isEmpty)
    #expect(DashboardTimeSeriesDecimator.decimate(points, maximumPointCount: 1) == [points.last!])
}

@Test func widgetSourceIDRoundTripsColonsAndRecoversLegacyIDs() throws {
    let identity = ObservationIdentity(
        providerID: "vendor:private",
        transportIdentityID: UUID(
            uuidString: "40000000-0000-0000-0000-000000000001"
        )!,
        parameterPath: "radio:rssi:instant"
    )
    let sourceID = WidgetSourceID(observationIdentity: identity)

    #expect(sourceID.rawValue.hasPrefix("v2:"))
    #expect(sourceID.observationIdentity == identity)

    let legacy = WidgetSourceID(
        rawValue: "vendor:private:40000000-0000-0000-0000-000000000001:radio:rssi:instant"
    )
    #expect(legacy.observationIdentity == identity)
}

@Test func widgetSourceIDDisambiguatesReservedV2ProviderAndLegacyPathColons() {
    let transportID = UUID(
        uuidString: "40000000-0000-0000-0000-000000000002"
    )!
    let identity = ObservationIdentity(
        providerID: "v2",
        transportIdentityID: transportID,
        parameterPath: "a:b"
    )
    let sourceID = WidgetSourceID(observationIdentity: identity)

    #expect(sourceID.rawValue.hasPrefix("v2:djI:"))
    #expect(sourceID.observationIdentity == identity)

    let legacy = WidgetSourceID(
        rawValue: "v2:\(transportID.uuidString.lowercased()):a:b"
    )
    #expect(legacy.observationIdentity == identity)
}
