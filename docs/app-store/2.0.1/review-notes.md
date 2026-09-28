# LinkScope Lite 2.0.1 (12) — App Review drafts

Prepared September 23, 2026. These are drafts to paste into App Store Connect after the user manually creates the archive in Xcode, uploads it, and selects version 2.0.1 (12). No archive, upload, reply, submission, or approval is established by this document. Before resubmission, publish the accompanying reviewed privacy policy at the existing Privacy Policy URL and confirm it is accessible without signing in.

## Reply to App Review — English

Hello App Review,

Thank you for explaining the issue under Guideline 5.1.1(iv). We have updated the permission flow in LinkScope Lite 2.0.1 (12).

The custom buttons preceding the Bluetooth and notification permission requests now say “Continue,” with the corresponding neutral wording in Simplified Chinese. The system permission dialog remains the place where users choose whether to grant access.

Bluetooth Accessories appears first and is marked Required, with a concise explanation that Bluetooth inspection needs access to accessory connection status and parameters. Saved History and Notifications are optional. Users can select “Done” to leave setup without requesting or granting any of these permissions and continue using available features. Bluetooth features depend on Bluetooth access, rule notifications depend on notification access, and saved history depends on optional storage setup. The setup introduction and memory-only message explain these choices neutrally. A declined permission is shown as “Not Allowed”; the user can choose to open System Settings later.

The same permission controls are available in Settings > Permissions and through the toolbar permission control. No account or sign-in is required.

Thank you for reviewing the update.

## Notes for Review — English

LinkScope Lite is a native, sandboxed macOS accessory inspection app requiring macOS 15 or later. It uses public Apple frameworks to display information made available by macOS. It does not pair or unpair devices, issue connection or disconnection commands, change accessory settings, remap input, or update firmware. No account or sign-in is required.

Version 2.0.1 (12) addresses the custom permission-button wording reported under Guideline 5.1.1(iv). Bluetooth Accessories is first and marked Required for Bluetooth inspection. Saved History and Notifications remain optional. “Done” closes setup without granting access.

Review steps:

1. Launch the app. On a first launch, the setup sheet explains the required Bluetooth Accessories access first, followed by optional Saved History and Notifications. Select “Done” to continue without making any permission request. Permission decisions are retained by macOS, so a previously authorized installation may already show its saved status.
2. Open Settings > Permissions, or use the toolbar permission control. For Bluetooth or Notifications that have not yet been requested, select the relevant “Continue” button to present the standard macOS request. Either system choice is supported. If access has been declined, the app shows “Not Allowed” and provides a user-operated “Open Settings” link. Already allowed Bluetooth and notification access has an “Open Settings” button beside its status so users can manage or revoke access. Permission status refreshes when returning to the app. Saved History displays “Enabled” because it is local storage setup, not a System Settings permission.
3. Saved History is optional. Choose “Enable” only to configure local storage for history and dashboards. Without saved storage, available live features continue in memory; history and dashboard changes from that session do not persist after quitting. “Done” never enables saved storage or grants a permission.
4. Review Provider Status, then select an available device in the sidebar. Summary, Raw Parameters, and History show observed values and their availability. Hardware and permissions determine which devices and parameters appear. Declining Bluetooth access does not prevent opening the rest of the workspace.
5. Open Dashboards and create a dashboard. Provider Health and Timeline widgets can be reviewed without a specific accessory. Other widgets require an observed source. To check persistence, enable Saved History, quit normally, and reopen the app.
6. To review active diagnostics, use an accessory already connected through macOS. Open Diagnostics, choose New Diagnostic, and select an available sample-capable source, sampling interval, and duration. Signal strength is available only when the accessory and macOS expose it. Stop the session, review readings or unavailable states, and optionally export CSV. Compatible Bluetooth hardware is needed for Bluetooth signal sampling, but is not needed to review the other workspace features.
7. The main toolbar provides snapshot capture and JSON import/export. Dashboards provide separate JSON layout import/export controls. The menu bar and Shortcuts offer additional snapshot and diagnostic actions. Notifications are optional local alerts for monitoring rules the user enables.

The app does not scan for arbitrary nearby BLE devices. CoreBluetooth is used for controller state and user-initiated Bluetooth authorization.

Observations and saved content are processed locally. There is no automatic developer upload, advertising, analytics integration, or cloud synchronization. User-selected JSON/CSV exports are unencrypted and can contain device names, identifiers, raw observations, and history. The privacy policy explains local storage protection, retention, deletion limits, and permission choices.

Support: https://apps.jasonstu.cc/linkscope/support

Privacy policy: https://apps.jasonstu.cc/linkscope/privacy

## What's New — English

Clarified why Bluetooth access is required for accessory inspection and placed it first in setup. Saved History and Notifications remain optional. Added Settings shortcuts beside granted Bluetooth and notification permissions. Continue opens the macOS permission request, and Done lets you start using available features without granting access. Updated messages explain permission status and when history will remain in memory for the current session.

## 此版本的新功能 — 简体中文

将蓝牙权限放在首位，说明蓝牙检测为何需要此权限。已保存历史和通知仍为可选功能，并在已允许的蓝牙和通知权限旁加入系统设置入口。点击“继续”可打开 macOS 权限请求，点击“完成”可直接进入工作区，无需授予权限。更新权限状态及内存模式说明，明确当前会话的历史记录何时不会在退出后保存。

If App Store Connect treats this as the first public version and does not offer a What's New field, omit that field rather than adding this text to unrelated metadata.
