# LinkScope Lite 2.0.1 (12) review remediation

> Historical preparation record from September 23, 2026. On September 28, the user reported successful worldwide App Store publication. The submission checklist and website observations below describe the earlier preparation session, not current release blockers. The user subsequently supplied App Store Connect text showing **2.0.1 Ready for Distribution**, with build **2.0.1 (13)** uploaded September 23, 2026 at 10:35 PM. Repository version settings now match that build; the earlier build 12 checks below remain historical.

Prepared September 23, 2026. Source changes and Debug verification are complete for the scope described below. The user owns the Release archive, upload, and resubmission in Xcode/App Store Connect. No archive, upload, Apple reply, or submission was performed.

## Reported rejection: 5.1.1(iv)

Apple's September 22 review of 2.0.0 (11) objected to custom **Allow** buttons preceding Bluetooth and notification permission requests.

- Both buttons now say **Continue** / **继续**, in the shared onboarding and Settings permission view used by Full and Lite.
- Bluetooth Accessories appears first and is marked Required, explaining why Bluetooth inspection needs access. Saved History and Notifications remain optional. **Done** / **完成** closes setup with the current choices and does not request any permission or enable storage. A Done button also remains available when reopening the toolbar sheet.
- The introduction explains that the system dialog owns the permission decision. Memory-only operation is explained as information, and denied access is presented neutrally as **Not Allowed** / **未允许**.
- Allowed, denied, or unavailable Bluetooth and notification access has an **Open Settings** action for the corresponding system pane. For allowed access it appears beside the status. The notification URL includes the running edition’s bundle identifier. Permission states refresh when the app becomes active again.
- Each action's accessibility label identifies its capability, so the two Continue buttons can be distinguished.
- The unsolicited Support link was removed from Settings > General. Saved History displays Enabled rather than Allowed: it uses app-owned Keychain storage and has no macOS permission toggle.

## Verification performed

| Check | Result |
| --- | --- |
| `script/check.sh`, Xcode beta, Debug | Passed: 53 Swift Testing tests (2 provider, 16 persistence, 35 core), Full/Lite builds, strict code signatures, provisioning/keychain checks, Bluetooth purpose strings and entitlement lint |
| Normal Full and Lite Debug launches | Both passed `script/build_and_run.sh --verify`; Lite's existing allowed-permission state was inspected in the UI |
| Generated Debug Info.plist, both apps | 2.0.1 (12), with `LinkScope DEBUG` / `LinkScope Lite DEBUG` display names |
| Resolved Release build settings, both schemes | 2.0.1 (12), queried with `-showBuildSettings` only; no Release build |
| Version ownership | Both project configurations own the values; both application targets inherit them |
| Isolated Lite first launch, English and Simplified Chinese | Initial remediation UI rendered with Continue/继续 and Done/完成; subsequent layout now puts required Bluetooth first (see follow-up verification below) |
| Skip setup | Done opened the workspace while Bluetooth and notifications remained Not Requested; Bluetooth providers reported Idle and other providers remained available |
| Reopen permissions | Both Continue controls and a visible Done control remained available |
| Real-use permission test | User reports that real-use testing passed. No user-specific permissions or system toggles were changed during the earlier isolated UI checks. |
| Diff review | Independent source review and `git diff --check` passed |

For fresh-permission UI checks, an isolated temporary copy of the freshly built Lite Debug app used a distinct bundle identity and an ad-hoc QA signature. Its executable code was unchanged; production application/keychain entitlements and provisioning were omitted in this copy. It is not a distribution artifact or a validation of Keychain persistence. Normal Full/Lite development-signed bundles were separately verified. Existing installed-app permissions and saved data were not reset. The temporary QA app was closed after inspection.

Local verification logs: `/tmp/linkscope-2.0.1-check.log`, `/tmp/linkscope-2.0.1-lite-launch.log`, and `/tmp/linkscope-2.0.1-full-launch.log`. These are local Debug evidence, not release assets.

## Additional concrete submission risk

