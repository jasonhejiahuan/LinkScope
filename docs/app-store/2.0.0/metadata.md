# LinkScope Lite — App Store Connect 字段与宣传文案

核对日期：2026-09-19。源码读取范围：当前 LinkScope 仓库，版本设置 `2.0.0 (9)`。用途：供最终复核后填写 App Store Connect。英文与简中粘贴文本同时保存于 `metadata.json`；状态与待定账号字段以该文件为准。本文件不代表已上传、提交或审核通过，实机测试结论以本目录单独报告为准。

## 1. 产品定位与使用条件

LinkScope Lite 是 macOS 配件检查工具：集中查看系统公开的数据、检查状态和参数、开展按需诊断、组织仪表盘。定位为观察与分析，不提供配对、断开、改键、配置写入、固件更新或网络测速。

- 面向 Mac 用户、配件爱好者、开发者和技术支持人员。
- 宣传主体优先顺序：检查配件 → 组织仪表盘 → 按需诊断 → 保存与导出。
- 平台最低版本由源码设置为 macOS 15.0。兼容性矩阵实际已测范围见单独测试报告，不以最低部署目标推导已测兼容性。
- 可见设备、参数、RSSI 和电池数据依赖硬件、macOS 与权限；不承诺所有配件、附近设备扫描、所有电池或完整无线诊断。
- 公开可用 API 与 Sandbox 是实现边界，不写成“已获 Apple 审核通过”。

## 2. 英语元数据（en-US）

### App Name

```text
LinkScope Lite
```

### Subtitle

```text
Bluetooth & Device Inspector
```

### Promotional Text

```text
See your Mac's accessories more clearly. Inspect available parameters, follow changes with diagnostics, and build dashboards around the details that matter.
```

### Description

```text
A clearer view of your Mac's accessories.

LinkScope Lite brings device details, connection states, and system-reported parameters into one native Mac workspace. Explore what your Mac can see, follow changes over time, and build a dashboard for the details you care about.

INSPECT THE DETAILS
Browse supported Bluetooth, input, audio, and game controller devices exposed by macOS. View raw parameters alongside their source, update time, and availability. Distinct states help you tell a missing reading from a permission issue or an unsupported value.

MAKE THE WORKSPACE YOURS
Create named dashboards with six widget types: current value, availability status, time series, raw table, timeline, and provider health. Move and resize widgets, edit with the keyboard, and use Undo and Redo to refine your layout.

DIAGNOSE ON DEMAND
Start a diagnostic session for available sample-capable sources, including Bluetooth signal strength where supported. Choose a sampling interval and duration, review recorded gaps, compare sessions, and export the displayed readings as CSV. Sampling is started explicitly and can be stopped at any time.

KEEP USEFUL CONTEXT
Capture snapshots, review an event timeline, and import or export observation history as JSON. Save dashboard layouts as portable JSON documents. Set rules for parameter changes, availability, numeric thresholds, or provider status, with optional notifications.

AT HOME ON YOUR MAC
Get a quick status summary from the menu bar. Use Shortcuts to capture a snapshot or start, stop, and check a diagnostic session. Switch between English and Simplified Chinese in Settings.

Availability depends on your Mac, macOS version, connected accessories, and permissions. Some devices do not expose signal strength or battery information. LinkScope Lite observes system-reported information; it does not pair devices, change accessory settings, remap controls, or update firmware.

Enable Saved History to retain observations and dashboards between launches. Without access to saved storage, the app continues in memory-only mode. Exported files can include device names and identifiers; review them before sharing.

Requires macOS 15 or later. No app account is required.
```

### Keywords

```text
diagnostics,dashboard,signal,rssi,peripheral,monitor,hardware,timeline,json,csv
```

### What's New in 2.0

仅用于已经存在 App Store 旧版本的更新；如果此次为首次上架，App Store Connect 不提供此栏，可将其用作网站发布说明。

```text
Build a workspace around the details that matter.

• Create named dashboards with six widget types and a flexible twelve-column layout.
• Move and resize widgets with the pointer or keyboard, with Undo and Redo.
• Explore current values, availability, time series, raw tables, timelines, and provider health in one place.
• Import and export dashboard layouts as JSON. Unavailable sources stay in the layout with a clear explanation.
• Manage Saved History, Bluetooth access, and notifications from a shared Permissions view.
• Improved dashboard restoration after quitting and reopening the app, plus fixes for window startup.
```

