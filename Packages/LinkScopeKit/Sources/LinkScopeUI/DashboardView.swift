import AppKit
import Accessibility
import Charts
import LinkScopeCore
import LinkScopePersistence
import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @Environment(\.linkScopeLanguage) private var language
    @Environment(\.undoManager) private var undoManager
    let model: LinkScopeApplicationModel

    @StateObject private var undoController = DashboardUndoController()
    @State private var selectedDashboardID: UUID?
    @State private var selectedWidgetID: UUID?
    @State private var namingRequest: DashboardNamingRequest?
    @State private var dashboardPendingDeletion: DashboardDocument?
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument: DashboardJSONDocument?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            DashboardActionBar(
                dashboard: selectedDashboard,
                selectedWidget: selectedWidget,
                isReadOnly: selectedDashboardIsReadOnly,
                createDashboard: presentNewDashboard,
                renameDashboard: presentRenameDashboard,
                deleteDashboard: presentDeleteDashboard,
                importDashboard: { importing = true },
                exportDashboard: prepareExport,
                addWidget: addWidget,
                duplicateWidget: duplicateSelectedWidget,
                deleteWidget: deleteSelectedWidget,
                moveWidget: moveSelectedWidget,
                resizeWidget: resizeSelectedWidget
            )

            if let selectedDashboard, selectedDashboardIsReadOnly {
                DashboardCompatibilityBanner(schemaVersion: selectedDashboard.schemaVersion)
            }

            Divider()

            HSplitView {
                DashboardListPanel(
                    dashboards: model.dashboards,
                    selection: $selectedDashboardID,
                    createDashboard: presentNewDashboard,
                    renameDashboard: { dashboard in
                        namingRequest = DashboardNamingRequest(mode: .rename(dashboard))
                    },
                    deleteDashboard: { dashboard in
                        dashboardPendingDeletion = dashboard
                    },
                    importDashboard: { importing = true }
                )
                .frame(minWidth: 190, idealWidth: 190, maxWidth: 260)

                Group {
                    if let dashboard = selectedDashboard {
                        DashboardCanvasView(
                            model: model,
                            dashboard: displayDashboard(dashboard),
                            isReadOnly: selectedDashboardIsReadOnly,
                            selectedWidgetID: $selectedWidgetID,
                            selectWidget: { selectedWidgetID = $0 },
                            moveWidget: moveWidget,
                            resizeWidget: resizeWidget,
                            duplicateWidget: duplicateWidget,
                            deleteWidget: deleteWidget
                        )
                        .id(dashboard.id)
                    } else {
                        DashboardEmptyView(
                            hasDashboards: !model.dashboards.isEmpty,
                            createDashboard: presentNewDashboard
                        )
                    }
                }
                .frame(minWidth: 250, maxWidth: .infinity, maxHeight: .infinity)

                DashboardInspectorView(
                    widget: selectedWidget,
                    isReadOnly: selectedDashboardIsReadOnly,
                    sourceOptions: selectedWidget.map(sourceOptions(for:)) ?? [],
                    updateWidget: updateWidget,
                    moveWidget: moveSelectedWidget,
                    resizeWidget: resizeSelectedWidget,
                    duplicateWidget: duplicateSelectedWidget,
                    deleteWidget: deleteSelectedWidget
                )
                .frame(minWidth: 240, idealWidth: 240, maxWidth: 300)
            }
        }
        .navigationTitle(L10n.string("dashboard.title", language: language))
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            importDashboard(result)
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case let .failure(error) = result {
                errorMessage = error.localizedDescription
            }
            exportDocument = nil
        }
        .sheet(item: $namingRequest) { request in
            DashboardNameEditor(
                title: request.title(language: language),
                initialName: request.initialName,
                saveLabel: request.saveLabel(language: language),
                onCancel: { namingRequest = nil },
                onSave: { name in saveName(name, for: request) }
            )
            .environment(\.linkScopeLanguage, language)
        }
        .alert(
            L10n.string("dashboard.delete.title", language: language),
            isPresented: Binding(
                get: { dashboardPendingDeletion != nil },
                set: { if !$0 { dashboardPendingDeletion = nil } }
            )
        ) {
            Button(L10n.string("common.cancel", language: language), role: .cancel) {
                dashboardPendingDeletion = nil
            }
            Button(L10n.string("dashboard.delete", language: language), role: .destructive) {
                confirmDashboardDeletion()
            }
        } message: {
            Text(String(
                format: L10n.string("dashboard.delete.message", language: language),
                dashboardPendingDeletion?.name ?? ""
            ))
        }
        .alert(
            L10n.string("dashboard.error.title", language: language),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(L10n.string("common.done", language: language), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            ensureDashboardSelection()
        }
        .onChange(of: model.dashboards.map(\.id)) { _, _ in
            ensureDashboardSelection()
        }
        .onChange(of: selectedDashboardID) { _, _ in
            selectedWidgetID = nil
        }
        .onChange(of: selectedDashboard?.widgets.map(\.id) ?? []) { _, widgetIDs in
            if let selectedWidgetID, !widgetIDs.contains(selectedWidgetID) {
                self.selectedWidgetID = nil
            }
        }
    }

    private var selectedDashboard: DashboardDocument? {
        guard let selectedDashboardID else { return nil }
        return model.dashboards.first { $0.id == selectedDashboardID }
    }

    private var selectedWidget: DashboardWidget? {
        guard let selectedWidgetID else { return nil }
        return selectedDashboard?.widgets.first { $0.id == selectedWidgetID }
    }

    private var selectedDashboardIsReadOnly: Bool {
        guard let selectedDashboard else { return false }
        return selectedDashboard.schemaVersion > DashboardDocument.currentSchemaVersion
    }

    private func displayDashboard(_ dashboard: DashboardDocument) -> DashboardDocument {
        guard dashboard.schemaVersion > DashboardDocument.currentSchemaVersion else {
            return dashboard
        }
        // A future document remains byte-for-byte portable in model/storage.
        // Only this non-editable projection is reflowed so every unknown
        // placement remains visible on the current twelve-column canvas.
        return DashboardLayoutEngine.normalized(dashboard)
    }

    private var exportFilename: String {
        let rawName = selectedDashboard?.name ?? "LinkScope-Dashboard"
        let invalid = CharacterSet(charactersIn: "/:")
        let safeName = rawName.components(separatedBy: invalid).joined(separator: "-")
        return safeName.isEmpty ? "LinkScope-Dashboard.json" : "\(safeName).json"
    }

    private func ensureDashboardSelection() {
        if let selectedDashboardID,
           model.dashboards.contains(where: { $0.id == selectedDashboardID }) {
            return
        }
        selectedDashboardID = model.dashboards.first?.id
    }

    private func presentNewDashboard() {
        namingRequest = DashboardNamingRequest(mode: .create)
    }

    private func presentRenameDashboard() {
        guard let selectedDashboard, !selectedDashboardIsReadOnly else { return }
        namingRequest = DashboardNamingRequest(mode: .rename(selectedDashboard))
    }

    private func presentDeleteDashboard() {
        dashboardPendingDeletion = selectedDashboard
    }

    private func saveName(_ name: String, for request: DashboardNamingRequest) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        switch request.mode {
        case .create:
            let dashboard = DashboardDocument(name: trimmedName)
            undoController.setPresence(
                dashboard,
                isPresent: true,
                model: model,
                undoManager: undoManager,
                actionName: L10n.string("dashboard.undo.create", language: language)
            )
            selectedDashboardID = dashboard.id
        case let .rename(dashboard):
            guard dashboard.schemaVersion <= DashboardDocument.currentSchemaVersion else {
                namingRequest = nil
                return
            }
            var updated = dashboard
            updated.name = trimmedName
            apply(
                updated,
                replacing: dashboard,
                actionName: L10n.string("dashboard.undo.rename", language: language)
            )
        }
        namingRequest = nil
    }

    private func confirmDashboardDeletion() {
        guard let dashboard = dashboardPendingDeletion else { return }
        undoController.setPresence(
            dashboard,
            isPresent: false,
            model: model,
            undoManager: undoManager,
            actionName: L10n.string("dashboard.undo.delete", language: language)
        )
        dashboardPendingDeletion = nil
        selectedWidgetID = nil
        ensureDashboardSelection()
    }

    private func addWidget(_ kind: DashboardWidget.Kind) {
        guard var dashboard = selectedDashboard, !selectedDashboardIsReadOnly else { return }
        let source = sourceOptions(for: kind).first?.id
        let size = DashboardGrid.defaultSize(for: kind)
        let placement = DashboardGrid.firstAvailablePlacement(
            in: dashboard,
            columnSpan: size.columns,
            rowSpan: size.rows
        )
        let widget = DashboardWidget(
            kind: kind,
            sourceIDs: source.map { [$0] } ?? [],
            placement: placement,
            configuration: ["precision": .signedInt(2)]
        )
        let previous = dashboard
        dashboard.widgets.append(widget)
        apply(
            dashboard,
            replacing: previous,
            actionName: L10n.string("dashboard.undo.addWidget", language: language)
        )
        selectedWidgetID = widget.id
    }

    private func updateWidget(
        id: UUID,
        edit: DashboardWidget.ContentEdit,
        actionName: String
    ) {
        guard var dashboard = selectedDashboard, !selectedDashboardIsReadOnly else { return }
        let previous = dashboard
        dashboard.apply(edit, toWidget: id)
        apply(dashboard, replacing: previous, actionName: actionName)
    }

    private func moveWidget(id: UUID, columns: Int, rows: Int) {
        guard let dashboard = selectedDashboard, !selectedDashboardIsReadOnly,
              let updated = DashboardGrid.movingWidget(
                id: id,
                in: dashboard,
                columns: columns,
                rows: rows
              ), updated != dashboard else { return }
        apply(
            updated,
            replacing: dashboard,
            actionName: L10n.string("dashboard.undo.moveWidget", language: language)
        )
    }

    private func resizeWidget(id: UUID, columns: Int, rows: Int) {
        guard let dashboard = selectedDashboard, !selectedDashboardIsReadOnly,
              let updated = DashboardGrid.resizingWidget(
                id: id,
                in: dashboard,
                columns: columns,
                rows: rows
              ), updated != dashboard else { return }
        apply(
            updated,
            replacing: dashboard,
            actionName: L10n.string("dashboard.undo.resizeWidget", language: language)
        )
    }

    private func duplicateWidget(id: UUID) {
        guard let dashboard = selectedDashboard, !selectedDashboardIsReadOnly,
              let result = DashboardGrid.duplicatingWidget(id: id, in: dashboard) else { return }
        apply(
            result.dashboard,
            replacing: dashboard,
            actionName: L10n.string("dashboard.undo.duplicateWidget", language: language)
        )
        selectedWidgetID = result.widgetID
    }

    private func deleteWidget(id: UUID) {
        guard var dashboard = selectedDashboard, !selectedDashboardIsReadOnly,
              dashboard.widgets.contains(where: { $0.id == id }) else { return }
        let previous = dashboard
        dashboard.widgets.removeAll { $0.id == id }
        apply(
            dashboard,
            replacing: previous,
            actionName: L10n.string("dashboard.undo.deleteWidget", language: language)
        )
        if selectedWidgetID == id {
            selectedWidgetID = nil
        }
    }

    private func moveSelectedWidget(columns: Int, rows: Int) {
        guard let selectedWidgetID else { return }
        moveWidget(id: selectedWidgetID, columns: columns, rows: rows)
    }

    private func resizeSelectedWidget(columns: Int, rows: Int) {
        guard let selectedWidgetID else { return }
        resizeWidget(id: selectedWidgetID, columns: columns, rows: rows)
    }

    private func duplicateSelectedWidget() {
        guard let selectedWidgetID else { return }
        duplicateWidget(id: selectedWidgetID)
    }

    private func deleteSelectedWidget() {
        guard let selectedWidgetID else { return }
        deleteWidget(id: selectedWidgetID)
    }

    private func apply(
        _ updated: DashboardDocument,
        replacing previous: DashboardDocument,
        actionName: String
    ) {
        guard updated != previous,
              previous.schemaVersion <= DashboardDocument.currentSchemaVersion else { return }
        undoController.apply(
            updated,
            replacing: previous,
            model: model,
            undoManager: undoManager,
            actionName: actionName
        )
    }

    private func sourceOptions(for widget: DashboardWidget) -> [DashboardSourceOption] {
        sourceOptions(for: widget.kind)
    }

    private func sourceOptions(for kind: DashboardWidget.Kind) -> [DashboardSourceOption] {
        DashboardSourceCatalog.options(
            for: kind,
            monitoringSources: model.monitoringSources,
            providers: model.providerDescriptors
        )
    }

    private func prepareExport() {
        guard let selectedDashboard else { return }
        do {
            exportDocument = try DashboardJSONDocument(dashboard: selectedDashboard)
            exporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importDashboard(_ result: Result<URL, Error>) {
        switch result {
        case let .failure(error):
            errorMessage = error.localizedDescription
        case let .success(url):
            Task {
                do {
                    let data = try await Task.detached {
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        return try Data(contentsOf: url)
                    }.value
                    var dashboard = try await Task.detached {
                        try DashboardDocumentCodec.decode(data)
                    }.value
                    if DashboardDocumentCodec.compatibility(of: dashboard) != .newer(dashboard.schemaVersion) {
                        dashboard = DashboardGrid.normalized(dashboard)
                    }
                    if model.dashboards.contains(where: { $0.id == dashboard.id }) {
                        dashboard = DashboardDocument(
                            schemaVersion: dashboard.schemaVersion,
                            id: UUID(),
                            name: dashboard.name,
                            columns: dashboard.columns,
                            widgets: dashboard.widgets,
                            extensionFields: dashboard.extensionFields
                        )
                    }
                    undoController.setPresence(
                        dashboard,
                        isPresent: true,
                        model: model,
                        undoManager: undoManager,
                        actionName: L10n.string("dashboard.undo.import", language: language)
                    )
                    selectedDashboardID = dashboard.id
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct DashboardActionBar: View {
    let dashboard: DashboardDocument?
    let selectedWidget: DashboardWidget?
    let isReadOnly: Bool
    let createDashboard: () -> Void
    let renameDashboard: () -> Void
    let deleteDashboard: () -> Void
    let importDashboard: () -> Void
    let exportDashboard: () -> Void
    let addWidget: (DashboardWidget.Kind) -> Void
    let duplicateWidget: () -> Void
    let deleteWidget: () -> Void
    let moveWidget: (Int, Int) -> Void
    let resizeWidget: (Int, Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(dashboard?.name ?? L10n.string("dashboard.title"))
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                if let dashboard {
                    Text(String(
                        format: L10n.string("dashboard.widgetCount"),
                        dashboard.widgets.count
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Button(action: createDashboard) {
                Label(L10n.string("dashboard.new"), systemImage: "plus")
            }
            .labelStyle(.iconOnly)
            .help(L10n.string("dashboard.new.help"))

            Button(action: importDashboard) {
                Label(L10n.string("dashboard.import"), systemImage: "square.and.arrow.down")
            }
            .labelStyle(.iconOnly)
            .help(L10n.string("dashboard.import"))

            Menu {
                Button(L10n.string("dashboard.rename"), action: renameDashboard)
                    .disabled(isReadOnly)
                Button(L10n.string("dashboard.delete"), role: .destructive, action: deleteDashboard)
                Divider()
                Button(L10n.string("dashboard.export"), action: exportDashboard)
            } label: {
                Label(L10n.string("dashboard.actions"), systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .help(L10n.string("dashboard.actions"))
            .disabled(dashboard == nil)

            Divider().frame(height: 20)

            Menu {
                ForEach(DashboardWidgetChoice.all) { choice in
                    Button {
                        addWidget(choice.kind)
                    } label: {
                        Label(L10n.string(choice.titleKey), systemImage: choice.icon)
                    }
                }
            } label: {
                Label(L10n.string("dashboard.addWidget"), systemImage: "plus.square.on.square")
            }
            .disabled(dashboard == nil || isReadOnly)

            Menu {
                Section(L10n.string("dashboard.move")) {
                    Button(L10n.string("dashboard.move.left")) { moveWidget(-1, 0) }
                    Button(L10n.string("dashboard.move.right")) { moveWidget(1, 0) }
                    Button(L10n.string("dashboard.move.up")) { moveWidget(0, -1) }
                    Button(L10n.string("dashboard.move.down")) { moveWidget(0, 1) }
                }
                Section(L10n.string("dashboard.resize")) {
                    Button(L10n.string("dashboard.resize.narrower")) { resizeWidget(-1, 0) }
                    Button(L10n.string("dashboard.resize.wider")) { resizeWidget(1, 0) }
                    Button(L10n.string("dashboard.resize.shorter")) { resizeWidget(0, -1) }
                    Button(L10n.string("dashboard.resize.taller")) { resizeWidget(0, 1) }
                }
            } label: {
                Label(L10n.string("dashboard.arrange"), systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .labelStyle(.iconOnly)
            .help(L10n.string("dashboard.arrange"))
            .disabled(selectedWidget == nil || isReadOnly)

            Button(action: duplicateWidget) {
                Label(L10n.string("dashboard.duplicateWidget"), systemImage: "plus.square.on.square")
            }
            .labelStyle(.iconOnly)
            .help(L10n.string("dashboard.duplicateWidget"))
            .disabled(selectedWidget == nil || isReadOnly)

            Button(role: .destructive, action: deleteWidget) {
                Label(L10n.string("dashboard.deleteWidget"), systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .help(L10n.string("dashboard.deleteWidget"))
            .disabled(selectedWidget == nil || isReadOnly)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct DashboardListPanel: View {
    let dashboards: [DashboardDocument]
    @Binding var selection: UUID?
    let createDashboard: () -> Void
    let renameDashboard: (DashboardDocument) -> Void
    let deleteDashboard: (DashboardDocument) -> Void
    let importDashboard: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L10n.string("dashboard.list"), systemImage: "rectangle.3.group")
                    .font(.headline)
                Spacer()
                Button(action: createDashboard) {
                    Label(L10n.string("dashboard.new"), systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .help(L10n.string("dashboard.new"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if dashboards.isEmpty {
                ContentUnavailableView {
                    Label(L10n.string("dashboard.empty"), systemImage: "rectangle.3.group")
                } description: {
                    Text(L10n.string("dashboard.empty.description"))
                } actions: {
                    HStack {
                        Button(L10n.string("dashboard.new"), action: createDashboard)
                        Button(L10n.string("dashboard.import"), action: importDashboard)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(dashboards) { dashboard in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dashboard.name)
                                .lineLimit(1)
                            Text(String(
                                format: L10n.string("dashboard.widgetCount"),
                                dashboard.widgets.count
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .tag(dashboard.id)
                        .accessibilityElement(children: .combine)
                        .contextMenu {
                            Button(L10n.string("dashboard.rename")) {
                                renameDashboard(dashboard)
                            }
                            .disabled(
                                dashboard.schemaVersion > DashboardDocument.currentSchemaVersion
                            )
                            Button(L10n.string("dashboard.delete"), role: .destructive) {
                                deleteDashboard(dashboard)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct DashboardEmptyView: View {
    let hasDashboards: Bool
    let createDashboard: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                L10n.string(hasDashboards ? "dashboard.noSelection" : "dashboard.empty"),
                systemImage: "rectangle.3.group"
            )
        } description: {
            Text(L10n.string(
                hasDashboards ? "dashboard.noSelection.description" : "dashboard.empty.description"
            ))
        } actions: {
            Button(L10n.string("dashboard.new"), action: createDashboard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DashboardCompatibilityBanner: View {
    let schemaVersion: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "lock.doc")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(String(
                format: L10n.string("dashboard.compatibility.readOnly"),
                schemaVersion
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.orange.opacity(0.08))
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardCanvasView: View {
    let model: LinkScopeApplicationModel
    let dashboard: DashboardDocument
    let isReadOnly: Bool
    @Binding var selectedWidgetID: UUID?
    let selectWidget: (UUID) -> Void
    let moveWidget: (UUID, Int, Int) -> Void
    let resizeWidget: (UUID, Int, Int) -> Void
    let duplicateWidget: (UUID) -> Void
    let deleteWidget: (UUID) -> Void

    @FocusState private var focusedWidgetID: UUID?

    private let canvasWidth: CGFloat = 960
    private let rowHeight: CGFloat = 96
    private let spacing: CGFloat = 8
    private let inset: CGFloat = 12

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                gridBackground

                ForEach(dashboard.widgets) { widget in
                    DashboardWidgetCard(
                        model: model,
                        widget: widget,
                        isSelected: selectedWidgetID == widget.id,
                        isEditable: !isReadOnly,
                        select: {
                            selectWidget(widget.id)
                            focusedWidgetID = widget.id
                        },
                        moveByDrag: { translation in
                            moveWidget(
                                widget.id,
                                Int((translation.width / columnStep).rounded()),
                                Int((translation.height / rowStep).rounded())
                            )
                        },
                        resizeByDrag: { translation in
                            resizeWidget(
                                widget.id,
                                Int((translation.width / columnStep).rounded()),
                                Int((translation.height / rowStep).rounded())
                            )
                        },
                        duplicate: { duplicateWidget(widget.id) },
                        delete: { deleteWidget(widget.id) },
                        move: { columns, rows in moveWidget(widget.id, columns, rows) },
                        resize: { columns, rows in resizeWidget(widget.id, columns, rows) }
                    )
                    .frame(
                        width: widgetWidth(widget.placement),
                        height: widgetHeight(widget.placement)
                    )
                    .offset(
                        x: inset + CGFloat(widget.placement.column) * columnStep,
                        y: inset + CGFloat(widget.placement.row) * rowStep
                    )
                    .focused($focusedWidgetID, equals: widget.id)
                    .zIndex(selectedWidgetID == widget.id ? 1 : 0)
                }

                if dashboard.widgets.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.string("dashboard.canvas.empty"), systemImage: "plus.square.dashed")
                    } description: {
                        Text(L10n.string("dashboard.canvas.empty.description"))
                    }
                    .frame(width: canvasWidth - inset * 2, height: 360)
                    .offset(x: inset, y: 90)
                }
            }
            .frame(width: canvasWidth, height: canvasHeight, alignment: .topLeading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(
                format: L10n.string("dashboard.canvas.accessibilityLabel"),
                dashboard.name,
                dashboard.widgets.count
            ))
            .padding(12)
        }
        .background(.quaternary.opacity(0.18))
        .onChange(of: selectedWidgetID) { _, selection in
            focusedWidgetID = selection
        }
    }

    private var gridBackground: some View {
        HStack(spacing: spacing) {
            ForEach(0..<DashboardDocument.gridColumnCount, id: \.self) { column in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(column.isMultiple(of: 2) ? 0.10 : 0.05))
                    .frame(width: columnWidth, height: canvasHeight - inset * 2)
                    .accessibilityHidden(true)
            }
        }
        .offset(x: inset, y: inset)
    }

    private var columnWidth: CGFloat {
        (canvasWidth - inset * 2 - spacing * CGFloat(DashboardDocument.gridColumnCount - 1))
            / CGFloat(DashboardDocument.gridColumnCount)
    }

    private var columnStep: CGFloat { columnWidth + spacing }
    private var rowStep: CGFloat { rowHeight + spacing }

    private var canvasHeight: CGFloat {
        let occupiedRows = dashboard.widgets.map {
            $0.placement.row + $0.placement.rowSpan
        }.max() ?? 0
        return max(560, inset * 2 + CGFloat(occupiedRows) * rowStep - spacing)
    }

    private func widgetWidth(_ placement: GridPlacement) -> CGFloat {
        CGFloat(placement.columnSpan) * columnWidth
            + CGFloat(max(0, placement.columnSpan - 1)) * spacing
    }

    private func widgetHeight(_ placement: GridPlacement) -> CGFloat {
        CGFloat(placement.rowSpan) * rowHeight
            + CGFloat(max(0, placement.rowSpan - 1)) * spacing
    }
}

private struct DashboardWidgetCard: View {
    let model: LinkScopeApplicationModel
    let widget: DashboardWidget
    let isSelected: Bool
    let isEditable: Bool
    let select: () -> Void
    let moveByDrag: (CGSize) -> Void
    let resizeByDrag: (CGSize) -> Void
    let duplicate: () -> Void
    let delete: () -> Void
    let move: (Int, Int) -> Void
    let resize: (Int, Int) -> Void

    var body: some View {
        cardSurface
            .modifier(DashboardWidgetInteractionModifier(
                isEditable: isEditable,
                select: select,
                duplicate: duplicate,
                delete: delete,
                move: move,
                resize: resize
            ))
            .modifier(DashboardWidgetAccessibilityModifier(
                widget: widget,
                isEditable: isEditable,
                duplicate: duplicate,
                delete: delete,
                move: move
            ))
    }

    private var cardSurface: some View {
        VStack(spacing: 0) {
            DashboardWidgetHeader(
                widget: widget,
                isSelected: isSelected,
                isEditable: isEditable,
                moveByDrag: moveByDrag
            )

            Divider()

            DashboardWidgetContent(model: model, widget: widget)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .overlay(alignment: .bottomTrailing) {
            if isEditable {
                DashboardResizeHandle(resizeByDrag: resizeByDrag)
            }
        }
    }
}

private struct DashboardWidgetHeader: View {
    let widget: DashboardWidget
    let isSelected: Bool
    let isEditable: Bool
    let moveByDrag: (CGSize) -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Image(systemName: DashboardWidgetChoice.icon(for: widget.kind))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(DashboardWidgetPresentation.title(for: widget))
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 4)
            if isSelected {
                Label(L10n.string("dashboard.selected"), systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 5)
                .onEnded { if isEditable { moveByDrag($0.translation) } }
        )
        .help(L10n.string("dashboard.drag.help"))
    }
}

private struct DashboardWidgetInteractionModifier: ViewModifier {
    let isEditable: Bool
    let select: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void
    let move: (Int, Int) -> Void
    let resize: (Int, Int) -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture(perform: select)
            .focusable(true)
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) {
                handleArrowKey($0)
            }
            .onKeyPress(.delete) {
                guard isEditable else { return .ignored }
                delete()
                return .handled
            }
            .onKeyPress("d", phases: .down) { press in
                guard isEditable, press.modifiers.contains(.command) else { return .ignored }
                duplicate()
                return .handled
            }
            .contextMenu {
                Button(L10n.string("dashboard.duplicateWidget"), action: duplicate)
                    .disabled(!isEditable)
                Divider()
                Button(L10n.string("dashboard.deleteWidget"), role: .destructive, action: delete)
                    .disabled(!isEditable)
            }
    }

    private func handleArrowKey(_ press: KeyPress) -> KeyPress.Result {
        guard isEditable else { return .ignored }
        let delta: (Int, Int)
        switch press.key {
        case .leftArrow: delta = (-1, 0)
        case .rightArrow: delta = (1, 0)
        case .upArrow: delta = (0, -1)
        case .downArrow: delta = (0, 1)
        default: return .ignored
        }
        if press.modifiers.contains(.option) {
            resize(delta.0, delta.1)
        } else {
            move(delta.0, delta.1)
        }
        return .handled
    }
}

private struct DashboardWidgetAccessibilityModifier: ViewModifier {
    let widget: DashboardWidget
    let isEditable: Bool
    let duplicate: () -> Void
    let delete: () -> Void
    let move: (Int, Int) -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(L10n.string(
                isEditable
                    ? "dashboard.widget.accessibilityHint"
                    : "dashboard.widget.readOnly.accessibilityHint"
            ))
            .accessibilityAction(named: L10n.string("dashboard.move.left")) {
                if isEditable { move(-1, 0) }
            }
            .accessibilityAction(named: L10n.string("dashboard.move.right")) {
                if isEditable { move(1, 0) }
            }
            .accessibilityAction(named: L10n.string("dashboard.move.up")) {
                if isEditable { move(0, -1) }
            }
            .accessibilityAction(named: L10n.string("dashboard.move.down")) {
                if isEditable { move(0, 1) }
            }
            .accessibilityAction(named: L10n.string("dashboard.duplicateWidget")) {
                if isEditable { duplicate() }
            }
            .accessibilityAction(named: L10n.string("dashboard.deleteWidget")) {
                if isEditable { delete() }
            }
    }

    private var accessibilityLabel: String {
        String(
            format: L10n.string("dashboard.widget.accessibilityLabel"),
            DashboardWidgetPresentation.title(for: widget),
            widget.placement.column + 1,
            widget.placement.row + 1,
            widget.placement.columnSpan,
            widget.placement.rowSpan
        )
    }
}

private struct DashboardResizeHandle: View {
    let resizeByDrag: (CGSize) -> Void

    var body: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(7)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onEnded { resizeByDrag($0.translation) }
            )
            .help(L10n.string("dashboard.resize.drag.help"))
            .accessibilityLabel(L10n.string("dashboard.resize"))
    }
}

private struct DashboardInspectorView: View {
    let widget: DashboardWidget?
    let isReadOnly: Bool
    let sourceOptions: [DashboardSourceOption]
    let updateWidget: (UUID, DashboardWidget.ContentEdit, String) -> Void
    let moveWidget: (Int, Int) -> Void
    let resizeWidget: (Int, Int) -> Void
    let duplicateWidget: () -> Void
    let deleteWidget: () -> Void

    @State private var titleDraft = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L10n.string("dashboard.inspector"), systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let widget {
                Form {
                    Section(L10n.string("dashboard.inspector.content")) {
                        TextField(L10n.string("dashboard.widget.title"), text: $titleDraft)
                            .focused($titleFocused)
                            .onSubmit { commitTitle(widget) }
                            .disabled(contentIsReadOnly(widget))

                        if DashboardSourceCatalog.requiresSource(widget.kind) {
                            Picker(
                                L10n.string("dashboard.widget.source"),
                                selection: sourceBinding(widget)
                            ) {
                                Text(L10n.string("dashboard.widget.source.none"))
                                    .tag(nil as WidgetSourceID?)
                                ForEach(sourceOptions) { option in
                                    Text(option.label).tag(option.id as WidgetSourceID?)
                                }
                            }
                            .disabled(contentIsReadOnly(widget))

                            if let sourceID = widget.sourceIDs.first {
                                Text(sourceID.rawValue)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }

                        Stepper(
                            L10n.formatted(
                                "dashboard.widget.precision.value",
                                language: currentLanguage,
                                DashboardWidgetPresentation.precision(for: widget)
                            ),
                            value: precisionBinding(widget),
                            in: 0...6
                        )
                        .disabled(
                            contentIsReadOnly(widget)
                                || !DashboardWidgetPresentation.supportsPrecision(widget.kind)
                        )

                        if widget.opaqueConfiguration != nil {
                            Label(
                                L10n.string("dashboard.widget.opaqueConfiguration"),
                                systemImage: "lock.doc"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Section(L10n.string("dashboard.inspector.layout")) {
                        LabeledContent(L10n.string("dashboard.widget.position")) {
                            Text("\(widget.placement.column + 1), \(widget.placement.row + 1)")
                                .monospacedDigit()
                        }
                        LabeledContent(L10n.string("dashboard.widget.size")) {
                            Text("\(widget.placement.columnSpan) × \(widget.placement.rowSpan)")
                                .monospacedDigit()
                        }

                        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                            GridRow {
                                Spacer()
                                inspectorButton("dashboard.move.up", icon: "arrow.up") {
                                    moveWidget(0, -1)
                                }
                                Spacer()
                            }
                            GridRow {
                                inspectorButton("dashboard.move.left", icon: "arrow.left") {
                                    moveWidget(-1, 0)
                                }
                                inspectorButton("dashboard.move.down", icon: "arrow.down") {
                                    moveWidget(0, 1)
                                }
                                inspectorButton("dashboard.move.right", icon: "arrow.right") {
                                    moveWidget(1, 0)
                                }
                            }
                        }

                        HStack {
                            Button(L10n.string("dashboard.resize.narrower")) { resizeWidget(-1, 0) }
                            Button(L10n.string("dashboard.resize.wider")) { resizeWidget(1, 0) }
                        }
                        HStack {
                            Button(L10n.string("dashboard.resize.shorter")) { resizeWidget(0, -1) }
                            Button(L10n.string("dashboard.resize.taller")) { resizeWidget(0, 1) }
                        }
                    }
                    .disabled(isReadOnly)

                    Section {
                        Button(L10n.string("dashboard.duplicateWidget"), action: duplicateWidget)
                        Button(
                            L10n.string("dashboard.deleteWidget"),
                            role: .destructive,
                            action: deleteWidget
                        )
                    }
                    .disabled(isReadOnly)
                }
                .formStyle(.grouped)
                .onAppear { titleDraft = DashboardWidgetPresentation.customTitle(for: widget) }
                .onChange(of: widget.id) { _, _ in
                    titleDraft = DashboardWidgetPresentation.customTitle(for: widget)
                }
                .onChange(of: DashboardWidgetPresentation.customTitle(for: widget)) { _, title in
                    if !titleFocused { titleDraft = title }
                }
                .onChange(of: titleFocused) { _, focused in
                    if !focused { commitTitle(widget) }
                }
            } else {
                ContentUnavailableView {
                    Label(L10n.string("dashboard.inspector.empty"), systemImage: "slider.horizontal.3")
                } description: {
                    Text(L10n.string("dashboard.inspector.empty.description"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @Environment(\.linkScopeLanguage) private var currentLanguage

    private func sourceBinding(_ widget: DashboardWidget) -> Binding<WidgetSourceID?> {
        Binding(
            get: { widget.sourceIDs.first },
            set: { newValue in
                guard !contentIsReadOnly(widget) else { return }
                updateWidget(
                    widget.id,
                    .sourceIDs(newValue.map { [$0] } ?? []),
                    L10n.string("dashboard.undo.configureWidget")
                )
            }
        )
    }

    private func precisionBinding(_ widget: DashboardWidget) -> Binding<Int> {
        Binding(
            get: { DashboardWidgetPresentation.precision(for: widget) },
            set: { value in
                guard !contentIsReadOnly(widget) else { return }
                updateWidget(
                    widget.id,
                    .configurationValue(key: "precision", value: .signedInt(Int64(value))),
                    L10n.string("dashboard.undo.configureWidget")
                )
            }
        )
    }

    private func commitTitle(_ widget: DashboardWidget) {
        guard !contentIsReadOnly(widget) else { return }
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        updateWidget(
            widget.id,
            .configurationValue(key: "title", value: trimmed.isEmpty ? nil : .string(trimmed)),
            L10n.string("dashboard.undo.configureWidget")
        )
    }

    private func contentIsReadOnly(_ widget: DashboardWidget) -> Bool {
        isReadOnly || widget.opaqueConfiguration != nil
    }

    private func inspectorButton(
        _ key: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(L10n.string(key), systemImage: icon)
        }
        .labelStyle(.iconOnly)
        .help(L10n.string(key))
    }
}

private struct DashboardNameEditor: View {
    @State private var name: String
    let title: String
    let saveLabel: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    init(
        title: String,
        initialName: String,
        saveLabel: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.saveLabel = saveLabel
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.weight(.semibold))
            TextField(L10n.string("dashboard.name"), text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            HStack {
                Spacer()
                Button(L10n.string("common.cancel"), action: onCancel)
                Button(saveLabel, action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSave(name)
    }
}

private struct DashboardWidgetContent: View {
    let model: LinkScopeApplicationModel
    let widget: DashboardWidget

    var body: some View {
        Group {
            if !widget.kind.isSupported {
                DashboardUnavailableWidgetView(
                    icon: "questionmark.app.dashed",
                    title: L10n.string("dashboard.widget.unsupportedType"),
                    detail: String(
                        format: L10n.string("dashboard.widget.unsupportedType.description"),
                        widget.kind.rawValue
                    ),
                    sourceID: widget.sourceIDs.first
                )
            } else if DashboardSourceCatalog.requiresSource(widget.kind),
                      widget.sourceIDs.first == nil {
                DashboardUnavailableWidgetView(
                    icon: "slider.horizontal.3",
                    title: L10n.string("dashboard.widget.configureSource"),
                    detail: L10n.string("dashboard.widget.configureSource.description"),
                    sourceID: nil
                )
            } else if let sourceID = widget.sourceIDs.first,
                      !DashboardSourceCatalog.isAvailable(
                        sourceID,
                        for: widget.kind,
                        monitoringSources: model.monitoringSources,
                        providers: model.providerDescriptors
                      ) {
                DashboardUnavailableWidgetView(
                    icon: "exclamationmark.triangle",
                    title: L10n.string("dashboard.widget.sourceUnavailable"),
                    detail: String(
                        format: L10n.string("dashboard.widget.sourceUnavailable.description"),
                        DashboardWidgetPresentation.editionName(model.edition)
                    ),
                    sourceID: sourceID
                )
            } else if widget.kind == .currentValue {
                DashboardCurrentValueWidget(model: model, widget: widget)
            } else if widget.kind == .status {
                DashboardStatusWidget(model: model, widget: widget)
            } else if widget.kind == .timeSeries {
                DashboardTimeSeriesWidget(model: model, widget: widget)
            } else if widget.kind == .rawTable {
                DashboardRawTableWidget(model: model, widget: widget)
            } else if widget.kind == .timeline {
                DashboardTimelineWidget(events: model.snapshot.timeline)
            } else if widget.kind == .providerHealth {
                DashboardProviderHealthWidget(model: model, widget: widget)
            } else {
                DashboardUnavailableWidgetView(
                    icon: "questionmark.app.dashed",
                    title: L10n.string("dashboard.widget.unsupportedType"),
                    detail: widget.kind.rawValue,
                    sourceID: widget.sourceIDs.first
                )
            }
        }
    }
}

private struct DashboardCurrentValueWidget: View {
    let model: LinkScopeApplicationModel
    let widget: DashboardWidget

    var body: some View {
        if let observation = latestObservation {
            VStack(alignment: .leading, spacing: 7) {
                if observation.observation.availability.code == .available,
                   let value = observation.observation.value {
                    Text(DashboardWidgetPresentation.formatted(value, widget: widget))
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .textSelection(.enabled)
                } else {
                    DashboardAvailabilityLabel(observation.observation.availability)
                }
                Text(observation.observation.parameterPath.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(observation.observation.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
        } else {
            DashboardNoDataView()
        }
    }

    private var latestObservation: ResolvedObservation? {
        DashboardSourceCatalog.latestObservation(
            for: widget.sourceIDs.first,
            in: model.snapshot.observations
        )
    }
}

private struct DashboardStatusWidget: View {
    let model: LinkScopeApplicationModel
    let widget: DashboardWidget

    var body: some View {
        if let observation = latestObservation {
            VStack(alignment: .leading, spacing: 10) {
                DashboardAvailabilityLabel(observation.observation.availability, prominent: true)
                if let detail = observation.observation.availability.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Text(observation.observation.parameterPath.rawValue)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        } else {
            DashboardNoDataView()
        }
    }

    private var latestObservation: ResolvedObservation? {
        DashboardSourceCatalog.latestObservation(
            for: widget.sourceIDs.first,
            in: model.snapshot.observations
        )
    }
}

private struct DashboardTimeSeriesWidget: View {
    let model: LinkScopeApplicationModel
    let widget: DashboardWidget

    @State private var points: [DashboardTimeSeriesPoint] = []
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        Group {
            if isLoading, points.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.string("dashboard.widget.loadingHistory"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, points.isEmpty {
                DashboardUnavailableWidgetView(
                    icon: "exclamationmark.triangle",
                    title: L10n.string("dashboard.widget.historyFailed"),
                    detail: loadError,
                    sourceID: widget.sourceIDs.first
                )
            } else if displayPoints.isEmpty {
                DashboardUnavailableWidgetView(
                    icon: "chart.xyaxis.line",
                    title: L10n.string("dashboard.widget.noNumericHistory"),
                    detail: L10n.string("dashboard.widget.noNumericHistory.description"),
                    sourceID: nil
                )
            } else {
                Chart(displayPoints) { point in
                    LineMark(
                        x: .value(L10n.string("dashboard.chart.time"), point.timestamp),
                        y: .value(L10n.string("dashboard.chart.value"), point.value)
                    )
                    .interpolationMethod(.linear)

                    PointMark(
                        x: .value(L10n.string("dashboard.chart.time"), point.timestamp),
                        y: .value(L10n.string("dashboard.chart.value"), point.value)
                    )
                    .symbolSize(12)
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                }
                .accessibilityChartDescriptor(
                    DashboardChartAccessibilityDescriptor(
                        title: DashboardWidgetPresentation.title(for: widget),
                        summary: accessibilitySummary,
                        points: displayPoints
                    )
                )
            }
        }
        .task(id: historyLoadID) {
            await loadHistory()
        }
    }

    private var historyLoadID: String {
        "\(widget.sourceIDs.first?.rawValue ?? "none"):\(model.dashboardHistoryRevision)"
    }

    private var displayPoints: [DashboardTimeSeriesPoint] {
        guard let sourceID = widget.sourceIDs.first else { return points }
        var unique: [UUID: DashboardTimeSeriesPoint] = [:]
        for point in points {
            unique[point.observationID] = point
        }
        for point in model.dashboardLiveSeries[sourceID, default: []] {
            unique[point.observationID] = point
        }
        return unique.values.sorted {
            if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
            return $0.observationID.uuidString < $1.observationID.uuidString
        }
    }

    private var accessibilitySummary: String {
        let values = displayPoints.map(\.value)
        return String(
            format: L10n.string("dashboard.chart.accessibilitySummary"),
            displayPoints.count,
            values.min() ?? 0,
            values.max() ?? 0
        )
    }

    private func loadHistory() async {
        guard let sourceID = widget.sourceIDs.first else {
            isLoading = false
            points = []
            return
        }
        isLoading = true
        loadError = nil
        do {
            let observations = try await model.dashboardHistory(for: sourceID, limit: 5_000)
            points = await Task.detached(priority: .userInitiated) {
                DashboardTimeSeriesDecimator.decimate(observations, maximumPointCount: 180)
            }.value
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

private struct DashboardChartAccessibilityDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let points: [DashboardTimeSeriesPoint]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xValues = points.map { $0.timestamp.timeIntervalSince1970 }
        let yValues = points.map(\.value)
        let xAxis = AXNumericDataAxisDescriptor(
            title: L10n.string("dashboard.chart.time"),
            range: expandedRange(xValues),
            gridlinePositions: [],
            valueDescriptionProvider: {
                Date(timeIntervalSince1970: $0)
                    .formatted(date: .abbreviated, time: .standard)
            }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: L10n.string("dashboard.chart.value"),
            range: expandedRange(yValues),
            gridlinePositions: [],
            valueDescriptionProvider: {
                $0.formatted(.number.precision(.fractionLength(0...4)))
            }
        )
        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: true,
            dataPoints: points.map {
                AXDataPoint(
                    x: $0.timestamp.timeIntervalSince1970,
                    y: $0.value,
                    label: $0.timestamp.formatted(date: .abbreviated, time: .standard)
                )
            }
        )
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }

    private func expandedRange(_ values: [Double]) -> ClosedRange<Double> {
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        guard minimum == maximum else { return minimum...maximum }
        let padding = max(abs(minimum) * 0.05, 1)
        return (minimum - padding)...(maximum + padding)
    }
}

private struct DashboardRawTableWidget: View {
    let model: LinkScopeApplicationModel
    let widget: DashboardWidget

    var body: some View {
        if rows.isEmpty {
            DashboardNoDataView()
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.string("dashboard.raw.time"))
                    Spacer()
                    Text(L10n.string("dashboard.raw.value"))
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

                ForEach(rows) { row in
                    Divider()
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.observation.timestamp, format: .dateTime.hour().minute().second())
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 6)
                        if row.observation.availability.code == .available,
                           let value = row.observation.value {
                            Text(DashboardWidgetPresentation.formatted(value, widget: widget))
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .textSelection(.enabled)
                        } else {
                            DashboardAvailabilityLabel(row.observation.availability, compact: true)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var rows: [ResolvedObservation] {
        guard let sourceID = widget.sourceIDs.first else { return [] }
        var seen: Set<UUID> = []
        let values = model.snapshot.observations + model.snapshot.history
        return values.filter {
            WidgetSourceID(observationIdentity: $0.observationIdentity) == sourceID
                && seen.insert($0.id).inserted
        }
        .sorted { $0.observation.timestamp > $1.observation.timestamp }
        .prefix(8)
        .map { $0 }
    }
}

private struct DashboardTimelineWidget: View {
    let events: [TimelineEvent]

    var body: some View {
        if events.isEmpty {
            DashboardNoDataView()
        } else {
            VStack(spacing: 0) {
                ForEach(events.prefix(7)) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: DashboardWidgetPresentation.icon(for: event.kind))
                            .frame(width: 16)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.message)
                                .font(.caption)
                                .lineLimit(2)
                            Text(event.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    if event.id != events.prefix(7).last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct DashboardProviderHealthWidget: View {
    let model: LinkScopeApplicationModel
    let widget: DashboardWidget

    var body: some View {
        if let descriptor {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    L10n.string("providerState.\(state.rawValue)"),
                    systemImage: DashboardWidgetPresentation.icon(for: state)
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(DashboardWidgetPresentation.color(for: state))
                Text(descriptor.displayName)
                    .font(.callout)
                    .lineLimit(1)
                Text(descriptor.id.rawValue)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
                if let message = status?.message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            DashboardNoDataView()
        }
    }

    private var providerID: ProviderID? {
        guard let raw = widget.sourceIDs.first?.rawValue,
              raw.hasPrefix("provider:") else { return nil }
        return ProviderID(rawValue: String(raw.dropFirst("provider:".count)))
    }

    private var descriptor: ProviderDescriptor? {
        guard let providerID else { return nil }
        return model.providerDescriptors.first { $0.id == providerID }
    }

    private var status: ProviderStatus? {
        guard let providerID else { return nil }
        return model.snapshot.providerStatuses.first { $0.providerID == providerID }
    }

    private var state: ProviderState { status?.state ?? .idle }
}

private struct DashboardAvailabilityLabel: View {
    let availability: ParameterAvailability
    var prominent = false
    var compact = false

    init(
        _ availability: ParameterAvailability,
        prominent: Bool = false,
        compact: Bool = false
    ) {
        self.availability = availability
        self.prominent = prominent
        self.compact = compact
    }

    var body: some View {
        Label(
            L10n.string("availability.\(availability.code.rawValue)"),
            systemImage: DashboardWidgetPresentation.icon(for: availability.code)
        )
        .font(prominent ? .title3.weight(.semibold) : (compact ? .caption2 : .callout))
        .foregroundStyle(DashboardWidgetPresentation.color(for: availability.code))
        .lineLimit(1)
    }
}

private struct DashboardUnavailableWidgetView: View {
    let icon: String
    let title: String
    let detail: String
    let sourceID: WidgetSourceID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.callout.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if let sourceID {
                Text(sourceID.rawValue)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardNoDataView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
            Text(L10n.string("dashboard.widget.noData"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardSourceOption: Identifiable, Hashable {
    let id: WidgetSourceID
    let label: String
}

private enum DashboardSourceCatalog {
    static func options(
        for kind: DashboardWidget.Kind,
        monitoringSources: [DiagnosticSource],
        providers: [ProviderDescriptor]
    ) -> [DashboardSourceOption] {
        if kind == .providerHealth {
            return providers.map {
                DashboardSourceOption(
                    id: WidgetSourceID(rawValue: "provider:\($0.id.rawValue)"),
                    label: $0.displayName
                )
            }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        }
        guard requiresSource(kind) else { return [] }
        return monitoringSources.map {
            DashboardSourceOption(id: $0.id, label: $0.displayName)
        }
    }

    static func requiresSource(_ kind: DashboardWidget.Kind) -> Bool {
        kind == .currentValue
            || kind == .status
            || kind == .timeSeries
            || kind == .rawTable
            || kind == .providerHealth
    }

    static func isAvailable(
        _ sourceID: WidgetSourceID,
        for kind: DashboardWidget.Kind,
        monitoringSources: [DiagnosticSource],
        providers: [ProviderDescriptor]
    ) -> Bool {
        if kind == .providerHealth {
            return providers.contains {
                sourceID.rawValue == "provider:\($0.id.rawValue)"
            }
        }
        return monitoringSources.contains { $0.id == sourceID }
    }

    static func latestObservation(
        for sourceID: WidgetSourceID?,
        in observations: [ResolvedObservation]
    ) -> ResolvedObservation? {
        guard let sourceID else { return nil }
        return observations
            .filter { WidgetSourceID(observationIdentity: $0.observationIdentity) == sourceID }
            .max { $0.observation.timestamp < $1.observation.timestamp }
    }
}

private enum DashboardWidgetPresentation {
    static func title(for widget: DashboardWidget) -> String {
        let custom = customTitle(for: widget)
        if !custom.isEmpty { return custom }
        if let choice = DashboardWidgetChoice.all.first(where: { $0.kind == widget.kind }) {
            return L10n.string(choice.titleKey)
        }
        return String(
            format: L10n.string("dashboard.widget.unknown.title"),
            widget.kind.rawValue
        )
    }

    static func customTitle(for widget: DashboardWidget) -> String {
        guard case let .string(title)? = widget.configuration["title"] else { return "" }
        return title
    }

    static func precision(for widget: DashboardWidget) -> Int {
        let value: Int
        switch widget.configuration["precision"] {
        case let .signedInt(raw): value = Int(raw)
        case let .unsignedInt(raw): value = Int(clamping: raw)
        case let .double(raw): value = Int(raw)
        default: value = 2
        }
        return min(6, max(0, value))
    }

    static func supportsPrecision(_ kind: DashboardWidget.Kind) -> Bool {
        kind == .currentValue || kind == .timeSeries || kind == .rawTable
    }

    static func formatted(_ value: RawValue, widget: DashboardWidget) -> String {
        let precision = precision(for: widget)
        let style = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(0...precision))
        switch value {
        case let .signedInt(value):
            return value.formatted()
        case let .unsignedInt(value):
            return value.formatted()
        case let .double(value):
            return value.formatted(style)
        case let .decimal(value):
            return Double(value)?.formatted(style) ?? value
        default:
            return value.compactDescription
        }
    }

    static func editionName(_ edition: LinkScopeEdition) -> String {
        L10n.string("dashboard.edition.\(edition.rawValue)")
    }

    static func icon(for code: AvailabilityCode) -> String {
        switch code {
        case .available: "checkmark.circle.fill"
        case .notExposed: "eye.slash"
        case .notReported: "ellipsis.circle"
        case .permissionDenied: "lock.circle"
        case .unsupported: "nosign"
        case .stale: "clock.badge.exclamationmark"
        case .providerFailure: "exclamationmark.triangle.fill"
        }
    }

    static func color(for code: AvailabilityCode) -> Color {
        switch code {
        case .available: .green
        case .notReported, .notExposed: .secondary
        case .stale, .unsupported: .orange
        case .permissionDenied, .providerFailure: .red
        }
    }

    static func icon(for state: ProviderState) -> String {
        switch state {
        case .running: "checkmark.circle.fill"
        case .starting: "arrow.trianglehead.2.clockwise.rotate.90"
        case .permissionDenied: "lock.circle"
        case .unsupported: "nosign"
        case .failed: "exclamationmark.triangle.fill"
        case .idle, .stopped: "pause.circle"
        }
    }

    static func color(for state: ProviderState) -> Color {
        switch state {
        case .running: .green
        case .starting: .blue
        case .permissionDenied, .failed: .red
        case .unsupported: .orange
        case .idle, .stopped: .secondary
        }
    }

    static func icon(for kind: TimelineEvent.Kind) -> String {
        switch kind {
        case .providerStarted: "play.circle"
        case .providerStopped: "stop.circle"
        case .deviceConnected: "link.circle"
        case .deviceDisconnected: "link.badge.minus"
        case .systemSleep: "moon.zzz"
        case .systemWake: "sun.max"
        case .thermalChanged: "thermometer.medium"
        case .snapshotCaptured: "camera"
        case .diagnostic: "waveform.path.ecg"
        case .error: "exclamationmark.triangle"
        }
    }
}

private struct DashboardWidgetChoice: Identifiable {
    let kind: DashboardWidget.Kind
    let titleKey: String
    let icon: String

    var id: String { kind.rawValue }

    static let all: [DashboardWidgetChoice] = [
        DashboardWidgetChoice(
            kind: .currentValue,
            titleKey: "dashboard.widget.currentValue",
            icon: "gauge.with.dots.needle.33percent"
        ),
        DashboardWidgetChoice(
            kind: .status,
            titleKey: "dashboard.widget.status",
            icon: "checkmark.circle"
        ),
        DashboardWidgetChoice(
            kind: .timeSeries,
            titleKey: "dashboard.widget.timeSeries",
            icon: "chart.xyaxis.line"
        ),
        DashboardWidgetChoice(
            kind: .rawTable,
            titleKey: "dashboard.widget.rawTable",
            icon: "tablecells"
        ),
        DashboardWidgetChoice(
            kind: .timeline,
            titleKey: "dashboard.widget.timeline",
            icon: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        ),
        DashboardWidgetChoice(
            kind: .providerHealth,
            titleKey: "dashboard.widget.providerHealth",
            icon: "wave.3.right.circle"
        )
    ]

    static func icon(for kind: DashboardWidget.Kind) -> String {
        all.first(where: { $0.kind == kind })?.icon ?? "questionmark.app.dashed"
    }
}

/// UI-only coordinate adapter. All normalization, collision handling, and
/// placement decisions remain owned by DashboardLayoutEngine in LinkScopeCore.
private enum DashboardGrid {
    static func defaultSize(
        for kind: DashboardWidget.Kind
    ) -> (columns: Int, rows: Int) {
        let placement = DashboardLayoutEngine.defaultSize(for: kind)
        return (placement.columnSpan, placement.rowSpan)
    }

    static func firstAvailablePlacement(
        in dashboard: DashboardDocument,
        columnSpan: Int,
        rowSpan: Int
    ) -> GridPlacement {
        DashboardLayoutEngine.placeholder(
            for: GridPlacement(
                column: 0,
                row: 0,
                columnSpan: columnSpan,
                rowSpan: rowSpan
            ),
            in: dashboard
        )
    }

    static func normalized(_ dashboard: DashboardDocument) -> DashboardDocument {
        DashboardLayoutEngine.normalized(dashboard)
    }

    static func movingWidget(
        id: UUID,
        in dashboard: DashboardDocument,
        columns: Int,
        rows: Int
    ) -> DashboardDocument? {
        do {
            return try DashboardLayoutEngine.movingWidget(
                id: id,
                columns: columns,
                rows: rows,
                in: dashboard
            )
        } catch {
            return nil
        }
    }

    static func resizingWidget(
        id: UUID,
        in dashboard: DashboardDocument,
        columns: Int,
        rows: Int
    ) -> DashboardDocument? {
        do {
            return try DashboardLayoutEngine.resizingWidget(
                id: id,
                columns: columns,
                rows: rows,
                in: dashboard
            )
        } catch {
            return nil
        }
    }

    static func duplicatingWidget(
        id: UUID,
        in dashboard: DashboardDocument
    ) -> (dashboard: DashboardDocument, widgetID: UUID)? {
        let newID = UUID()
        do {
            return (
                try DashboardLayoutEngine.duplicatingWidget(
                    id: id,
                    newID: newID,
                    in: dashboard
                ),
                newID
            )
        } catch {
            return nil
        }
    }
}

@MainActor
private final class DashboardUndoController: ObservableObject {
    func apply(
        _ updated: DashboardDocument,
        replacing previous: DashboardDocument,
        model: LinkScopeApplicationModel,
        undoManager: UndoManager?,
        actionName: String
    ) {
        model.applyDashboard(updated)
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { [weak model, weak undoManager] target in
            guard let model, let undoManager else { return }
            target.apply(
                previous,
                replacing: updated,
                model: model,
                undoManager: undoManager,
                actionName: actionName
            )
        }
        undoManager.setActionName(actionName)
    }

    func setPresence(
        _ dashboard: DashboardDocument,
        isPresent: Bool,
        model: LinkScopeApplicationModel,
        undoManager: UndoManager?,
        actionName: String
    ) {
        if isPresent {
            model.applyDashboard(dashboard)
        } else {
            model.deleteDashboard(id: dashboard.id)
        }
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { [weak model, weak undoManager] target in
            guard let model, let undoManager else { return }
            target.setPresence(
                dashboard,
                isPresent: !isPresent,
                model: model,
                undoManager: undoManager,
                actionName: actionName
            )
        }
        undoManager.setActionName(actionName)
    }
}

private struct DashboardNamingRequest: Identifiable {
    enum Mode {
        case create
        case rename(DashboardDocument)
    }

    let id = UUID()
    let mode: Mode

    var initialName: String {
        switch mode {
        case .create: ""
        case let .rename(dashboard): dashboard.name
        }
    }

    func title(language: AppLanguage) -> String {
        switch mode {
        case .create: L10n.string("dashboard.new", language: language)
        case .rename: L10n.string("dashboard.rename", language: language)
        }
    }

    func saveLabel(language: AppLanguage) -> String {
        switch mode {
        case .create: L10n.string("dashboard.create", language: language)
        case .rename: L10n.string("dashboard.rename", language: language)
        }
    }
}

private struct DashboardJSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(dashboard: DashboardDocument) throws {
        data = try DashboardDocumentCodec.encode(dashboard)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
