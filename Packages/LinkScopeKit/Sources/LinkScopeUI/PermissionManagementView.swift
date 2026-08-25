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
                    icon: "key.fill",
                    title: L10n.string("permissions.keychain.title", language: language),
                    reason: L10n.string("permissions.keychain.reason", language: language),
                    state: model.keychainPermissionState,
                    actionTitle: keychainActionTitle
                ) {
                    Task { await model.requestKeychainAccess() }
                }
                Divider().padding(.leading, 48)
                PermissionRow(
                    icon: "wave.3.right",
                    title: L10n.string("permissions.bluetooth.title", language: language),
                    reason: L10n.string("permissions.bluetooth.reason", language: language),
                    state: model.bluetoothPermissionState,
                    actionTitle: bluetoothActionTitle
                ) {
                    if model.bluetoothPermissionState == .denied {
                        openPrivacySettings(anchor: "Privacy_Bluetooth")
                    } else {
                        Task { await model.requestBluetoothAccess() }
                    }
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
                    if model.notificationPermissionState == .denied {
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
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout)
                .foregroundStyle(.orange)
            }

            if showsCompletionButton {
                HStack {
                    Spacer()
                    Button(L10n.string("permissions.continue", language: language)) {
                        onComplete()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .task { await model.refreshPermissionStatuses() }
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
        case .unknown, .allowed: nil
        case .notRequested:
            L10n.string("permissions.allow", language: language)
        case .denied, .unavailable:
            L10n.string("permissions.openSettings", language: language)
        }
    }

    private var notificationActionTitle: String? {
        switch model.notificationPermissionState {
        case .unknown, .allowed: nil
        case .notRequested:
            L10n.string("permissions.allow", language: language)
        case .denied, .unavailable:
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
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
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
                    if optional {
                        Text(L10n.string("permissions.optional", language: language))
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
                Label(statusTitle, systemImage: statusIcon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                if let actionTitle {
                    Button(actionTitle, action: action)
                }
            }
        }
        .padding(14)
    }

    private var statusTitle: String {
        let key = switch state {
        case .unknown: "permissions.status.checking"
        case .notRequested: "permissions.status.notRequested"
        case .allowed: "permissions.status.allowed"
        case .denied: "permissions.status.needsAttention"
        case .unavailable: "permissions.status.unavailable"
        }
        return L10n.string(key, language: language)
    }

    private var statusIcon: String {
        switch state {
        case .allowed: "checkmark.circle.fill"
        case .denied, .unavailable: "exclamationmark.circle.fill"
        case .unknown, .notRequested: "circle.dashed"
        }
    }

    private var statusColor: Color {
        switch state {
        case .allowed: .green
        case .denied, .unavailable: .orange
        case .unknown, .notRequested: .secondary
        }
    }
}
