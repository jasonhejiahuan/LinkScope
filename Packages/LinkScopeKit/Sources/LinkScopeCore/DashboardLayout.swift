import Foundation

public enum DashboardGridDirection: String, Codable, CaseIterable, Sendable {
    case left, right, up, down
}

public enum DashboardResizeDirection: String, Codable, CaseIterable, Sendable {
    case narrower, wider, shorter, taller
}

public enum DashboardCollisionPolicy: String, Codable, Sendable {
    case reject
    case nextAvailable
}

public enum DashboardLayoutError: Error, Equatable, Sendable {
    case widgetNotFound(UUID)
    case collision(UUID)
}

public extension GridPlacement {
    var endColumn: Int { column + columnSpan }
    var endRow: Int { row + rowSpan }

    func normalized(columnCount: Int = DashboardDocument.gridColumnCount) -> GridPlacement {
        let columns = max(1, columnCount)
        let normalizedColumnSpan = min(columns, max(1, columnSpan))
        return GridPlacement(
            column: min(max(0, column), columns - normalizedColumnSpan),
            row: max(0, row),
            columnSpan: normalizedColumnSpan,
            rowSpan: max(1, rowSpan),
            extensionFields: extensionFields
        )
    }

    func intersects(_ other: GridPlacement) -> Bool {
        column < other.endColumn
            && endColumn > other.column
            && row < other.endRow
            && endRow > other.row
    }
}

/// Deterministic, side-effect-free layout operations shared by pointer and
/// keyboard interactions. Grid coordinates are zero-based and use half-open
/// rectangles on a fixed twelve-column canvas.
public enum DashboardLayoutEngine: Sendable {
    public static let columnCount = DashboardDocument.gridColumnCount

    public static func normalized(_ document: DashboardDocument) -> DashboardDocument {
        var result = document
        result.columns = columnCount
        result.widgets = []
        result.widgets.reserveCapacity(document.widgets.count)

        for original in document.widgets {
            var widget = original
            let proposed = original.placement.normalized(columnCount: columnCount)
            widget.placement = isFree(proposed, among: result.widgets)
                ? proposed
                : firstAvailablePlacement(preferred: proposed, among: result.widgets)
            result.widgets.append(widget)
        }
        return result
    }

    public static func defaultSize(for kind: DashboardWidget.Kind) -> GridPlacement {
        let size: (columns: Int, rows: Int)
        switch kind.rawValue {
        case DashboardWidget.Kind.currentValue.rawValue,
             DashboardWidget.Kind.status.rawValue,
             DashboardWidget.Kind.providerHealth.rawValue:
            size = (3, 2)
        case DashboardWidget.Kind.timeSeries.rawValue,
             DashboardWidget.Kind.rawTable.rawValue:
            size = (6, 4)
        case DashboardWidget.Kind.timeline.rawValue:
            size = (6, 3)
        default:
            size = (4, 3)
        }
        return GridPlacement(
            column: 0,
            row: 0,
            columnSpan: size.columns,
            rowSpan: size.rows
        )
    }

    public static func defaultPlacement(
        for kind: DashboardWidget.Kind,
        in document: DashboardDocument
    ) -> GridPlacement {
        let document = normalized(document)
        return firstAvailablePlacement(
            preferred: defaultSize(for: kind),
            among: document.widgets
        )
    }

    public static func placeholder(
        for proposedPlacement: GridPlacement,
        excluding widgetID: UUID? = nil,
        in document: DashboardDocument
    ) -> GridPlacement {
        let document = normalized(document)
        let widgets = document.widgets.filter { $0.id != widgetID }
        let proposed = proposedPlacement.normalized(columnCount: columnCount)
        return isFree(proposed, among: widgets)
            ? proposed
            : firstAvailablePlacement(preferred: proposed, among: widgets)
    }

