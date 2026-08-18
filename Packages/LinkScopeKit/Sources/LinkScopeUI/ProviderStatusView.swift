import LinkScopeCore
import SwiftUI

struct ProviderStatusView: View {
    @Environment(\.linkScopeLanguage) private var language
    let descriptors: [ProviderDescriptor]
    let statuses: [ProviderStatus]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        LText("providers.title").font(.largeTitle.weight(.bold))
                        LText("providers.description").foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)

                ForEach(descriptors) { descriptor in
                    ProviderCard(
                        descriptor: descriptor,
                        status: statuses.first { $0.providerID == descriptor.id }
                    )
                }
            }
            .padding()
        }
        .navigationTitle(L10n.string("sidebar.providers", language: language))
    }
}

private struct ProviderCard: View {
    @Environment(\.linkScopeLanguage) private var language
    let descriptor: ProviderDescriptor
    let status: ProviderStatus?

    private var state: ProviderState { status?.state ?? .idle }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(descriptor.displayName).font(.headline)
                        Text(descriptor.id.rawValue)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(stateColor).frame(width: 8, height: 8)
                        Text(L10n.string("providerState.\(state.rawValue)", language: language))
                    }
                    .font(.caption.weight(.medium))
                }

                if let message = status?.message {
                    Text(message).foregroundStyle(.secondary).textSelection(.enabled)
                }

                FlowLayout(spacing: 6) {
                    ForEach(descriptor.capabilities) { capability in
                        Text("\(capability.operation.rawValue) · \(capability.id)")
                            .font(.caption.monospaced())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
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

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