## 3. 简体中文元数据（zh-Hans）

### App Name

```text
LinkScope Lite
```

### Subtitle

```text
蓝牙配件检查与自定义仪表盘
```

### Promotional Text

```text
更清楚地了解 Mac 配件。查看系统提供的参数，按需诊断信号变化，用自定义仪表盘集中呈现你关心的信息。
```

### Description

```text
看清 Mac 配件的每一份可用信息。

LinkScope Lite 将设备信息、连接状态和系统提供的参数汇集到原生 Mac 工作区。查看当前状态，追踪变化，再把关心的数据整理成自己的仪表盘。

深入查看配件
浏览 macOS 能够识别的蓝牙、输入、音频和游戏控制器设备。检查原始参数，以及数据来源、更新时间和可用状态。没有读数、权限不足或系统不支持，都会明确显示。

打造自己的工作区
创建命名仪表盘，组合当前值、可用状态、时间序列、原始表格、时间线和数据源健康状态六类组件。支持拖动、调整大小、键盘编辑，以及撤销和重做。

需要时，再开始诊断
为支持采样的数据源创建诊断会话，包括系统可提供的蓝牙信号强度。选择采样间隔和时长，查看记录中的中断、对比不同会话，并将当前显示的读数导出为 CSV。采样由你主动开始，也可随时停止。

保留有用的上下文
捕获快照、查看事件时间线，通过 JSON 导入或导出观察历史，也可单独保存仪表盘布局。为参数变化、可用状态、数值阈值或数据源状态设置规则，并按需开启通知。

融入 Mac 使用习惯
从菜单栏快速查看概况，使用快捷指令捕获快照、开始或停止诊断、查询诊断状态。可在设置中切换英语和简体中文。

可见设备与参数取决于 Mac、macOS 版本、连接的配件和权限。部分设备不会提供信号强度或电池信息。LinkScope Lite 用于观察系统提供的数据，不执行设备配对、配件设置修改、按键映射或固件更新。

启用“已保存历史”后，可在重新启动应用后继续查看已保存的观察记录和仪表盘。无法访问保存空间时，应用会以内存模式继续运行。导出文件可能包含设备名称和标识符，分享前请先检查内容。

需要 macOS 15 或更高版本，无需注册应用账户。
```

### Keywords

```text
连接状态,参数查看,信号强度,诊断工具,历史记录,数据导出,快捷指令
```

### What's New in 2.0

```text
围绕你关心的数据，打造自己的工作区。

• 新增命名仪表盘，提供六类组件和灵活的十二列布局。
• 使用鼠标或键盘移动组件、调整大小，支持撤销和重做。
• 集中查看当前值、可用状态、时间序列、原始表格、时间线和数据源健康状态。
• 通过 JSON 导入或导出仪表盘。暂不可用的数据源会保留在布局中，并显示原因。
• 在统一的权限页面管理已保存历史、蓝牙访问与通知。
• 改进正常退出后重新打开的仪表盘恢复体验，并修复窗口启动问题。
```

## 4. App Review Notes（English，提交前与最终构建复核）

```text
LinkScope Lite is a native, sandboxed macOS accessory inspection app. It uses public Apple frameworks to display information that macOS makes available. It does not pair or unpair devices, initiate connection or disconnection commands, change accessory settings, remap input, or update firmware. No app account or sign-in is required.

Review steps:
1. Launch the app. The first-run Permissions view offers Saved History, Bluetooth Accessories, and optional Notifications. Choose Enable for Saved History to retain history and dashboards, and Allow for Bluetooth Accessories to inspect permitted Bluetooth data. Continue opens the main workspace. Permissions are also available in Settings.
2. Review Provider Status, then select an available device in the sidebar. Summary, Raw Parameters, and History display observed values and availability states. Hardware and permissions determine which devices and parameters appear.
3. Open Dashboards and choose New Dashboard. Add a Provider Health or Timeline widget; these are useful without a specific accessory. Other widget types require an observed source. Use the Widget Inspector to select a source, then move or resize the widget. Quit normally and reopen to check saved layouts after Saved History has been enabled.
4. To test active diagnostics, connect a supported Bluetooth accessory using macOS settings before opening Diagnostics. Choose New Diagnostic, select an available sample-capable source, and set an interval and duration. Bluetooth RSSI is available only when exposed by the connected device and system. The app intentionally shows unavailable states if data is not reported. Stop the session, inspect its readings, and optionally export CSV. Lack of compatible hardware does not prevent reviewing the rest of the app.
5. The main toolbar supports snapshot capture and JSON import/export. Dashboards have their own JSON import/export controls. The menu bar and Shortcuts provide additional snapshot and diagnostic actions.

The app does not scan for arbitrary nearby BLE devices. CoreBluetooth is used for controller state and explicit Bluetooth authorization. Idle providers use system events; diagnostic sampling is explicitly started by the user.

If saved storage cannot be enabled, the app continues in memory-only mode and explains this in Permissions. Optional notifications are requested only by user action. User-selected exports may contain device names, identifiers, raw observations, and history.

Support and product information: https://apps.jasonstu.cc/linkscope
Privacy policy: https://apps.jasonstu.cc/linkscope/privacy
```

