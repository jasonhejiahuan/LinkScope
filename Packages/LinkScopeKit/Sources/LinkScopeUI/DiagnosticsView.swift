import Accessibility
import Charts
import LinkScopeCore
import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    let model: LinkScopeApplicationModel
    @State private var selection: UUID?
    @State private var comparisonRunID: UUID?
    @State private var runSearchText = ""
    @State private var runStateFilter: DiagnosticRunState?
    @State private var presentingNewSession = false
    @State private var presentingRules = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer()

                Menu {
                    Picker(L10n.string("diagnostics.compareWith"), selection: $comparisonRunID) {
                        Text(L10n.string("diagnostics.compare.none"))
                            .tag(nil as UUID?)
                        ForEach(comparisonCandidates) { run in
                            Text(run.name).tag(run.id as UUID?)
                        }
                    }
                } label: {
                    Label(L10n.string("diagnostics.compare"), systemImage: "square.split.2x1")
                }
                .disabled(selection == nil || comparisonCandidates.isEmpty)
                .help(L10n.string("diagnostics.compare.help"))

                Button {
                    presentingRules = true
                } label: {
                    Label(L10n.string("rules.title"), systemImage: "bell.badge")
                }

                Button {
                    presentingNewSession = true
                } label: {
                    Label(L10n.string("diagnostics.new"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            HSplitView {
                DiagnosticRunListPanel(
                    selection: $selection,
                    searchText: $runSearchText,
                    stateFilter: $runStateFilter,
                    activeRun: visibleActiveRun,
                    historyRuns: visibleHistoryRuns
                )
                .frame(minWidth: 230, idealWidth: 280, maxWidth: 360)

                Group {
                    if let selectedRun {
                        DiagnosticDetailView(
                            model: model,
                            run: selectedRun,
                            comparisonRun: comparisonRun
                        )
                        .id(selectedRun.id)
                    } else {
                        DiagnosticEmptyDetail(
                            hasRuns: !model.diagnosticRuns.isEmpty,
                            hasFilters: !runSearchText.isEmpty || runStateFilter != nil,
                            clearFilters: clearRunFilters,
                            createDiagnostic: { presentingNewSession = true }
                        )
                    }
                }
                .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(L10n.string("diagnostics.title"))
        .sheet(isPresented: $presentingNewSession) {
            NewDiagnosticView(model: model) { runID in
                runSearchText = ""
                runStateFilter = nil
                selection = runID
                comparisonRunID = nil
                presentingNewSession = false
            }
        }
        .sheet(isPresented: $presentingRules) {
            RuleManagementView(model: model)
        }
        .task {
            ensureSelection(preferActive: true)
        }
        .onChange(of: model.activeDiagnostic?.id) { _, _ in
            ensureSelection(preferActive: true)
        }
        .onChange(of: filteredRuns.map(\.id)) { _, _ in
            ensureSelection()
        }
        .onChange(of: selection) { _, newSelection in
            if comparisonRunID == newSelection {
                comparisonRunID = nil
            }
        }
        .onChange(of: comparisonCandidates.map(\.id)) { _, candidates in
            if let comparisonRunID, !candidates.contains(comparisonRunID) {
                self.comparisonRunID = nil
            }
        }
    }

    private var filteredRuns: [DiagnosticRun] {
        DiagnosticsPresentation.runs(
            model.diagnosticRuns,
            searchText: runSearchText,
            state: runStateFilter
        )
    }

    private var visibleActiveRun: DiagnosticRun? {
        guard let activeID = model.activeDiagnostic?.id else { return nil }
        return filteredRuns.first { $0.id == activeID }
    }

    private var visibleHistoryRuns: [DiagnosticRun] {
        filteredRuns.filter { $0.id != model.activeDiagnostic?.id }
    }

    private var selectedRun: DiagnosticRun? {
        guard let selection else { return nil }
        return model.diagnosticRuns.first { $0.id == selection }
    }

    private var comparisonRun: DiagnosticRun? {
        guard let comparisonRunID else { return nil }
        return model.diagnosticRuns.first { $0.id == comparisonRunID }
    }

    private var comparisonCandidates: [DiagnosticRun] {
        model.diagnosticRuns
            .filter { $0.id != selection }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func ensureSelection(preferActive: Bool = false) {
        if preferActive,
           let activeID = model.activeDiagnostic?.id,
           filteredRuns.contains(where: { $0.id == activeID }) {
            selection = activeID
            return
        }
        if let selection, filteredRuns.contains(where: { $0.id == selection }) {
            return
        }
        selection = visibleActiveRun?.id ?? filteredRuns.first?.id
    }

    private func clearRunFilters() {
        runSearchText = ""
        runStateFilter = nil
        ensureSelection(preferActive: true)
    }
}

private struct DiagnosticRunListPanel: View {
    @Binding var selection: UUID?
    @Binding var searchText: String
    @Binding var stateFilter: DiagnosticRunState?
    let activeRun: DiagnosticRun?
    let historyRuns: [DiagnosticRun]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(L10n.string("diagnostics.searchRuns"), text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(L10n.string("diagnostics.clearFilters"))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
            .padding(9)

            HStack(spacing: 8) {
                Label(L10n.string("diagnostics.statusFilter"), systemImage: "line.3.horizontal.decrease")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Picker(L10n.string("diagnostics.statusFilter"), selection: $stateFilter) {
                    Text(L10n.string("diagnostics.status.all"))
                        .tag(nil as DiagnosticRunState?)
                    ForEach(DiagnosticRunState.allCases, id: \.self) { state in
                        Text(localizedRunState(state)).tag(state as DiagnosticRunState?)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            List(selection: $selection) {
                if let activeRun {
                    Section {
                        DiagnosticRunRow(run: activeRun)
                            .tag(activeRun.id)
                    } header: {
                        LText("diagnostics.active")
                    }
                }

                if !historyRuns.isEmpty {
                    Section {
                        ForEach(historyRuns) { run in
                            DiagnosticRunRow(run: run)
                                .tag(run.id)
                        }
                    } header: {
                        LText("diagnostics.history")
                    }
                }

                if activeRun == nil, historyRuns.isEmpty {
                    ContentUnavailableView(
                        L10n.string("diagnostics.noMatchingRuns"),
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(L10n.string("diagnostics.noMatchingRuns.description"))
                    )
                }
            }
        }
    }
}

private struct DiagnosticEmptyDetail: View {
    let hasRuns: Bool
    let hasFilters: Bool
    let clearFilters: () -> Void
    let createDiagnostic: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                L10n.string(hasRuns ? "diagnostics.noSelection" : "diagnostics.empty"),
                systemImage: "waveform.path.ecg"
            )
        } description: {
            Text(L10n.string(hasRuns ? "diagnostics.noSelection.description" : "diagnostics.empty.description"))
        } actions: {
            HStack {
                if hasFilters {
                    Button(L10n.string("diagnostics.clearFilters"), action: clearFilters)
                }
                Button(L10n.string("diagnostics.new"), action: createDiagnostic)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct DiagnosticRunRow: View {
    let run: DiagnosticRun

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: diagnosticStateIcon(run.state))
                .foregroundStyle(diagnosticStateColor(run.state))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(run.name)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(localizedRunState(run.state))
                    Text("·")
                    Text(run.createdAt, format: .dateTime.month().day().hour().minute())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: L10n.string("diagnostics.run.accessibilityLabel"),
                run.name,
                localizedRunState(run.state),
                run.createdAt.formatted(date: .abbreviated, time: .shortened)
            )
        )
    }
}

private struct NewDiagnosticView: View {
    let model: LinkScopeApplicationModel
    let didStart: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var purpose = ""
    @State private var selectedSources: Set<WidgetSourceID> = []
    @State private var interval = 5.0
    @State private var duration = 300.0
    @State private var hasDuration = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField(L10n.string("diagnostics.name"), text: $name)
                    TextField(L10n.string("diagnostics.purpose"), text: $purpose, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    if model.diagnosticSources.isEmpty {
                        ContentUnavailableView(
                            L10n.string("diagnostics.noSources"),
                            systemImage: "sensor.tag.radiowaves.forward",
                            description: Text(L10n.string("diagnostics.noSources.description"))
                        )
                    } else {
                        ForEach(model.diagnosticSources) { source in
                            Toggle(isOn: sourceBinding(source.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.displayName)
                                    Text(source.providerID.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    LText("diagnostics.sources")
                }

                Section {
                    Picker(L10n.string("diagnostics.interval"), selection: $interval) {
                        Text(formattedShortDuration(2)).tag(2.0)
                        Text(formattedShortDuration(5)).tag(5.0)
                        Text(formattedShortDuration(10)).tag(10.0)
                        Text(formattedShortDuration(30)).tag(30.0)
                    }
                    Toggle(L10n.string("diagnostics.limitDuration"), isOn: $hasDuration)
                    if hasDuration {
                        Picker(L10n.string("diagnostics.duration"), selection: $duration) {
                            Text(formattedShortDuration(60)).tag(60.0)
                            Text(formattedShortDuration(300)).tag(300.0)
                            Text(formattedShortDuration(900)).tag(900.0)
                            Text(formattedShortDuration(3600)).tag(3600.0)
                        }
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel(
                            String(format: L10n.string("diagnostics.error.accessibilityLabel"), errorMessage)
                        )
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button(L10n.string("common.cancel")) { dismiss() }
                Spacer()
                Button(L10n.string("diagnostics.start")) {
                    Task { await start() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedSources.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 620)
    }

    private func sourceBinding(_ sourceID: WidgetSourceID) -> Binding<Bool> {
        Binding(
            get: { selectedSources.contains(sourceID) },
            set: { selected in
                if selected {
                    selectedSources.insert(sourceID)
                } else {
                    selectedSources.remove(sourceID)
                }
            }
        )
    }

    private func start() async {
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            try await model.startDiagnostic(
                name: trimmedName.isEmpty
                    ? String(
                        format: L10n.string("diagnostics.defaultName"),
                        Date.now.formatted(date: .abbreviated, time: .shortened)
                    )
                    : trimmedName,
                purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceIDs: selectedSources,
                duration: hasDuration ? duration : nil,
                samplingPolicy: .fixedInterval(seconds: interval)
            )
            if let id = model.activeDiagnostic?.id {
                didStart(id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DiagnosticDetailView: View {
    let model: LinkScopeApplicationModel
    let run: DiagnosticRun
    let comparisonRun: DiagnosticRun?
    @State private var observations: [ResolvedObservation] = []
    @State private var comparisonObservations: [ResolvedObservation] = []
    @State private var selectedSourceID: DiagnosticObservationSource.ID?
    @State private var selectedParameter: ParameterPath?
    @State private var availabilityFilter: AvailabilityCode?
    @State private var loadError: String?
    @State private var exporting = false
    @State private var exportDocument: DiagnosticCSVDocument?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DiagnosticHeader(model: model, run: run)

                HStack {
                    Spacer()
                    Button {
                        exportDocument = DiagnosticCSVDocument(observations: filteredObservations)
                        exporting = true
                    } label: {
                        Label(
                            L10n.string("diagnostics.exportCSV"),
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .disabled(filteredObservations.isEmpty)
                    .help(L10n.string("diagnostics.exportCSV.help"))
                }

                if let comparisonRun {
                    Label(
                        String(format: L10n.string("diagnostics.compare.restriction"), comparisonRun.name),
                        systemImage: "equal.circle"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                }

                if availableSeries.isEmpty {
                    ContentUnavailableView(
                        L10n.string(comparisonRun == nil
                            ? "diagnostics.noObservations"
                            : "diagnostics.compare.noCommonSeries"),
                        systemImage: comparisonRun == nil ? "waveform.slash" : "square.split.2x1",
                        description: Text(
                            L10n.string(comparisonRun == nil
                                ? "diagnostics.noObservations.description"
                                : "diagnostics.compare.noCommonSeries.description")
                        )
                    )
                } else {
                    DiagnosticFilterBar(
                        sources: availableSources,
                        parameters: availableParameters,
                        selectedSourceID: $selectedSourceID,
                        selectedParameter: $selectedParameter,
                        availabilityFilter: $availabilityFilter
                    )

                    if filteredObservations.isEmpty {
                        ContentUnavailableView {
                            Label(
                                L10n.string("diagnostics.filters.empty"),
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                        } description: {
                            Text(L10n.string("diagnostics.filters.empty.description"))
                        } actions: {
                            Button(L10n.string("diagnostics.filters.reset")) {
                                availabilityFilter = nil
                            }
                        }
                    } else {
                        DiagnosticMetrics(statistics: statistics)

                        if let comparisonRun {
                            DiagnosticComparisonSummary(
                                primaryRun: run,
                                comparisonRun: comparisonRun,
                                primaryStatistics: statistics,
                                comparisonStatistics: comparisonStatistics,
                                parameter: selectedParameter
                            )
                        }

                        DiagnosticChart(
                            primaryObservations: filteredObservations,
                            comparisonObservations: comparisonRun == nil ? [] : filteredComparisonObservations,
                            primaryName: run.name,
                            comparisonName: comparisonRun?.name,
                            parameter: selectedParameter
                        )

                        DiagnosticObservationTable(observations: filteredObservations)
                    }
                }

                if let loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle(run.name)
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "\(run.name)-Diagnostics.csv"
        ) { result in
            if case let .failure(error) = result {
                loadError = error.localizedDescription
            }
            exportDocument = nil
        }
        .task(id: loadID) {
            await loadObservations()
        }
        .onChange(of: availableSeries.map(\.id)) { _, _ in
            ensureFilterSelection()
        }
        .onChange(of: selectedSourceID) { _, _ in
            ensureParameterSelection(preferFirst: true)
        }
    }

    private var loadID: DiagnosticLoadID {
        DiagnosticLoadID(
            primaryID: run.id,
            primarySampleCount: run.sampleCount,
            comparisonID: comparisonRun?.id,
            comparisonSampleCount: comparisonRun?.sampleCount
        )
    }

    private var availableSeries: [DiagnosticObservationSeries] {
        guard comparisonRun != nil else {
            return DiagnosticsPresentation.series(in: observations)
        }
        return DiagnosticsPresentation.commonNumericSeries(
            lhs: observations,
            rhs: comparisonObservations
        )
    }

    private var availableSources: [DiagnosticObservationSource] {
        availableSeries.reduce(into: [DiagnosticObservationSource.ID: DiagnosticObservationSource]()) {
            $0[$1.source.id] = $1.source
        }
        .values
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private var availableParameters: [ParameterPath] {
        guard let selectedSourceID else { return [] }
        return availableSeries
            .filter { $0.source.id == selectedSourceID }
            .map(\.parameterPath)
            .sorted { $0.rawValue.localizedStandardCompare($1.rawValue) == .orderedAscending }
    }

    private var selectedSeriesID: DiagnosticObservationSeries.ID? {
        guard let selectedSourceID, let selectedParameter else { return nil }
        return DiagnosticObservationSeries.ID(
            sourceID: selectedSourceID,
            parameterPath: selectedParameter
        )
    }

    private var filteredObservations: [ResolvedObservation] {
        guard let selectedSeriesID else { return [] }
        return filterAvailability(
            DiagnosticsPresentation.observations(in: observations, seriesID: selectedSeriesID)
        )
    }

    private var filteredComparisonObservations: [ResolvedObservation] {
        guard let selectedSeriesID else { return [] }
        return filterAvailability(
            DiagnosticsPresentation.observations(
                in: comparisonObservations,
                seriesID: selectedSeriesID
            )
        )
    }

    private var statistics: DiagnosticSeriesStatistics {
        DiagnosticsPresentation.statistics(for: filteredObservations)
    }

    private var comparisonStatistics: DiagnosticSeriesStatistics {
        DiagnosticsPresentation.statistics(for: filteredComparisonObservations)
    }

    private func filterAvailability(_ values: [ResolvedObservation]) -> [ResolvedObservation] {
        guard let availabilityFilter else { return values }
        return values.filter { $0.observation.availability.code == availabilityFilter }
    }

    private func loadObservations() async {
        do {
            let loaded = try await model.observations(for: run)
            let loadedComparison: [ResolvedObservation]
            if let comparisonRun {
                loadedComparison = try await model.observations(for: comparisonRun)
            } else {
                loadedComparison = []
            }
            guard !Task.isCancelled else { return }
            observations = loaded
            comparisonObservations = loadedComparison
            loadError = nil
            ensureFilterSelection()
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error.localizedDescription
        }
    }

    private func ensureFilterSelection() {
        if let selectedSourceID,
           availableSources.contains(where: { $0.id == selectedSourceID }) {
            ensureParameterSelection()
            return
        }
        selectedSourceID = availableSources.first?.id
        selectedParameter = availableParameters.first
    }

    private func ensureParameterSelection(preferFirst: Bool = false) {
        if !preferFirst,
           let selectedParameter,
           availableParameters.contains(selectedParameter) {
            return
        }
        selectedParameter = availableParameters.first
    }
}

private struct DiagnosticLoadID: Hashable {
    let primaryID: UUID
    let primarySampleCount: Int
    let comparisonID: UUID?
    let comparisonSampleCount: Int?
}

private struct DiagnosticFilterBar: View {
    let sources: [DiagnosticObservationSource]
    let parameters: [ParameterPath]
    @Binding var selectedSourceID: DiagnosticObservationSource.ID?
    @Binding var selectedParameter: ParameterPath?
    @Binding var availabilityFilter: AvailabilityCode?

    var body: some View {
        GroupBox {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { filters }
                VStack(alignment: .leading, spacing: 10) { filters }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(L10n.string("diagnostics.filters"), systemImage: "line.3.horizontal.decrease")
        }
    }

    @ViewBuilder
    private var filters: some View {
        Picker(L10n.string("diagnostics.source"), selection: $selectedSourceID) {
            ForEach(sources) { source in
                Text("\(source.displayName) · \(source.providerID.rawValue)")
                    .tag(source.id as DiagnosticObservationSource.ID?)
            }
        }
        .frame(minWidth: 190)

        Picker(L10n.string("diagnostics.parameter"), selection: $selectedParameter) {
            ForEach(parameters, id: \.self) { parameter in
                Text(parameter.rawValue).tag(parameter as ParameterPath?)
            }
        }
        .frame(minWidth: 170)

        Picker(L10n.string("diagnostics.availability"), selection: $availabilityFilter) {
            Text(L10n.string("diagnostics.availability.all"))
                .tag(nil as AvailabilityCode?)
            ForEach(AvailabilityCode.allCases, id: \.self) { code in
                Text(localizedAvailability(code)).tag(code as AvailabilityCode?)
            }
        }
        .frame(minWidth: 150)
    }
}

private struct DiagnosticCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let data: Data

    init(observations: [ResolvedObservation]) {
        var rows = ["timestamp,device,provider,parameter,availability,value"]
        rows += observations.reversed().map {
            [
                $0.observation.timestamp.formatted(.iso8601),
                $0.identity.physicalAccessory.displayName,
                $0.observation.transportIdentity.providerID.rawValue,
                $0.observation.parameterPath.rawValue,
                $0.observation.availability.code.rawValue,
                $0.observation.value?.compactDescription ?? ""
            ].map(Self.escape).joined(separator: ",")
        }
        data = Data(rows.joined(separator: "\n").utf8)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    private static func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private struct DiagnosticHeader: View {
    let model: LinkScopeApplicationModel
    let run: DiagnosticRun

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(run.name)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)
                Spacer()
                Label(localizedRunState(run.state), systemImage: diagnosticStateIcon(run.state))
                    .foregroundStyle(diagnosticStateColor(run.state))
                    .accessibilityLabel(
                        String(
                            format: L10n.string("diagnostics.status.accessibilityLabel"),
                            localizedRunState(run.state)
                        )
                    )
            }

            Text(run.purpose.isEmpty ? L10n.string("diagnostics.noPurpose") : run.purpose)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 16) {
                Label {
                    Text(run.startedAt ?? run.createdAt, format: .dateTime)
                } icon: {
                    Image(systemName: "play.circle")
                }
                .accessibilityLabel(
                    String(
                        format: L10n.string("diagnostics.started.accessibilityLabel"),
                        (run.startedAt ?? run.createdAt).formatted(date: .abbreviated, time: .standard)
                    )
                )

                if let endedAt = run.endedAt {
                    Label {
                        Text(endedAt, format: .dateTime)
                    } icon: {
                        Image(systemName: "stop.circle")
                    }
                    .accessibilityLabel(
                        String(
                            format: L10n.string("diagnostics.ended.accessibilityLabel"),
                            endedAt.formatted(date: .abbreviated, time: .standard)
                        )
                    )
                }

                Label(
                    String(format: L10n.string("diagnostics.gapCount"), run.gapCount),
                    systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                )
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            if let errorMessage = run.errorMessage, !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            if run.state == .running || run.state == .stopping {
                Button(role: .destructive) {
                    Task { await model.stopDiagnostic() }
                } label: {
                    Label(L10n.string("diagnostics.stop"), systemImage: "stop.fill")
                }
                .disabled(run.state == .stopping)
            }
        }
    }
}

private struct DiagnosticMetrics: View {
    let statistics: DiagnosticSeriesStatistics

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
            MetricCard(
                title: L10n.string("diagnostics.filteredSamples"),
                value: "\(statistics.rowCount)"
            )
            MetricCard(
                title: L10n.string("diagnostics.unavailable"),
                value: "\(statistics.unavailableCount)"
            )
            MetricCard(title: L10n.string("diagnostics.minimum"), value: formattedNumber(statistics.minimum))
            MetricCard(title: L10n.string("diagnostics.maximum"), value: formattedNumber(statistics.maximum))
            MetricCard(title: L10n.string("diagnostics.average"), value: formattedNumber(statistics.average))
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

private struct DiagnosticComparisonSummary: View {
    let primaryRun: DiagnosticRun
    let comparisonRun: DiagnosticRun
    let primaryStatistics: DiagnosticSeriesStatistics
    let comparisonStatistics: DiagnosticSeriesStatistics
    let parameter: ParameterPath?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if let parameter {
                    Text(parameter.rawValue)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    MetricCard(
                        title: String(
                            format: L10n.string("diagnostics.compare.runAverage"),
                            primaryRun.name
                        ),
                        value: formattedNumber(primaryStatistics.average)
                    )
                    MetricCard(
                        title: String(
                            format: L10n.string("diagnostics.compare.runAverage"),
                            comparisonRun.name
                        ),
                        value: formattedNumber(comparisonStatistics.average)
                    )
                    MetricCard(
                        title: L10n.string("diagnostics.compare.delta"),
                        value: formattedDelta(delta)
                    )
                }

                Text(
                    String(
                        format: L10n.string("diagnostics.compare.deltaDescription"),
                        comparisonRun.name,
                        primaryRun.name
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } label: {
            Label(L10n.string("diagnostics.compare.summary"), systemImage: "arrow.left.arrow.right")
        }
    }

    private var delta: Double? {
        guard let primary = primaryStatistics.average,
              let comparison = comparisonStatistics.average else { return nil }
        return comparison - primary
    }
}

private struct DiagnosticChart: View {
    let primaryObservations: [ResolvedObservation]
    let comparisonObservations: [ResolvedObservation]
    let primaryName: String
    let comparisonName: String?
    let parameter: ParameterPath?

    var body: some View {
        GroupBox {
            if points.isEmpty {
                ContentUnavailableView(
                    L10n.string("diagnostics.chart.noNumeric"),
                    systemImage: "chart.xyaxis.line",
                    description: Text(L10n.string("diagnostics.chart.noNumeric.description"))
                )
                .frame(minHeight: 180)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value(L10n.string("diagnostics.time"), point.date),
                        y: .value(L10n.string("diagnostics.value"), point.value)
                    )
                    .foregroundStyle(by: .value(L10n.string("diagnostics.run"), point.series))
                    .symbol(by: .value(L10n.string("diagnostics.run"), point.series))
                    .interpolationMethod(.linear)

                    PointMark(
                        x: .value(L10n.string("diagnostics.time"), point.date),
                        y: .value(L10n.string("diagnostics.value"), point.value)
                    )
                    .foregroundStyle(by: .value(L10n.string("diagnostics.run"), point.series))
                    .symbol(by: .value(L10n.string("diagnostics.run"), point.series))
                }
                .frame(minHeight: 260)
                .chartXAxisLabel(L10n.string("diagnostics.time"))
                .chartYAxisLabel(parameter?.rawValue ?? L10n.string("diagnostics.value"))
                .chartLegend(position: .bottom)
                .accessibilityChartDescriptor(
                    DiagnosticChartAccessibilityDescriptor(
                        title: parameter?.rawValue ?? L10n.string("diagnostics.chart"),
                        points: points
                    )
                )
            }
        } label: {
            Label(L10n.string("diagnostics.chart"), systemImage: "chart.xyaxis.line")
        }
    }

    private var points: [DiagnosticPoint] {
        makePoints(primaryObservations, series: primaryName)
            + makePoints(comparisonObservations, series: comparisonName ?? "")
    }

    private func makePoints(_ observations: [ResolvedObservation], series: String) -> [DiagnosticPoint] {
        observations.compactMap { resolved in
            DiagnosticsPresentation.numericValue(resolved.observation.value).map {
                DiagnosticPoint(
                    id: "\(series)-\(resolved.id.uuidString)",
                    date: resolved.observation.timestamp,
                    value: $0,
                    series: series
                )
            }
        }
        .sorted { $0.date < $1.date }
    }
}

private struct DiagnosticPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    let series: String
}

private struct DiagnosticChartAccessibilityDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let points: [DiagnosticPoint]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xValues = points.map { $0.date.timeIntervalSince1970 }
        let yValues = points.map(\.value)
        let xRange = expandedRange(minimum: xValues.min() ?? 0, maximum: xValues.max() ?? 1)
        let yRange = expandedRange(minimum: yValues.min() ?? 0, maximum: yValues.max() ?? 1)

        let xAxis = AXNumericDataAxisDescriptor(
            title: L10n.string("diagnostics.time"),
            range: xRange,
            gridlinePositions: [],
            valueDescriptionProvider: {
                Date(timeIntervalSince1970: $0).formatted(date: .abbreviated, time: .standard)
            }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: title,
            range: yRange,
            gridlinePositions: [],
            valueDescriptionProvider: { formattedNumber($0) }
        )
        let series = Dictionary(grouping: points, by: \.series)
            .map { name, values in
                AXDataSeriesDescriptor(
                    name: name,
                    isContinuous: true,
                    dataPoints: values.sorted { $0.date < $1.date }.map {
                        AXDataPoint(
                            x: $0.date.timeIntervalSince1970,
                            y: $0.value,
                            label: $0.date.formatted(date: .abbreviated, time: .standard)
                        )
                    }
                )
            }

        return AXChartDescriptor(
            title: title,
            summary: String(
                format: L10n.string("diagnostics.chart.accessibilitySummary"),
                points.count,
                series.count
            ),
            xAxis: xAxis,
            yAxis: yAxis,
            series: series
        )
    }

    private func expandedRange(minimum: Double, maximum: Double) -> ClosedRange<Double> {
        guard minimum == maximum else { return minimum...maximum }
        let padding = max(abs(minimum) * 0.05, 1)
        return (minimum - padding)...(maximum + padding)
    }
}

private struct DiagnosticObservationTable: View {
    let observations: [ResolvedObservation]

    var body: some View {
        GroupBox {
            Table(observations) {
                TableColumn(L10n.string("diagnostics.time")) {
                    Text($0.observation.timestamp, format: .dateTime.hour().minute().second())
                }
                TableColumn(L10n.string("diagnostics.source")) {
                    Text($0.identity.physicalAccessory.displayName)
                        .lineLimit(1)
                }
                TableColumn(L10n.string("diagnostics.parameter")) {
                    Text($0.observation.parameterPath.rawValue)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                }
                TableColumn(L10n.string("diagnostics.availability")) {
                    Text(localizedAvailability($0.observation.availability.code))
                        .lineLimit(1)
                }
                TableColumn(L10n.string("diagnostics.value")) {
                    Text(
                        $0.observation.value?.compactDescription
                            ?? localizedAvailability($0.observation.availability.code)
                    )
                    .font(.body.monospacedDigit())
                    .lineLimit(1)
                }
            }
            .frame(minHeight: 260)
        } label: {
            Label(L10n.string("diagnostics.observations"), systemImage: "tablecells")
        }
    }
}

private struct RuleManagementView: View {
    let model: LinkScopeApplicationModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sourceID: WidgetSourceID?
    @State private var threshold = 20.0
    @State private var comparison = RuleComparison.below
    @State private var availabilityCode = AvailabilityCode.permissionDenied
    @State private var repeatInterval = 900.0
    @State private var pendingDeletion: RuleDefinition?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    if model.rules.isEmpty {
                        ContentUnavailableView(
                            L10n.string("rules.empty"),
                            systemImage: "bell.slash",
                            description: Text(L10n.string("rules.empty.description"))
                        )
                    } else {
                        ForEach(model.rules) { rule in
                            RuleRow(
                                rule: rule,
                                sourceName: sourceName(for: rule.sourceID),
                                condition: conditionSummary(rule.predicate),
                                repeatDescription: String(
                                    format: L10n.string("rules.minimumRepeat"),
                                    repeatDescription(rule.minimumRepeatInterval)
                                ),
                                isEnabled: Binding(
                                    get: { rule.isEnabled },
                                    set: { enabled in
                                        var changed = rule
                                        changed.isEnabled = enabled
                                        Task { await model.saveRule(changed) }
                                    }
                                ),
                                delete: { pendingDeletion = rule }
                            )
                        }
                    }
                } header: {
                    LText("rules.existing")
                }

                Section {
                    TextField(L10n.string("rules.name"), text: $name)

                    Picker(L10n.string("rules.source"), selection: $sourceID) {
                        Text(L10n.string("rules.selectSource"))
                            .tag(nil as WidgetSourceID?)
                        ForEach(ruleSources) { source in
                            Text(source.name).tag(source.id as WidgetSourceID?)
                        }
                    }

                    Picker(L10n.string("rules.condition"), selection: $comparison) {
                        ForEach(allowedComparisons) { comparison in
                            Text(comparison.label).tag(comparison)
                        }
                    }

                    if selectedSource?.kind == .providerHealth {
                        Text(L10n.string("rules.providerHealth.conditions"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    switch comparison {
                    case .below, .above:
                        TextField(
                            L10n.string("rules.threshold"),
                            value: $threshold,
                            format: .number
                        )
                    case .availability:
                        Picker(L10n.string("rules.availabilityCode"), selection: $availabilityCode) {
                            ForEach(AvailabilityCode.allCases, id: \.self) { code in
                                Text(localizedAvailability(code)).tag(code)
                            }
                        }
                    case .changed:
                        EmptyView()
                    }

                    Picker(L10n.string("rules.repeatInterval"), selection: $repeatInterval) {
                        ForEach(RuleRepeatInterval.allCases) { option in
                            Text(option.label).tag(option.seconds)
                        }
                    }

                    Button(L10n.string("rules.add")) {
                        addRule()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sourceID == nil)
                } header: {
                    LText("rules.new")
                } footer: {
                    Text(L10n.string("rules.repeatInterval.description"))
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(L10n.string("common.done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 620, minHeight: 680)
        .task {
            if sourceID == nil {
                sourceID = ruleSources.first?.id
            }
            normalizeComparisonForSource()
        }
        .onChange(of: sourceID) { _, _ in
            normalizeComparisonForSource()
        }
        .alert(
            L10n.string("rules.delete.title"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { presented in
                    if !presented { pendingDeletion = nil }
                }
            )
        ) {
            Button(L10n.string("common.cancel"), role: .cancel) {}
            Button(L10n.string("rules.delete"), role: .destructive) {
                guard let pendingDeletion else { return }
                Task { await model.deleteRule(id: pendingDeletion.id) }
                self.pendingDeletion = nil
            }
        } message: {
            Text(
                String(
                    format: L10n.string("rules.delete.message"),
                    pendingDeletion?.name ?? ""
                )
            )
        }
    }

    private var ruleSources: [RuleSourceOption] {
        let observations = model.monitoringSources.map {
            RuleSourceOption(id: $0.id, name: $0.displayName, kind: .observation)
        }
        let providers = model.providerDescriptors.map {
            RuleSourceOption(
                id: WidgetSourceID(rawValue: "provider:\($0.id.rawValue)"),
                name: String(format: L10n.string("rules.providerHealth"), $0.displayName),
                kind: .providerHealth
            )
        }
        return (observations + providers).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var selectedSource: RuleSourceOption? {
        guard let sourceID else { return nil }
        return ruleSources.first { $0.id == sourceID }
    }

    private var allowedComparisons: [RuleComparison] {
        selectedSource?.kind == .providerHealth
            ? [.changed, .availability]
            : [.below, .above, .changed, .availability]
    }

    private func normalizeComparisonForSource() {
        if !allowedComparisons.contains(comparison) {
            comparison = allowedComparisons.first ?? .changed
        }
    }

    private func addRule() {
        guard let sourceID else { return }
        let predicate: RulePredicate = switch comparison {
        case .below: .numericBelow(threshold)
        case .above: .numericAbove(threshold)
        case .changed: .changed
        case .availability: .availability(availabilityCode)
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = RuleDefinition(
            name: trimmedName.isEmpty ? L10n.string("rules.defaultName") : trimmedName,
            sourceID: sourceID,
            predicate: predicate,
            minimumRepeatInterval: repeatInterval
        )
        Task { await model.saveRule(rule) }
        name = ""
    }

    private func sourceName(for sourceID: WidgetSourceID) -> String {
        ruleSources.first { $0.id == sourceID }?.name ?? sourceID.rawValue
    }
}

private struct RuleRow: View {
    let rule: RuleDefinition
    let sourceName: String
    let condition: String
    let repeatDescription: String
    @Binding var isEnabled: Bool
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.name)
                    Text("\(sourceName) · \(condition)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(repeatDescription)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(
                String(format: L10n.string("rules.delete.accessibilityLabel"), rule.name)
            )
        }
    }
}

private enum RuleComparison: String, Identifiable {
    case below
    case above
    case changed
    case availability

    var id: String { rawValue }
    var label: String { L10n.string("rules.\(rawValue)") }
}

private enum RuleSourceKind {
    case observation
    case providerHealth
}

private struct RuleSourceOption: Identifiable {
    let id: WidgetSourceID
    let name: String
    let kind: RuleSourceKind
}

private enum RuleRepeatInterval: Double, CaseIterable, Identifiable {
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case oneHour = 3600
    case sixHours = 21600

    var id: Double { rawValue }
    var seconds: Double { rawValue }
    var label: String { repeatDescription(rawValue) }
}

private func conditionSummary(_ predicate: RulePredicate) -> String {
    switch predicate {
    case let .numericBelow(value):
        String(format: L10n.string("rules.condition.below"), formattedNumber(value))
    case let .numericAbove(value):
        String(format: L10n.string("rules.condition.above"), formattedNumber(value))
    case .changed:
        L10n.string("rules.changed")
    case let .availability(code):
        String(
            format: L10n.string("rules.condition.availability"),
            localizedAvailability(code)
        )
    }
}

private func repeatDescription(_ seconds: TimeInterval) -> String {
    let key: String? = switch seconds {
    case 60: "rules.repeat.oneMinute"
    case 300: "rules.repeat.fiveMinutes"
    case 900: "rules.repeat.fifteenMinutes"
    case 3600: "rules.repeat.oneHour"
    case 21600: "rules.repeat.sixHours"
    default: nil
    }
    if let key { return L10n.string(key) }
    return String(format: L10n.string("rules.repeat.seconds"), Int(seconds))
}

private func formattedShortDuration(_ seconds: TimeInterval) -> String {
    switch seconds {
    case 60: L10n.string("duration.oneMinute")
    case 300: L10n.string("duration.fiveMinutes")
    case 900: L10n.string("duration.fifteenMinutes")
    case 3600: L10n.string("duration.oneHour")
    default: String(format: L10n.string("duration.seconds"), Int(seconds))
    }
}

private func formattedNumber(_ value: Double?) -> String {
    value?.formatted(.number.precision(.fractionLength(0...2))) ?? "—"
}

private func formattedDelta(_ value: Double?) -> String {
    guard let value else { return "—" }
    let magnitude = abs(value).formatted(.number.precision(.fractionLength(0...2)))
    if value > 0 { return "+\(magnitude)" }
    if value < 0 { return "−\(magnitude)" }
    return magnitude
}

private func localizedAvailability(_ code: AvailabilityCode) -> String {
    L10n.string("availability.\(code.rawValue)")
}

private func localizedRunState(_ state: DiagnosticRunState) -> String {
    L10n.string("diagnostics.state.\(state.rawValue)")
}

private func diagnosticStateIcon(_ state: DiagnosticRunState) -> String {
    switch state {
    case .scheduled: "clock"
    case .running: "record.circle.fill"
    case .stopping: "stop.circle"
    case .completed: "checkmark.circle"
    case .failed: "xmark.octagon"
    case .interrupted: "exclamationmark.triangle"
    }
}

private func diagnosticStateColor(_ state: DiagnosticRunState) -> Color {
    switch state {
    case .scheduled, .stopping: .orange
    case .running: .green
    case .completed: .secondary
    case .failed: .red
    case .interrupted: .yellow
    }
}