**Publish the updated privacy policy before resubmission.** On September 23, the [public policy](https://apps.jasonstu.cc/linkscope/privacy) returned HTTP 200 but still displayed the brief August 20 policy. It omitted retention/deletion rules and instructions for revoking access. [Guideline 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#privacy) explicitly requires these disclosures.

Ready local replacements:

- [English privacy policy](privacy-policy.en.md)
- [Simplified Chinese privacy policy](privacy-policy.zh-Hans.md)
- [App Review reply, Notes for Review, and release text](review-notes.md)

These policy drafts describe the actual limits: unlimited retention by default; explicit cleanup only for older observations; other record types, Keychain keys, exports and backups are separate; no single erase-all control. They distinguish local processing from user-selected sharing and website/support requests. Publishing the drafts was outside this repository change and has not been performed.

The historical `2.0.0/metadata.json` still contains old build references and instructions to choose Allow. Use the new review notes when resubmitting. Existing 2.0.0 permission marketing screenshots show already-Allowed status, not the rejected Allow action; there is no evidence that those images themselves repeat the rejection.

## Wider audit result and limits

No additional high-confidence rejection blocker was identified in the audited Lite source: it uses public Apple frameworks; enables App Sandbox with Bluetooth and user-selected file access; does not open HID input reports or record audio; and contains no app upload, analytics, account, purchase, or downloaded-code implementation. The in-app privacy link exists. The bundled privacy manifest declares no tracking/collection and the app-local UserDefaults reason `CA92.1`. Product, support and privacy URLs returned HTTP 200.

One secondary quality issue was observed in source, without runtime reproduction and without classifying it as a likely rejection: `CoreAudioProvider` listens for device-list changes but not default-input/output changes, so changing routes between existing devices may leave route observations stale. It is outside this permission remediation.

Live App Store Connect privacy answers, accessibility labels, review contact information, distribution signing, the final archive, and oldest-supported-macOS/hardware coverage were not revalidated. Source and Debug checks do not establish App Review approval.

## Manual resubmission handoff

1. Publish the reviewed policy at the existing public Privacy Policy URL and verify the published content. It still serves the short August 20 policy, so this is the remaining known rejection risk.
2. Create a fresh **LinkScope Lite** Release archive in Xcode GUI at **2.0.1 (12)**, validate it, and upload through Organizer.
3. In App Store Connect, create/select version 2.0.1 and build 12. Add the supplied **What's New** text and **Notes for Review** explaining the permission fix and where to find the controls.
4. Reply briefly to the rejection message that the custom buttons now say Continue and the system dialogs handle the user's decision, then add and submit the new version for review. Apple permits correspondence until resubmission; the reply draft is ready in [review-notes.md](review-notes.md).

References: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Privacy design guidance](https://developer.apple.com/design/human-interface-guidelines/privacy), and Apple's rejection message supplied for this task.

## Follow-up verification

Bluetooth-first ordering, dependency wording, the removed Support link, granted-access Settings buttons, and status refresh were added following user feedback. The user reports that real-use permission testing passed. Version remains 2.0.1 (12).

Follow-up checks passed: 53 tests and both signed Debug builds; Lite Debug launch; English granted-access layout; Chinese first-run layout; Bluetooth shortcut opened Privacy & Security > Bluetooth and showed the app toggle; notification shortcut opened LinkScope Lite’s own notification controls. Settings > General showed only the existing Privacy Policy link, with Support removed. No system permission toggles were changed. The temporary Chinese layout app was closed after inspection.

## Repository review — September 28, 2026

Reviewed the pending shared permission UI, both localizations, project-level version settings, validation script, metadata edits and release-ownership documentation before committing them. Updated the root README to match the local source version and marked the older preparation records as historical after the user's worldwide-release report.

Fresh checks passed: 53 Swift tests; both development-signed Debug builds; generated Info.plist versions and names; entitlement/provisioning checks; metadata length/consistency validation; localization syntax; and whitespace checks. Before aligning the build number with the supplied App Store Connect record, both Release schemes resolved 2.0.1 (12), inspected with build settings only. The source and validation script were then aligned to 2.0.1 (13), with fresh Debug checks for both targets. Targets inherit project-level version values. No Release archive or upload was produced.

The normal Lite Debug app launched. Its existing-authorized permission sheet showed Bluetooth first, optional Saved History as Enabled, optional Notifications, and Done. Both system-settings links reached their intended panes; Done dismissed the sheet and returned to the workspace. System permission switches were not changed. Fresh-install, denied-state and first-time permission prompts were reviewed in source but were not re-exercised in this pass.

The first build attempt encountered `ld: unknown option: -Xlinker` from inherited Conda tool overrides. Clearing those variables only for the validation command allowed the checks to pass without changing project linker settings. Local logs are `/tmp/linkscope-review-check.log` and `/tmp/linkscope-review-launch.log`; they are not repository assets.

After the build-number alignment, all 53 tests and both signed Debug bundle checks passed again at 2.0.1 (13). Lite launched again and its granted-permission sheet retained the expected controls. Follow-up log: `/tmp/linkscope-review-build13-check.log`.