Review Notes 内不填写私人联系人、设备地址、开发机标识符、Keychain 内容或真实用户原始日志。建议附件提供本轮测试录屏/步骤 PDF；只用经筛选的脱敏材料。

## 5. 非本地化字段与待定项

| 字段 | 建议或已知值 | 状态 |
| --- | --- | --- |
| Platform | macOS | 源码确认 |
| Bundle ID | `cc.jasonstu.linkscope.lite` | Lite 源码确认；提交时与 App ID/Profile 对齐 |
| Version | `2.0.0` | 当前源码；最终上传档案再次核对 |
| Build | `9` | 当前源码；若 App Store 已有该 build，则必须增加后重新构建 |
| Primary Language | English (U.S.) | 建议，与当前默认本地化一致 |
| Additional Localization | Chinese (Simplified) | 源码已包含 |
| Primary Category | Utilities | 建议；当前 `LSApplicationCategoryType` 已为 `public.app-category.utilities` |
| Secondary Category | 留空 | 可选；当前 JSON 不设置第二分类 |
| Support URL | `https://apps.jasonstu.cc/linkscope` | 用户指定；产品页及 `/linkscope/support` 已返回 200，支持子页提供 GitHub Issues 渠道 |
| Marketing URL | `https://apps.jasonstu.cc/linkscope` | 用户指定 |
| Privacy Policy URL | `https://apps.jasonstu.cc/linkscope/privacy` | 用户指定；最终隐私稿需在此上线并与版本一致 |
| Privacy Choices URL | 留空 | 未发现独立账户/在线隐私选择服务；如果后续提供专用页面再填 |
| Copyright | `2026 JASON Studio` | 候选；需用户确认实际权利人和首次取得权利年份，不加 © |
| Content Rights | No, it does not contain, show, or access third-party content | 候选；设备系统信息不是内容分发服务，提交人仍须核对实际发布素材授权 |
| Sign-in Required | No | 当前产品无应用账户登录流程 |
| Review Contact | 姓、名、有效电话（国际格式）、邮箱 | 必须由用户提供，不能用作者署名替代 |
| SKU | 使用现有记录；新建时由用户确定 | 建议内部值 `linkscope-lite-macos`，未创建且非已存在值 |
| Price | **Free / 免费** | 用户已明确确认本次发行免费；尚未在 App Store Connect 保存定价 |
| Availability | 待用户确认国家/地区 | 不默认全球；按所选地区补充对应资料 |
| Release Method | Manually release this version | 建议，便于最终检查与网站同步；尚未操作 ASC |
| License Agreement | Apple standard EULA，除非用户提供自定义协议 | 建议，不自行编造额外合同条款 |
| App Privacy | **Data Not Collected / 未收集数据**；Tracking = No | 依据已完成源码审计的**候选答案，尚未提交**；最终二进制与实际运营行为须一致，详见 `privacy-and-encryption.md` |
| Export Compliance | Uses encryption = Yes；Apple OS only = Yes；`ITSAppUsesNonExemptEncryption = false` | 已审计候选答案，尚未在账号保存；当前 OS-only 路线无需上传加密文档，最终归档仍需核对 |
| Screenshots | en-US / zh-Hans 各 4 张，2880×1800 RGB PNG | 用户提供的原生数据源、仪表盘、历史诊断、权限界面；8 张成品已逐张目视检查，详见 `Design/AppStore/2.0.0` |
| App Preview | 可选，暂不要求制作 | 如制作，使用实际操作内容 |
| Apple ID | 由 Apple 自动生成，读取现有记录 | 账号待定，不编造 |
| Distribution Method | Public | 建议，尚未操作 ASC |
| Tax Category | App Store Software | 建议默认，提交人按实际业务核对 |
| Reset Overview Rating | 不重置 | 建议；首次发布不适用 |
| Routing App Coverage File | 不适用 | 当前产品不是路线导航应用 |
| Regulated Medical Device | Not a regulated medical device | 当前功能的候选答案；最终按账号实际问题确认 |
| Accessibility | 暂不声明未验证的支持项；Accessibility URL 留空 | 可选；不能从 AX 元素可见或深色外观推导整项通过 |
| App Icon | 最终 Lite 发行包中的应用图标 | 最终二进制检查，勿使用 Full 或 Debug 包 |
| DSA / Agreements / Tax / Banking | 按真实主体与所选地区填写 | 账号待定；不存在可由代码补齐的身份或财务值 |

