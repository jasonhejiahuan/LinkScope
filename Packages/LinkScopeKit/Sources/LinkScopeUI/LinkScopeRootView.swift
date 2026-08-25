import AppKit
import LinkScopeCore
import SwiftUI
import UniformTypeIdentifiers

private enum InspectorSelection: Hashable {
    case device(UUID)
    case dashboard
    case providers
    case timeline
    case diagnostics
}

public struct LinkScopeRootView: View {
    public let model: LinkScopeApplicationModel
    @AppStorage("LinkScope.uiLanguage") private var languageCode = AppLanguage.defaultLanguage.rawValue
    @AppStorage("LinkScope.sidebarGrouping") private var groupingRawValue = AccessoryListGrouping.connection.rawValue
    @AppStorage("LinkScope.sidebarSortOrder") private var sortOrderRawValue = AccessoryListSortOrder.nameAscending.rawValue
    @AppStorage("LinkScope.permissionOnboardingCompleted.v1") private var permissionOnboardingCompleted = false
    @State private var selection: InspectorSelection? = .providers
    @State private var searchText = ""
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDocument: SnapshotDocument?
    @State private var exportError: String?
    @State private var showingPermissions = false

    public init(model: LinkScopeApplicationModel) {
        self.model = model
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    private var grouping: AccessoryListGrouping {
        AccessoryListGrouping(rawValue: groupingRawValue) ?? .connection
    }

    private var sortOrder: AccessoryListSortOrder {
        AccessoryListSortOrder(rawValue: sortOrderRawValue) ?? .nameAscending
    }

    private var accessoryEntries: [AccessoryListEntry] {
        AccessoryListPresentation.entries(
            snapshot: model.snapshot,
            liveSessionStartedAt: model.liveSessionStartedAt,
            searchText: searchText,
            sortOrder: sortOrder
        )
    }

    private var accessorySections: [AccessoryListSection] {
        AccessoryListPresentation.sections(
            entries: accessoryEntries,
            grouping: grouping
        )
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label {
                        LText("dashboard.title")
                    } icon: {
                        Image(systemName: "rectangle.3.group")
                    }
                    .tag(InspectorSelection.dashboard)

                    Label {
                        LText("sidebar.providers")
                    } icon: {
                        Image(systemName: "wave.3.right.circle")
                    }
                    .tag(InspectorSelection.providers)

                    Label {
                        LText("sidebar.timeline")
                    } icon: {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }
                    .tag(InspectorSelection.timeline)

                    Label {
                        LText("diagnostics.title")
                    } icon: {
                        Image(systemName: "waveform.path.ecg")
                    }
                    .tag(InspectorSelection.diagnostics)
                } header: {
                    LText("sidebar.system")
                }

                if accessoryEntries.isEmpty {
                    Section {
                        ContentUnavailableView(
                            L10n.string("sidebar.noDevices", language: language),
                            systemImage: "dot.radiowaves.left.and.right"
                        )
                    } header: {
                        LText("sidebar.devices")
                    }
                } else {
                    ForEach(accessorySections) { section in
                        Section {
                            ForEach(section.entries) { entry in
                                AccessorySidebarRow(entry: entry)
                                    .tag(InspectorSelection.device(entry.id))
                            }
                        } header: {
                            Text(sectionTitle(section))
                        }
                    }
                }

            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: L10n.string("search.prompt", language: language))
            .safeAreaInset(edge: .bottom) {
                SidebarStatusBar(model: model)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
        }
        .environment(\.linkScopeLanguage, language)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    Picker(
                        L10n.string("sidebar.groupBy", language: language),
                        selection: $groupingRawValue
                    ) {
                        ForEach(AccessoryListGrouping.allCases) { value in
                            Text(L10n.string(
                                "sidebar.group.\(value.rawValue)",
                                language: language
                            ))
                            .tag(value.rawValue)
                        }
                    }
                    Picker(
                        L10n.string("sidebar.sortBy", language: language),
                        selection: $sortOrderRawValue
                    ) {
                        ForEach(AccessoryListSortOrder.allCases) { value in
                            Text(L10n.string(
                                "sidebar.sort.\(value.rawValue)",
                                language: language
                            ))
                            .tag(value.rawValue)
                        }
                    }
                } label: {
                    Label(
                        L10n.string("sidebar.listOptions", language: language),
                        systemImage: "arrow.up.arrow.down.circle"
                    )
                }
                .help(L10n.string("sidebar.listOptions.help", language: language))
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingPermissions = true
                } label: {
                    Label(
                        L10n.string("permissions.title", language: language),
                        systemImage: model.permissionsNeedAttention
                            ? "exclamationmark.shield.fill"
                            : "checkmark.shield"
                    )
                }
                .help(L10n.string("permissions.open.help", language: language))

                Button {
                    Task { await model.captureSnapshot() }
                } label: {
                    Label(L10n.string("toolbar.snapshot", language: language), systemImage: "camera")
                }
                .help(L10n.string("toolbar.snapshot.help", language: language))

                Button {
                    Task { await prepareExport() }
                } label: {
                    Label(L10n.string("toolbar.export", language: language), systemImage: "square.and.arrow.up")
                }
                .help(L10n.string("toolbar.export.help", language: language))

                Button {
                    importing = true
                } label: {
                    Label(L10n.string("toolbar.import", language: language), systemImage: "square.and.arrow.down")
                }
                .help(L10n.string("toolbar.import.help", language: language))
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "LinkScope-Snapshot.json"
        ) { result in
            if case let .failure(error) = result {
                exportError = error.localizedDescription
            }
            exportDocument = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case let .success(url):
                Task {
                    do {
                        let data = try await Task.detached {
                            let scoped = url.startAccessingSecurityScopedResource()
                            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                            return try Data(contentsOf: url)
                        }.value
                        try await model.importData(data)
                    } catch {
                        exportError = error.localizedDescription
                    }
                }
            case let .failure(error):
                exportError = error.localizedDescription
            }
        }
        .alert(
            L10n.string("export.failed", language: language),
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .sheet(isPresented: $showingPermissions) {
            PermissionManagementView(
                model: model,
                isOnboarding: !permissionOnboardingCompleted,
                showsCompletionButton: !permissionOnboardingCompleted
            ) {
                permissionOnboardingCompleted = true
                showingPermissions = false
            }
            .environment(\.linkScopeLanguage, language)
            .frame(width: 620)
            .interactiveDismissDisabled(!permissionOnboardingCompleted)
        }
        .task {
            await model.refreshPermissionStatuses()
            await Task.yield()
            if !permissionOnboardingCompleted {
                showingPermissions = true
            }
            await model.start()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.willSleepNotification
        )) { _ in
            Task { await model.systemWillSleep() }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.didWakeNotification
        )) { _ in
            Task { await model.systemDidWake() }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case let .device(id):
            if let accessory = model.snapshot.accessories.first(where: { $0.id == id }) {
                AccessoryDetailView(
                    accessory: accessory,
                    snapshot: model.snapshot,
                    liveSessionStartedAt: model.liveSessionStartedAt
                )
            } else {
                EmptyInspectorView()
            }
        case .dashboard:
            DashboardView(model: model)
        case .providers:
            ProviderStatusView(
                descriptors: model.providerDescriptors,
                statuses: model.snapshot.providerStatuses
            )
        case .timeline:
            TimelineListView(events: model.snapshot.timeline)
        case .diagnostics:
            DiagnosticsView(model: model)
        case nil:
            EmptyInspectorView()
        }
    }

    private func prepareExport() async {
        do {
            exportDocument = SnapshotDocument(data: try await model.exportData())
            exporting = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func sectionTitle(_ section: AccessoryListSection) -> String {
        let title: String
        switch section.id {
        case let .connection(state):
            title = L10n.string(
                "connectionState.\(state.rawValue)",
                language: language
            )
        case let .connectionProtocol(connectionProtocol):
            title = L10n.string(
                "connectionProtocol.\(connectionProtocol.rawValue)",
                language: language
            )
        case .all:
            title = L10n.string("sidebar.devices", language: language)
        }
        return "\(title) (\(section.entries.count))"
    }
}

private struct AccessorySidebarRow: View {
    @Environment(\.linkScopeLanguage) private var language
    let entry: AccessoryListEntry

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: protocolIcon)
                    .foregroundStyle(entry.summary.state == .inactive ? .secondary : .primary)
                if let statusIcon {
                    Image(systemName: statusIcon)
                        .font(.system(size: 8, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, statusColor)
                        .background(Circle().fill(statusColor).padding(-1))
                        .offset(x: 4, y: 4)
                }
            }
            .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.accessory.displayName)
                    .lineLimit(1)
                Text(L10n.formatted(
                    "sidebar.deviceSummary",
                    language: language,
                    L10n.string(
                        "connectionState.\(entry.summary.state.rawValue)",
                        language: language
                    ),
                    L10n.string(
                        "connectionProtocol.\(entry.summary.primaryProtocol.rawValue)",
                        language: language
                    )
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityHint(L10n.formatted(
            "sidebar.transportCount",
            language: language,
            entry.transports.count
        ))
    }

    private var protocolIcon: String {
        if let bluetoothDeviceIcon {
            return bluetoothDeviceIcon
        }
        return switch iconProtocol {
        case .bluetooth: "wave.3.right"
        case .usb: "cable.connector"
        case .builtIn: "laptopcomputer"
        case .network: "network"
        case .virtual: "square.stack.3d.up"
        case .gameController: "gamecontroller"
        case .system: "gearshape.2"
        case .unknown: "questionmark.circle"
        }
    }

    private var bluetoothDeviceIcon: String? {
        guard let classOfDevice = entry.bluetoothClassOfDevice,
              entry.summary.protocols.contains(.bluetooth) else {
            return nil
        }

        let majorDeviceClass = (classOfDevice >> 8) & 0x1F
        switch majorDeviceClass {
        case 1:
            return "laptopcomputer"
        case 2:
            return "iphone"
        case 3:
            return "network"
        case 4:
            return "headphones"
        case 5:
            let peripheralClass = (classOfDevice >> 6) & 0x03
            switch peripheralClass {
            case 1:
                return "keyboard"
            case 2:
                return "computermouse"
            case 3:
                return "keyboard.badge.ellipsis"
            default:
                return "gamecontroller"
            }
        case 6:
            return "camera"
        case 7:
            return "applewatch"
        case 8:
            return "teddybear"
        case 9:
            return "cross.case"
        default:
            return "questionmark.circle"
        }
    }

    private var iconProtocol: ConnectionProtocol {
        let deviceTypePriority: [ConnectionProtocol] = [
            .builtIn, .gameController, .usb, .network,
            .virtual, .system, .unknown, .bluetooth
        ]
        return deviceTypePriority.first(where: entry.summary.protocols.contains)
            ?? entry.summary.primaryProtocol
    }

    private var statusColor: Color {
        switch entry.summary.state {
        case .connected: .green
        case .saved: .orange
        case .disconnected: .secondary
        case .inactive: .gray
        }
    }

    private var statusIcon: String? {
        switch entry.summary.state {
        case .connected: "checkmark.circle.fill"
        case .saved: "bookmark.circle.fill"
        case .disconnected: "xmark.circle.fill"
        case .inactive: nil
        }
    }
}

private struct SidebarStatusBar: View {
    @Environment(\.linkScopeLanguage) private var language
    let model: LinkScopeApplicationModel

    var body: some View {
        HStack {
            Circle()
                .fill(model.runningProviderCount > 0 ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
            Text(L10n.formatted(
                "status.providersAndDevices",
                language: language,
                model.runningProviderCount,
                model.connectedAccessoryCount
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct EmptyInspectorView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                LText("detail.noSelection")
            } icon: {
                Image(systemName: "scope")
            }
        } description: {
            LText("detail.noSelection.description")
        }
    }
}
