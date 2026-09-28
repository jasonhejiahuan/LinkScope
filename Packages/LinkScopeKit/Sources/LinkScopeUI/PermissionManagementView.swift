import AppKit
import SwiftUI

public struct PermissionManagementView: View {
    public let model: LinkScopeApplicationModel
    public let isOnboarding: Bool
    public let showsCompletionButton: Bool
    public let onComplete: () -> Void

    @Environment(\.linkScopeLanguage) private var language

    public init(
        model: LinkScopeApplicationModel,
        isOnboarding: Bool = false,
        showsCompletionButton: Bool = false,
        onComplete: @escaping () -> Void = {}
    ) {
        self.model = model
        self.isOnboarding = isOnboarding
        self.showsCompletionButton = showsCompletionButton
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isOnboarding {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("permissions.welcome.title", language: language))
                        .font(.title2.bold())
                    Text(L10n.string("permissions.welcome.message", language: language))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                PermissionRow(
                    icon: "wave.3.right",
                    title: L10n.string("permissions.bluetooth.title", language: language),
                    reason: L10n.string("permissions.bluetooth.reason", language: language),
                    state: model.bluetoothPermissionState,
                    actionTitle: bluetoothActionTitle,
                    required: true
                ) {
                    if [.allowed, .denied, .unavailable].contains(model.bluetoothPermissionState) {
                        openPrivacySettings(anchor: "Privacy_Bluetooth")
                    } else {
                        Task { await model.requestBluetoothAccess() }
                    }
                }
                Divider().padding(.leading, 48)
                PermissionRow(
                    icon: "key.fill",
                    title: L10n.string("permissions.keychain.title", language: language),
                    reason: L10n.string("permissions.keychain.reason", language: language),
                    state: model.keychainPermissionState,
                    actionTitle: keychainActionTitle,
                    optional: true,
                    allowedStatusTitle: L10n.string("permissions.status.enabled", language: language)
                ) {
                    Task { await model.requestKeychainAccess() }
                }
                Divider().padding(.leading, 48)
                PermissionRow(
                    icon: "bell.badge.fill",
                    title: L10n.string("permissions.notifications.title", language: language),
                    reason: L10n.string("permissions.notifications.reason", language: language),
                    state: model.notificationPermissionState,
                    actionTitle: notificationActionTitle,
                    optional: true
                ) {
                    if [.allowed, .denied, .unavailable].contains(model.notificationPermissionState) {
                        openNotificationSettings()
                    } else {
                        Task { await model.requestNotificationAuthorization() }
                    }
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

            if !model.isUsingPersistentStorage {
                Label(
                    L10n.string("permissions.memoryOnly", language: language),
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if showsCompletionButton {
                HStack {
                    Spacer()
                    Button(L10n.string("permissions.done", language: language)) {
                        onComplete()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .task { await model.refreshPermissionStatuses() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refreshPermissionStatuses() }
        }
    }

    private var keychainActionTitle: String? {
        switch model.keychainPermissionState {
        case .unknown, .allowed: nil
        case .notRequested:
            L10n.string("permissions.enable", language: language)
        case .denied, .unavailable:
            L10n.string("permissions.tryAgain", language: language)
        }
    }

    private var bluetoothActionTitle: String? {
        switch model.bluetoothPermissionState {
        case .unknown: nil
        case .notRequested:
            L10n.string("permissions.continue", language: language)
        case .allowed, .denied, .unavailable:
            L10n.string("permissions.openSettings", language: language)
        }
    }

    private var notificationActionTitle: String? {
        switch model.notificationPermissionState {
        case .unknown: nil
        case .notRequested:
            L10n.string("permissions.continue", language: language)
        case .allowed, .denied, .unavailable:
            L10n.string("permissions.openSettings", language: language)
        }
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openNotificationSettings() {
        var components = URLComponents(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        if let bundleID = Bundle.main.bundleIdentifier {
            components?.queryItems = [URLQueryItem(name: "id", value: bundleID)]
        }
        guard let url = components?.url else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let reason: String
    let state: LinkScopePermissionState
    let actionTitle: String?
    var optional = false
    var required = false
    var allowedStatusTitle: String?
    let action: () -> Void

    @Environment(\.linkScopeLanguage) private var language

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title).fontWeight(.semibold)
                    if optional || required {
                        Text(L10n.string(required ? "permissions.required" : "permissions.optional", language: language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Label(statusTitle, systemImage: statusIcon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                    if state == .allowed {
                        actionButton
                    }
                }
                if state != .allowed {
                    actionButton
                }
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle {
            Button(actionTitle, action: action)
                .accessibilityLabel("\(actionTitle), \(title)")
        }
    }

    private var statusTitle: String {
        if state == .allowed, let allowedStatusTitle {
            return allowedStatusTitle
        }
        let key = switch state {
        case .unknown: "permissions.status.checking"
        case .notRequested: "permissions.status.notRequested"
        case .allowed: "permissions.status.allowed"
        case .denied: "permissions.status.notAllowed"
        case .unavailable: "permissions.status.unavailable"
        }
        return L10n.string(key, language: language)
    }

    private var statusIcon: String {
        switch state {
        case .allowed: "checkmark.circle.fill"
        case .denied: "minus.circle"
        case .unavailable: "exclamationmark.circle.fill"
        case .unknown, .notRequested: "circle.dashed"
        }
    }

    private var statusColor: Color {
        switch state {
        case .allowed: .green
        case .unavailable: .orange
        case .unknown, .notRequested, .denied: .secondary
        }
    }
}