    public static func addingWidget(
        id: UUID = UUID(),
        kind: DashboardWidget.Kind,
        sourceIDs: [WidgetSourceID] = [],
        placement: GridPlacement? = nil,
        configuration: [String: RawValue] = [:],
        opaqueConfiguration: DashboardFieldValue? = nil,
        extensionFields: [String: DashboardFieldValue] = [:],
        to document: DashboardDocument
    ) -> DashboardDocument {
        var result = normalized(document)
        let proposed = placement ?? defaultSize(for: kind)
        let resolved = placeholder(for: proposed, in: result)
        result.widgets.append(DashboardWidget(
            id: id,
            kind: kind,
            sourceIDs: sourceIDs,
            placement: resolved,
            configuration: configuration,
            opaqueConfiguration: opaqueConfiguration,
            extensionFields: extensionFields
        ))
        return result
    }

    public static func movingWidget(
        id: UUID,
        direction: DashboardGridDirection,
        steps: Int = 1,
        collisionPolicy: DashboardCollisionPolicy = .reject,
        in document: DashboardDocument
    ) throws -> DashboardDocument {
        let distance = max(0, steps)
        let delta: (columns: Int, rows: Int)
        switch direction {
        case .left:
            delta = (-distance, 0)
        case .right:
            delta = (distance, 0)
        case .up:
            delta = (0, -distance)
        case .down:
            delta = (0, distance)
        }
        return try movingWidget(
            id: id,
            columns: delta.columns,
            rows: delta.rows,
            collisionPolicy: collisionPolicy,
            in: document
        )
    }

    /// Applies a two-axis pointer or keyboard delta atomically. Only the final
    /// snapped placement participates in collision resolution.
    public static func movingWidget(
        id: UUID,
        columns: Int,
        rows: Int,
        collisionPolicy: DashboardCollisionPolicy = .reject,
        in document: DashboardDocument
    ) throws -> DashboardDocument {
        var result = normalized(document)
        guard let index = result.widgets.firstIndex(where: { $0.id == id }) else {
            throw DashboardLayoutError.widgetNotFound(id)
        }
        var proposed = result.widgets[index].placement
        proposed.column += columns
        proposed.row += rows
        result.widgets[index].placement = try resolvedPlacement(
            proposed,
            widgetID: id,
            policy: collisionPolicy,
            widgets: result.widgets
        )
        return result
    }

    public static func resizingWidget(
        id: UUID,
        direction: DashboardResizeDirection,
        steps: Int = 1,
        collisionPolicy: DashboardCollisionPolicy = .reject,
        in document: DashboardDocument
    ) throws -> DashboardDocument {
        let distance = max(0, steps)
        let delta: (columns: Int, rows: Int)
        switch direction {
        case .narrower:
            delta = (-distance, 0)
        case .wider:
            delta = (distance, 0)
        case .shorter:
            delta = (0, -distance)
        case .taller:
            delta = (0, distance)
        }
        return try resizingWidget(
            id: id,
            columns: delta.columns,
            rows: delta.rows,
            collisionPolicy: collisionPolicy,
            in: document
        )
    }

    /// Applies width and height changes atomically, which keeps diagonal
    /// pointer resize gestures from failing on an intermediate rectangle.
    public static func resizingWidget(
        id: UUID,
        columns: Int,
        rows: Int,
        collisionPolicy: DashboardCollisionPolicy = .reject,
        in document: DashboardDocument
    ) throws -> DashboardDocument {
        var result = normalized(document)
        guard let index = result.widgets.firstIndex(where: { $0.id == id }) else {
            throw DashboardLayoutError.widgetNotFound(id)
        }
        var proposed = result.widgets[index].placement
        proposed.columnSpan = min(
            columnCount - proposed.column,
            max(1, proposed.columnSpan + columns)
        )
        proposed.rowSpan = max(1, proposed.rowSpan + rows)
        result.widgets[index].placement = try resolvedPlacement(
            proposed,
            widgetID: id,
            policy: collisionPolicy,
            widgets: result.widgets
        )
        return result
    }

