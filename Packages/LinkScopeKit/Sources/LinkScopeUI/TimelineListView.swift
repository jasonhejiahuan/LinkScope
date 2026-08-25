import LinkScopeCore
import SwiftUI

struct TimelineListView: View {
    @Environment(\.linkScopeLanguage) private var language
    @SceneStorage("LinkScope.timeline.searchText") private var searchText = ""
    @SceneStorage("LinkScope.timeline.selectedKind") private var selectedKind: String?
    @SceneStorage("LinkScope.timeline.selectedProvider") private var selectedProvider: String?
    let events: [TimelineEvent]

    private var kindOptions: [String] {
        Array(Set(events.map { $0.kind.rawValue })).sorted {
            localizedKind($0).localizedStandardCompare(localizedKind($1)) == .orderedAscending
        }
    }

    private var providerOptions: [String] {
        Array(Set(events.compactMap { $0.providerID?.rawValue })).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedKind != nil || selectedProvider != nil
    }

    private var filteredEvents: [TimelineEvent] {
        events.filter { event in
            let matchesKind = selectedKind.map { event.kind.rawValue == $0 } ?? true
            let matchesProvider = selectedProvider.map { event.providerID?.rawValue == $0 } ?? true
            let matchesSearch = searchText.isEmpty
                || event.message.localizedStandardContains(searchText)
                || event.kind.rawValue.localizedStandardContains(searchText)
                || localizedKind(event.kind.rawValue).localizedStandardContains(searchText)
                || (event.providerID?.rawValue.localizedStandardContains(searchText) ?? false)
            return matchesKind && matchesProvider && matchesSearch
        }
    }

    var body: some View {
        Group {
            if events.isEmpty {
                ContentUnavailableView {
                    Label {
                        LText("timeline.empty")
                    } icon: {
                        Image(systemName: "clock")
                    }
                } description: {
                    LText("timeline.empty.description")
                }
            } else {
                VStack(spacing: 0) {
                    filterBar
                    Divider()

                    if filteredEvents.isEmpty {
                        ContentUnavailableView {
                            Label(
                                L10n.string("timeline.filtered.empty", language: language),
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                        } description: {
                            Text(L10n.string("timeline.filtered.empty.description", language: language))
                        } actions: {
                            Button(L10n.string("diagnostics.clearFilters", language: language)) {
                                clearFilters()
                            }
                        }
                    } else {
                        List(filteredEvents) { event in
                            TimelineEventRow(event: event)
                        }
                        .listStyle(.inset)
                    }
                }
            }
        }
        .environment(\.locale, Locale(identifier: language.rawValue))
        .navigationTitle(L10n.string("sidebar.timeline", language: language))
    }

    private var filterBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchField
                kindPicker
                providerPicker
                Spacer(minLength: 8)
                clearFiltersButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    searchField
                    Spacer(minLength: 8)
                    clearFiltersButton
                }
                HStack(spacing: 10) {
                    kindPicker
                    providerPicker
                    Spacer(minLength: 0)
                }
            }
        }
        .controlSize(.small)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(
                L10n.string("timeline.search", language: language),
                text: $searchText
            )
            .textFieldStyle(.roundedBorder)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    L10n.string("timeline.search.clear", language: language)
                )
                .help(L10n.string("timeline.search.clear", language: language))
            }
        }
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
    }

    private var kindPicker: some View {
        Picker(
            L10n.string("timeline.filter.kind", language: language),
            selection: $selectedKind
        ) {
            Text(L10n.string("timeline.filter.allKinds", language: language))
                .tag(nil as String?)
            ForEach(kindOptions, id: \.self) { rawValue in
                Text(localizedKind(rawValue)).tag(rawValue as String?)
            }
        }
        .frame(minWidth: 145, idealWidth: 170, maxWidth: 190)
    }

    private var providerPicker: some View {
        Picker(
            L10n.string("timeline.filter.provider", language: language),
            selection: $selectedProvider
        ) {
            Text(L10n.string("timeline.filter.allProviders", language: language))
                .tag(nil as String?)
            ForEach(providerOptions, id: \.self) { providerID in
                Text(providerID).tag(providerID as String?)
            }
        }
        .frame(minWidth: 170, idealWidth: 200, maxWidth: 230)
        .disabled(providerOptions.isEmpty)
    }

    private var clearFiltersButton: some View {
        Button(L10n.string("diagnostics.clearFilters", language: language)) {
            clearFilters()
        }
        .disabled(!hasActiveFilters)
    }

    private func localizedKind(_ rawValue: String) -> String {
        L10n.string("timeline.kind.\(rawValue)", language: language)
    }

    private func clearFilters() {
        searchText = ""
        selectedKind = nil
        selectedProvider = nil
    }
}

private struct TimelineEventRow: View {
    @Environment(\.linkScopeLanguage) private var language
    let event: TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.message)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    Text(localizedKind)
                    if let provider = event.providerID {
                        Text("·")
                            .accessibilityHidden(true)
                        Text(provider.rawValue)
                            .font(.caption.monospaced())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(event.timestamp, format: .dateTime.month().day().hour().minute().second())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var localizedKind: String {
        L10n.string("timeline.kind.\(event.kind.rawValue)", language: language)
    }

    private var icon: String {
        switch event.kind {
        case .providerStarted, .deviceConnected: "link.badge.plus"
        case .providerStopped, .deviceDisconnected: "link.badge.minus"
        case .systemSleep: "moon.zzz"
        case .systemWake: "sun.max"
        case .thermalChanged: "thermometer.medium"
        case .snapshotCaptured: "camera"
        case .diagnostic: "waveform.path.ecg"
        case .error: "exclamationmark.triangle"
        }
    }

    private var color: Color {
        switch event.kind {
        case .deviceConnected, .providerStarted, .systemWake: .green
        case .error: .red
        case .thermalChanged: .orange
        default: .secondary
        }
    }
}