年龄评级候选：所有敏感内容频率选 None；Parental Controls、Age Assurance、Advertising、Messaging and Chat、Unrestricted Web Access、User-Generated Content、Social Media、Contests、Gambling、Loot Boxes 均为 No。系统参数、用户本机命名的仪表盘、手动导入 JSON，并非 App 内广泛传播用户内容。预期为 4+，以完整问卷计算结果及地区要求为准；不要选择 Made for Kids，也不要把 4+ 描述为儿童应用。

年龄内容需逐项核对：粗俗/亵渎语言、惊悚/恐怖、酒精烟草药物、健康主题、医疗治疗信息、成熟/暗示性主题、性内容/裸露、露骨性内容/裸露、卡通/幻想暴力、真实暴力、持续或虐待性暴力、枪支武器、模拟赌博，候选均 None。此列表用于答题准备，最终界面可能按地区及 OS 分组展示。

## 6. 宣传短句与本轮截图文案

本轮截图为数据源、仪表盘、历史诊断和权限四张，英语与简体中文各一套，共 8 张。用户提供的原生 PNG 窗口完整嵌入版式，等比适配且不放大；最终 PNG、可编辑模板与目视验收记录见 `Design/AppStore/2.0.0`。参考 Apple 公开 macOS 宣传页的黑色舞台、大号银白标题与克制留白，不使用 Apple 标志或虚构硬件、图表。

| 用途 | English | 简体中文 |
| --- | --- | --- |
| 网页主标题 | A clearer view of your accessories. | 更清楚地了解你的配件。 |
| 网页副标题 | Inspect system-reported details. Follow changes. Build your own workspace. | 查看系统参数，追踪状态变化，打造自己的工作区。 |
| 截图 1：数据源标题 | See every source clearly. | 数据来源，一目了然。 |
| 截图 1：副标题 | Independent providers. Explicit availability. | 独立的数据源，明确的可用状态。 |
| 截图 2：仪表盘标题 | Your details. Your dashboard. | 关心的数据，按你的方式呈现。 |
| 截图 2：副标题 | Arrange a workspace around what matters. | 把重要信息，整理成自己的工作区。 |
| 截图 3：诊断标题 | Review the signal history. | 信号变化，有迹可循。 |
| 截图 3：副标题 | Inspect recorded readings, gaps, and trends. | 查看已记录的读数、中断与趋势。 |
| 截图 4：权限标题 | Permissions, on your terms. | 权限，由你掌握。 |
| 截图 4：副标题 | Review access. Keep saved history on your Mac. | 清楚了解每项授权，在本机保留历史。 |

图面小标签统一为 `LinkScope Lite` / `For Mac`。全部输出为 2880×1800 RGB PNG，无透明通道。采集前选择不暴露私人设备名称、地址、路径或 UUID 的界面；不绘制虚构 RSSI 波形，也不以 UI 状态截图证明主动采样已经通过。

## 7. 可发布主张与源码证据映射

以下证明实现存在，不代表本轮硬件、生产签名或 App Store 上传验证通过。路径均相对仓库根目录。