    public static func duplicatingWidget(
        id: UUID,
        newID: UUID = UUID(),
        in document: DashboardDocument
    ) throws -> DashboardDocument {
        var result = normalized(document)
        guard let source = result.widgets.first(where: { $0.id == id }) else {
            throw DashboardLayoutError.widgetNotFound(id)
        }
        var preferred = source.placement
        preferred.column += source.placement.columnSpan
        let placement = placeholder(for: preferred, in: result)
        result.widgets.append(DashboardWidget(
            id: newID,
            kind: source.kind,
            sourceIDs: source.sourceIDs,
            placement: placement,
            configuration: source.configuration,
            opaqueConfiguration: source.opaqueConfiguration,
            extensionFields: source.extensionFields
        ))
        return result
    }

    public static func removingWidget(
        id: UUID,
        from document: DashboardDocument
    ) -> DashboardDocument {
        var result = normalized(document)
        result.widgets.removeAll { $0.id == id }
        return result
    }

    public static func isCollisionFree(_ document: DashboardDocument) -> Bool {
        let widgets = document.widgets
        for leftIndex in widgets.indices {
            let left = widgets[leftIndex].placement.normalized(columnCount: columnCount)
            for rightIndex in widgets.indices where rightIndex > leftIndex {
                let right = widgets[rightIndex].placement.normalized(columnCount: columnCount)
                if left.intersects(right) {
                    return false
                }
            }
        }
        return widgets.allSatisfy {
            $0.placement == $0.placement.normalized(columnCount: columnCount)
        } && document.columns == columnCount
    }

    private static func resolvedPlacement(
        _ proposedPlacement: GridPlacement,
        widgetID: UUID,
        policy: DashboardCollisionPolicy,
        widgets: [DashboardWidget]
    ) throws -> GridPlacement {
        let proposed = proposedPlacement.normalized(columnCount: columnCount)
        let otherWidgets = widgets.filter { $0.id != widgetID }
        guard !isFree(proposed, among: otherWidgets) else { return proposed }
        switch policy {
        case .reject:
            throw DashboardLayoutError.collision(widgetID)
        case .nextAvailable:
            return firstAvailablePlacement(preferred: proposed, among: otherWidgets)
        }
    }

    private static func firstAvailablePlacement(
        preferred: GridPlacement,
        among widgets: [DashboardWidget]
    ) -> GridPlacement {
        let preferred = preferred.normalized(columnCount: columnCount)
        if isFree(preferred, among: widgets) {
            return preferred
        }

        let lastOccupiedRow = widgets.map {
            $0.placement.normalized(columnCount: columnCount).endRow
        }.max() ?? 0
        let lastSearchRow = max(preferred.row, lastOccupiedRow)
        let finalColumn = columnCount - preferred.columnSpan

        for row in preferred.row...lastSearchRow {
            let columns: [Int]
            if row == preferred.row {
                columns = Array(preferred.column...finalColumn)
                    + Array(0..<preferred.column)
            } else {
                columns = Array(0...finalColumn)
            }
            for column in columns {
                let candidate = GridPlacement(
                    column: column,
                    row: row,
                    columnSpan: preferred.columnSpan,
                    rowSpan: preferred.rowSpan,
                    extensionFields: preferred.extensionFields
                )
                if isFree(candidate, among: widgets) {
                    return candidate
                }
            }
        }

        return GridPlacement(
            column: 0,
            row: lastSearchRow + 1,
            columnSpan: preferred.columnSpan,
            rowSpan: preferred.rowSpan,
            extensionFields: preferred.extensionFields
        )
    }

    private static func isFree(
        _ placement: GridPlacement,
        among widgets: [DashboardWidget]
    ) -> Bool {
        !widgets.contains {
            placement.intersects($0.placement.normalized(columnCount: columnCount))
        }
    }
}
