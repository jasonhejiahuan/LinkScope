import LinkScopeCore
import SwiftUI

struct TimelineListView: View {
    @Environment(\.linkScopeLanguage) private var language
    let events: [TimelineEvent]

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
                List(events) { event in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(event.kind))
                            .foregroundStyle(color(event.kind))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.message).textSelection(.enabled)
                            HStack {
                                Text(event.kind.rawValue)
                                if let provider = event.providerID {
                                    Text(provider.rawValue).font(.caption.monospaced())
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(event.timestamp, format: .dateTime.month().day().hour().minute().second())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(L10n.string("sidebar.timeline", language: language))
    }

    private func icon(_ kind: TimelineEvent.Kind) -> String {
        switch kind {
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

    private func color(_ kind: TimelineEvent.Kind) -> Color {
        switch kind {
        case .deviceConnected, .providerStarted, .systemWake: .green
        case .error: .red
        case .thermalChanged: .orange
        default: .secondary
        }
    }
}