| 主张 | 源码证据 | 限定与待验证 |
| --- | --- | --- |
| Lite 为沙盒 Mac 应用 | `Apps/LinkScopeLite/LinkScopeLite.entitlements:9`; `Apps/LinkScopeLite/LinkScopeLiteApp.swift:13` | 最终档案须验证 Sandbox、生产签名/描述文件 |
| 公开数据源 | `Packages/LinkScopeKit/Sources/LinkScopeProviders/PublicProviderFactory.swift:4`; `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeApplicationModel.swift:65` | 不代表每个数据源在全部 Mac 均能取得数据 |
| 原始参数、来源、可用性和历史 | `Packages/LinkScopeKit/Sources/LinkScopeUI/AccessoryDetailView.swift:4` | Summary/Raw Parameters/History 的真实数据需实机验收 |
| 状态分组、协议分组及排序 | `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeRootView.swift:17`; `Packages/LinkScopeKit/Sources/LinkScopeUI/AccessoryListPresentation.swift:76` | 不是自定义用户分组、收藏、备注或别名编辑 |
| 六类仪表盘组件、编辑、撤销/重做 | `Packages/LinkScopeKit/Sources/LinkScopeUI/DashboardView.swift:9`; `Packages/LinkScopeKit/Sources/LinkScopeUI/DashboardView.swift:269`; `Packages/LinkScopeKit/Sources/LinkScopeUI/DashboardView.swift:302`; `Packages/LinkScopeKit/Sources/LinkScopeUI/DashboardView.swift:317` | 数值/历史图需要可用 source；历史运行记录不能替代本次测试 |
| 仪表盘 JSON 导入导出 | `Packages/LinkScopeKit/Sources/LinkScopeUI/DashboardView.swift:406`; `Packages/LinkScopeKit/Sources/LinkScopeUI/DashboardView.swift:416` | 不宣传跨设备自动同步 |
| 明确启动、停止的采样诊断 | `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeApplicationModel.swift:358`; `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeApplicationModel.swift:374`; `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeApplicationModel.swift:411` | 当前主动采样主要 IOBluetooth RSSI，不能推导所有数据可高频采样 |
| RSSI 支持 | `Packages/LinkScopeKit/Sources/LinkScopeProviders/IOBluetoothProvider.swift:90` | 连接状态、class-of-device 与系统返回值限制；127 视为 unavailable |
| 电池数据 | `Packages/LinkScopeKit/Sources/LinkScopeProviders/GameControllerProvider.swift:88` | 仅系统暴露控制器 battery 对象时，不能宣传所有蓝牙配件电量 |
| CoreBluetooth 状态 | `Packages/LinkScopeKit/Sources/LinkScopeProviders/CoreBluetoothProvider.swift:106` | 无全局扫描，不枚举任意附近/已连接 BLE 外设 |
| CSV 导出与诊断对比 | `Packages/LinkScopeKit/Sources/LinkScopeUI/DiagnosticsView.swift:18`; `Packages/LinkScopeKit/Sources/LinkScopeUI/DiagnosticsView.swift:451` | CSV 导出当前筛选后的 observations，不承诺整个无限历史一键导出 CSV |
| 快照和历史 JSON | `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeApplicationModel.swift:758`; `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeApplicationModel.swift:777` | 本机显式导出可能含标识符，非匿名数据 |
| 规则与可选通知 | `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeApplicationModel.swift:217`; `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeApplicationModel.swift:688` | 依赖可观测数据和通知权限；不是设备故障自动修复 |
| 菜单栏状态与快捷指令 | `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeMenuBarView.swift:4`; `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeAppIntents.swift:15` | Shortcuts 需本次实机验证；没有源时诊断动作会报无可采样源 |
| 英语/简体中文 | `Packages/LinkScopeKit/Sources/LinkScopeUI/LinkScopeSettingsView.swift:6`; `Packages/LinkScopeKit/Sources/LinkScopeUI/Resources/en.lproj/Localizable.strings`; `Packages/LinkScopeKit/Sources/LinkScopeUI/Resources/zh-Hans.lproj/Localizable.strings` | 英语 Review Notes 中使用实际英语 UI 标签 |
| 不修改配件的设计边界 | `docs/architecture/INVARIANTS.md:3`; `Packages/LinkScopeKit/Sources/LinkScopeCore/Provider.swift` | 不等于不写任何本机数据；会保存自己的历史/布局 |

