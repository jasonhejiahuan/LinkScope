import Charts
import LinkScopeCore
import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    let model: LinkScopeApplicationModel
    @State private var selection: UUID?
    @State private var presentingNewSession = false
    @State private var presentingRules = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if let active = model.activeDiagnostic {
                    Section {
                        DiagnosticRunRow(run: active)
                            .tag(active.id)
                    } header: {
                        LText("diagnostics.active")
                    }
                }
                Section {
                    ForEach(model.diagnosticRuns.filter { $0.id != model.activeDiagnostic?.id }) { run in
                        DiagnosticRunRow(run: run)
                            .tag(run.id)
                    }
                } header: {
                    LText("diagnostics.history")
                }
            }
            .navigationTitle(L10n.string("diagnostics.title"))
            .toolbar {
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
            }
        } detail: {
            if let selection,
               let run = model.diagnosticRuns.first(where: { $0.id == selection }) {
                DiagnosticDetailView(model: model, run: run)
            } else {
                ContentUnavailableView(
                    L10n.string("diagnostics.noSelection"),
                    systemImage: "waveform.path.ecg"
                )
            }
        }
        .sheet(isPresented: $presentingNewSession) {
            NewDiagnosticView(model: model) { runID in
                selection = runID
                presentingNewSession = false
            }
        }
        .sheet(isPresented: $presentingRules) {
            RuleManagementView(model: model)
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

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    ForEach(model.rules) { rule in
                        HStack {
                            Toggle(
                                rule.name,
                                isOn: Binding(
                                    get: { rule.isEnabled },
                                    set: { enabled in
                                        var changed = rule
                                        changed.isEnabled = enabled
                                        Task { await model.saveRule(changed) }
                                    }
                                )
                            )
                            Button(role: .destructive) {
                                Task { await model.deleteRule(id: rule.id) }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    LText("rules.existing")
                }
                Section {
                    TextField(L10n.string("rules.name"), text: $name)
                    Picker(L10n.string("rules.source"), selection: $sourceID) {
                        Text("—").tag(nil as WidgetSourceID?)
                        ForEach(ruleSources) { source in
                            Text(source.name).tag(source.id as WidgetSourceID?)
                        }
                    }
                    Picker(L10n.string("rules.condition"), selection: $comparison) {
                        Text(L10n.string("rules.below")).tag(RuleComparison.below)
                        Text(L10n.string("rules.above")).tag(RuleComparison.above)
                        Text(L10n.string("rules.changed")).tag(RuleComparison.changed)
                    }
                    if comparison != .changed {
                        TextField(L10n.string("rules.threshold"), value: $threshold, format: .number)
                    }
                    Button(L10n.string("rules.add")) {
                        guard let sourceID else { return }
                        let predicate: RulePredicate = switch comparison {
                        case .below: .numericBelow(threshold)
                        case .above: .numericAbove(threshold)
                        case .changed: .changed
                        }
                        let rule = RuleDefinition(
                            name: name.isEmpty ? L10n.string("rules.defaultName") : name,
                            sourceID: sourceID,
                            predicate: predicate
                        )
                        Task {
                            await model.saveRule(rule)
                            name = ""
                        }
                    }
                    .disabled(sourceID == nil)
                } header: {
                    LText("rules.new")
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button(L10n.string("common.done")) { dismiss() }
            }
            .padding()
        }
        .frame(width: 540, height: 560)
    }

    private var ruleSources: [RuleSourceOption] {
        let observations = model.diagnosticSources.map {
            RuleSourceOption(id: $0.id, name: $0.displayName)
        }
        let providers = model.providerDescriptors.map {
            RuleSourceOption(
                id: WidgetSourceID(rawValue: "provider:\($0.id.rawValue)"),
                name: "\($0.displayName) · Health"
            )
        }
        return observations + providers
    }
}

private enum RuleComparison: String, CaseIterable {
    case below, above, changed
}

private struct RuleSourceOption: Identifiable {
    let id: WidgetSourceID
    let name: String
}

private struct DiagnosticRunRow: View {
    let run: DiagnosticRun

