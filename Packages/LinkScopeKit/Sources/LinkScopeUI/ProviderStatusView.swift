import LinkScopeCore
import SwiftUI

struct ProviderStatusView: View {
    @Environment(\.linkScopeLanguage) private var language
    let descriptors: [ProviderDescriptor]
    let statuses: [ProviderStatus]

    var body: some View {
        Group {
            if descriptors.isEmpty {
                ContentUnavailableView {
                    Label(
                        L10n.string("providers.empty", language: language),
                        systemImage: "shippingbox"
                    )
                } description: {
                    Text(L10n.string("providers.empty.description", language: language))
                }
            } else {
                List {
                    Section {
                        ForEach(descriptors) { descriptor in
                            ProviderRow(
                                descriptor: descriptor,
                                status: statuses.first { $0.providerID == descriptor.id }
                            )
                        }
                    } header: {
                        Text(L10n.string("providers.description", language: language))
                            .textCase(nil)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(L10n.string("providers.title", language: language))
    }
}

private struct ProviderRow: View {
    @Environment(\.linkScopeLanguage) private var language
    let descriptor: ProviderDescriptor
    let status: ProviderStatus?

    private var state: ProviderState { status?.state ?? .idle }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: stateSymbol)
                    .foregroundStyle(stateColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.displayName)
                        .font(.headline)
                    Text(descriptor.id.rawValue)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 12)

                Text(L10n.string("providerState.\(state.rawValue)", language: language))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(stateColor)
            }
            .accessibilityElement(children: .combine)

            if let message = status?.message, !message.isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !descriptor.capabilities.isEmpty {
                DisclosureGroup {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                        ForEach(descriptor.capabilities) { capability in
                            GridRow {
                                Text(capability.operation.rawValue.capitalized)
                                    .font(.caption.weight(.medium))
                                Text(capability.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Label(
                        L10n.formatted(
                            "providers.capabilityCount",
                            language: language,
                            descriptor.capabilities.count
                        ),
                        systemImage: "checklist"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var stateSymbol: String {
        switch state {
        case .idle: "pause.circle"
        case .starting: "clock.arrow.circlepath"
        case .running: "checkmark.circle.fill"
        case .permissionDenied: "lock.slash.fill"
        case .unsupported: "questionmark.diamond.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .stopped: "stop.circle"
        }
    }

    private var stateColor: Color {
        switch state {
        case .running: .green
        case .starting: .blue
        case .permissionDenied, .failed: .red
        case .unsupported: .orange
        case .idle, .stopped: .secondary
        }
    }
}