避免文案：全能蓝牙扫描器、所有配件电量、提升信号、修复连接、网络测速、抓包、无限制后台监控、零能耗、零 CPU、完整数据库全部加密、永久匿名、Apple 官方/认证工具，以及未实现的别名/收藏/备注功能。现有文档中的能耗数字是参考机目标，不能放进宣传。

## 8. Apple 官方依据（2026-09-19 读取）

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)：App Name 2–30 字符，Subtitle 最多 30 字符。
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)：Promotional Text 最多 170 字符；Description/What's New 最多 4000 字符；Keywords 文档为 100 bytes；Review Notes 为 4000 bytes。首次版本无 What's New 栏。Support URL 必须提供真实联系方式。
- [Creating Your Product Page](https://developer.apple.com/app-store/product-page/)：Keywords 产品页指南另写 100 characters，使用英文逗号分隔、不在词条间加空格。此稿同时遵守字符与 UTF-8 字节限制。
- [Categories and Discoverability](https://developer.apple.com/app-store/categories/)：以实际核心用途选择类目；Utilities 为本稿推荐。
- [Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)：评级由内容问卷生成；数据导入并不自动等同其定义的广泛分发 UGC。

## 9. 填写状态与使用方式

- `metadata.json` 将本地化字段、共享建议和账号待定项分开。`null` 表示尚未确认，不是可提交的字符串。以实际账号记录为准，不覆盖既有 Apple ID / SKU。
- 用户指定的 support/marketing 与 privacy URL 已于 2026-09-19 返回 HTTP 200。现有隐私正文仍为 2026-08-20 的简短说明，须将本轮审核后的政策发布后再提交；可访问性不代表内容已合格。`/linkscope/support` 已返回 HTTP 200 并提供 GitHub Issues 支持渠道；提交前确认产品入口仍能到达该渠道。审核联系人另行提供。
- 用户已确认本次发行 **Free / 免费**，尚需在 App Store Connect 保存该定价；审核联系人、版权主体、发行地区、DSA、协议与税银等仍需依据账号事实补齐。完整列表见 `metadata.json` 的 `accountPending`。
- 隐私审计已完成：App Privacy 候选为 **Data Not Collected / 未收集数据**、Tracking = No；加密候选为 Apple OS-only，`ITSAppUsesNonExemptEncryption = false`。这是待账号确认的草案，尚未保存或提交。证据与限制见 `privacy-and-encryption.md`；不声称“全部本地数据加密”。
- 首次商店版本不粘贴 What's New；已有版本更新时使用对应本地化文本。
- `script/check.sh` 已通过 53 项测试（含新增 2 项仪表盘回归）、Full/Lite Debug 构建与签名检查。最终本地 Release 归档 `build/AppStore/LinkScopeLite-2.0.0-9-final.xcarchive` 已成功构建；最终包验收范围以 `real-device-qa.md` 为准。Apple Development 本机签名不等于 App Store distribution 签名或上传通过。
- 蓝牙已实测为 Allowed。Debug 与最终 Release 中重复打开/关闭 Settings > Permissions 后，IOBluetooth 与 CoreBluetooth 均保持 Running；最终 Release 的 7 个公共数据源均为 Running。读取 Diagnostics 仍触发原生自动化 helper 崩溃，本轮主动采样及 RSSI 读数未验证，不能把权限与数据源状态通过扩大为完整诊断验收。
- 修改文本后运行 `python3 docs/app-store/2.0.0/validate_metadata.py`；Keywords 按 UTF-8 bytes、Review Notes 按 bytes 检查，其他文案按字符检查。

## 10. 长度核验

已按实际粘贴文本统计 Unicode 字符和 UTF-8 字节；换行计入。

| 字段 | en-US 字符 | zh-Hans 字符 | 限制 |
| --- | ---: | ---: | --- |
| Name | 14 | 14 | 30 字符 |
| Subtitle | 28 | 13 | 30 字符 |
| Promotional Text | 156 | 51 | 170 字符 |
| Description | 2219 | 741 | 4000 字符 |
| Keywords | 79 | 34 | en-US 79 bytes；zh-Hans 90 bytes；均少于 100 |
| What's New | 627 | 214 | 4000 字符 |
| Review Notes | 2602 | — | 英语 2602 bytes，少于 4000 |

本表仅适用于当前文本；以 `validate_metadata.py` 的重新计算结果为准。