    var body: some View {
        HStack {
            Image(systemName: run.state == .running ? "record.circle" : "waveform.path.ecg")
                .foregroundStyle(run.state == .running ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(run.name).lineLimit(1)
                Text(run.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
                            systemImage: "sensor.tag.radiowaves.forward"
                        )
                    } else {
                        ForEach(model.diagnosticSources) { source in
                            Toggle(
                                source.displayName,
                                isOn: Binding(
                                    get: { selectedSources.contains(source.id) },
                                    set: { selected in
                                        if selected {
                                            selectedSources.insert(source.id)
                                        } else {
                                            selectedSources.remove(source.id)
                                        }
                                    }
                                )
                            )
                        }
                    }
                } header: {
                    LText("diagnostics.sources")
                }
                Section {
                    Picker(L10n.string("diagnostics.interval"), selection: $interval) {
                        Text("2 s").tag(2.0)
                        Text("5 s").tag(5.0)
                        Text("10 s").tag(10.0)
                        Text("30 s").tag(30.0)
                    }
                    Toggle(L10n.string("diagnostics.limitDuration"), isOn: $hasDuration)
                    if hasDuration {
                        Picker(L10n.string("diagnostics.duration"), selection: $duration) {
                            Text("1 min").tag(60.0)
                            Text("5 min").tag(300.0)
                            Text("15 min").tag(900.0)
                            Text("1 h").tag(3600.0)
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
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
                .disabled(selectedSources.isEmpty)
            }
            .padding()
        }
        .frame(width: 560, height: 620)
    }

    private func start() async {
        do {
            try await model.startDiagnostic(
                name: name,
                purpose: purpose,
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
    @State private var observations: [ResolvedObservation] = []
    @State private var loadError: String?
    @State private var exporting = false
    @State private var exportDocument: DiagnosticCSVDocument?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DiagnosticHeader(model: model, run: run)
                DiagnosticMetrics(run: run, observations: observations)
                DiagnosticChart(observations: observations)
                DiagnosticObservationTable(observations: observations)
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle(run.name)
        .toolbar {
            Button {
                exportDocument = DiagnosticCSVDocument(observations: observations)
                exporting = true
            } label: {
                Label(L10n.string("diagnostics.exportCSV"), systemImage: "square.and.arrow.up")
            }
            .disabled(observations.isEmpty)
        }
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
        .task(id: run.sampleCount) {
            do {
                observations = try await model.observations(for: run)
                loadError = nil
            } catch {
                loadError = error.localizedDescription
            }
        }
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(run.purpose.isEmpty ? L10n.string("diagnostics.noPurpose") : run.purpose)
                    .foregroundStyle(.secondary)
                Text(run.startedAt ?? run.createdAt, format: .dateTime)
                if let endedAt = run.endedAt {
                    Text(endedAt, format: .dateTime)
                }
            }
            Spacer()
            if run.state == .running {
                Button(role: .destructive) {
                    Task { await model.stopDiagnostic() }
                } label: {
                    Label(L10n.string("diagnostics.stop"), systemImage: "stop.fill")
                }
            }
        }
    }
}

private struct DiagnosticMetrics: View {
    let run: DiagnosticRun
    let observations: [ResolvedObservation]

    var body: some View {
        HStack(spacing: 12) {
            MetricCard(title: L10n.string("diagnostics.samples"), value: "\(run.sampleCount)")
            MetricCard(title: L10n.string("diagnostics.gaps"), value: "\(run.gapCount)")
            MetricCard(title: L10n.string("diagnostics.minimum"), value: formatted(numericValues.min()))
            MetricCard(title: L10n.string("diagnostics.maximum"), value: formatted(numericValues.max()))
            MetricCard(title: L10n.string("diagnostics.average"), value: formatted(average))
        }
    }

    private var numericValues: [Double] {
        observations.compactMap { observation in
            switch observation.observation.value {
            case let .signedInt(value): Double(value)
            case let .unsignedInt(value): Double(value)
            case let .double(value): value
            default: nil
            }
        }
    }

    private var average: Double? {
        numericValues.isEmpty ? nil : numericValues.reduce(0, +) / Double(numericValues.count)
    }

    private func formatted(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(0...1))) ?? "—"
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DiagnosticChart: View {
    let observations: [ResolvedObservation]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Source", point.source))
        }
        .frame(minHeight: 260)
        .chartLegend(position: .bottom)
    }

    private var points: [DiagnosticPoint] {
        observations.compactMap { resolved in
            let value: Double?
            switch resolved.observation.value {
            case let .signedInt(raw): value = Double(raw)
            case let .unsignedInt(raw): value = Double(raw)
            case let .double(raw): value = raw
            default: value = nil
            }
            return value.map {
                DiagnosticPoint(
                    id: resolved.id,
                    date: resolved.observation.timestamp,
                    value: $0,
                    source: resolved.identity.physicalAccessory.displayName
                )
            }
        }
        .sorted { $0.date < $1.date }
    }
}

private struct DiagnosticPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
    let source: String
}

private struct DiagnosticObservationTable: View {
    let observations: [ResolvedObservation]

    var body: some View {
        Table(observations) {
            TableColumn(L10n.string("diagnostics.time")) {
                Text($0.observation.timestamp, format: .dateTime.hour().minute().second())
            }
            TableColumn(L10n.string("diagnostics.source")) {
                Text($0.identity.physicalAccessory.displayName)
            }
            TableColumn(L10n.string("diagnostics.parameter")) {
                Text($0.observation.parameterPath.rawValue)
            }
            TableColumn(L10n.string("diagnostics.value")) {
                Text($0.observation.value?.compactDescription ?? $0.observation.availability.code.rawValue)
            }
        }
        .frame(minHeight: 240)
    }
}
