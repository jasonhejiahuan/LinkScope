# LinkScope Lite 2.0.0 — 隐私与加密申报底稿

编制日期：2026-09-19。开发者：**JASON Studio**。适用产品：Mac App Store 的 **LinkScope Lite**，版本 **2.0.0（9）**。源码基线为 `5a21534`，本底稿包含本次未提交的隐私清单、应用内政策链接和加密标志准备修改。下列路径和行号以本次工作区为准。

这是可用于填写 App Store Connect 的候选答案与证据，不代表已在账号中保存、已通过 App Review、已完成政府申报或已部署新版网站政策。隐私政策成稿见 [English](privacy-policy.en.md) 和 [简体中文](privacy-policy.zh-Hans.md)。

## 1. App Store Connect 隐私答案

| 字段或问题 | 本版本候选答案 | 依据及限制 |
| --- | --- | --- |
| Privacy Policy URL | `https://apps.jasonstu.cc/linkscope/privacy` | 提交前应发布与本版本一致的英中政策，并在无登录状态检查。 |
| Privacy Choices URL | 可留空；若同一政策页清楚展示数据管理方式，也可使用上述 URL | 可选字段；不编造账号管理或完整数据重置功能。 |
| Do you or your third-party partners collect data from this app? | **No / 否** | 本地源码没有开发者或第三方上传通道、分析 SDK 或云同步。最终分发构建及实际运营做法需保持一致。 |
| 隐私标签结果 | **Data Not Collected / 未收集数据** | 本地读取、保存及用户自行保存导出文件，不自动构成开发者的离机收集。 |
| Tracking | **No / 否**；清单 `NSPrivacyTracking = false` | 无跨应用广告匹配、广告 SDK 或跟踪域名。 |
| Data Linked to You / Data Not Linked to You | 无数据类型条目 | 不为纯本地设备标识符、诊断参数或自定义文字创建离机收集条目。 |
| 数据用途和与用户关联问题 | 在“未收集数据”路径下不适用 | 若实际增加上传或分析，需逐类重新回答，不能沿用本底稿。 |
| App Tracking Transparency | 无需为当前实现增加跟踪授权流程 | 当前源码没有跟踪行为，也没有广告标识符使用。 |

Apple 的隐私标签以开发者或合作方可访问的离机数据为核心，明确排除仅在设备上处理的数据；开发者仍应核实自己从 Apple 服务获得并使用的数据。[Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

本候选覆盖所有标签类别：联系方式、健康与健身、财务、位置、敏感信息、联系人、用户内容、浏览/搜索历史、标识符、购买、使用数据、诊断、环境、身体及其他数据均没有已发现的应用内离机收集路径。设备名称、蓝牙地址、硬件序列号和原始参数确实可能在本地处理；“未收集数据”不能被写成“应用不读取设备标识”。

官网访问和用户主动联系支持是单独的数据处理场景。不得把“应用无遥测”扩大为“网站无 IP 日志”。当前应用没有内嵌网页或支持提交表单；未来加入此类功能时，应按实际数据流重新评估标签。不要未经检查就援引“可选支持反馈免披露”。

## 2. 源码数据流与权限证据

除非另行标明，下表文件在 `Packages/LinkScopeKit/Sources/` 下。

| 范围 | 当前行为 | 源码证据 |
| --- | --- | --- |
| 实际 provider 入口 | 仅实例化 CoreHID、IOBluetooth、CoreBluetooth、CoreAudio、GameController、IORegistry、SystemEvent 七个公共 API provider | `LinkScopeProviders/PublicProviderFactory.swift:4–14`；`LinkScopeUI/LinkScopeApplicationModel.swift:65–72` |
| Bluetooth | 配对设备、名称、地址、连接状态、分类、可用 RSSI；诊断可按用户操作采样 | `LinkScopeProviders/IOBluetoothProvider.swift:31–75,90–130,173–269` |
| CoreBluetooth | 权限与控制器状态；未发现通用扫描或主动连接路径 | `LinkScopeProviders/CoreBluetoothProvider.swift:28–89,106–163` |
| HID | 产品、制造商、序列号、传输方式、设备标识与生命周期；当前未读取按键或输入报告 | `LinkScopeProviders/CoreHIDProvider.swift:29–60,109–204` |
| Audio / controller | 音频端点与路由、控制器连接及可用电池信息；无音频录制或游戏操作输入采集路径 | `LinkScopeProviders/CoreAudioProvider.swift:115–210`；`LinkScopeProviders/GameControllerProvider.swift:26–50,62–103` |
| IORegistry / system | 公共 IOKit 中限定属性、Mac 名称、OS、电源/温度及睡眠唤醒 | `LinkScopeProviders/IORegistryProvider.swift:38–132`；`LinkScopeProviders/SystemEventProvider.swift:26–106` |
| 用户内容 | 仪表盘、快照、诊断会话、规则、导入文件和偏好设置 | `LinkScopeCore/FutureModels.swift:32–118`；`LinkScopeUI/LinkScopeApplicationModel.swift:374–380,758–837` |
| 本地通知 / Shortcuts | 系统授权后的本地规则通知；用户触发的 App Intents 可以返回会话状态 | `LinkScopeUI/LinkScopeApplicationModel.swift:732–755`；`LinkScopeUI/LinkScopeAppIntents.swift:15–92` |
| Lite 权限 | 沙盒、蓝牙、用户选定文件读写、应用自己的 Keychain access group | `Apps/LinkScopeLite/LinkScopeLite.entitlements:5–14`（仓库根目录） |
| 外部依赖 | Swift Package 无外部依赖，使用 Apple 框架和系统 SQLite；Xcode 项目只引用本地 package | `Packages/LinkScopeKit/Package.swift:17–61`；`LinkScope.xcodeproj/project.pbxproj:190–192,438–463`（仓库根目录） |

本次重查 `Apps`、`Packages/LinkScopeKit/Sources` 和 `Package.swift`，未发现 `URLSession`、`URLRequest`、`NWConnection`、`NWListener`、CFNetwork、NSURLConnection、CloudKit、WebView、常见分析/崩溃 SDK 或外部加密库调用。这是源码证据，不是对所有操作系统网络活动的流量证明。Lite entitlement 没有网络 client/server、iCloud、麦克风、通讯录、位置或全盘访问能力。本轮本地 Release 归档的签名权限已核实，见第 8 节；最终 App Store 分发签名包仍需复查。

## 3. 本地加密算法清单

| 项目 | 实现与目的 | 源码证据 |
| --- | --- | --- |
| 随机主密钥 | `SecRandomCopyBytes` 生成 32 字节（256 位）随机值 | `LinkScopePersistence/KeyMaterial.swift:306–312` |
| 密钥派生 | Apple CryptoKit `HKDF<SHA256>`，固定 salt、独立 context，分别派生 32 字节 payload key 与 identity HMAC key | `LinkScopePersistence/KeyMaterial.swift:41–57` |
| 载荷加密 | Apple CryptoKit `AES.GCM.seal/open`，256 位派生密钥；存储 combined sealed box；未自定义密码算法或 nonce 构造 | `LinkScopePersistence/PayloadCipher.swift:1–15`；`LinkScopePersistence/KeyMaterial.swift:46–50` |
| 本地标识匹配 | Apple CryptoKit `HMAC<SHA256>` 对本地 provider/kind/raw identifier 组合生成带密钥摘要 | `LinkScopePersistence/KeyMaterial.swift:60–61`；`LinkScopePersistence/ObservationDatabase.swift:145–179`；`LinkScopeCore/Identity.swift:97–99` |
| 主密钥保存 | macOS Data Protection Keychain；`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`；无 synchronizable 标志 | `LinkScopePersistence/KeyMaterial.swift:114–151` |
| 授权行为 | 普通启动非交互读取；用户主动配置时生成/迁移自己的主密钥；未配置时使用内存 sink | `LinkScopePersistence/KeyMaterial.swift:155–164,247–303`；`LinkScopeUI/LinkScopeApplicationModel.swift:65–72,840–880` |

### 必须保留的安全边界

数据库是普通 SQLite/WAL，序列化 payload 在写入前加密；它不是 SQLCipher 或整库加密。观测值、原始设备标识、设备显示名称、仪表盘、快照、诊断及规则等 payload 受到保护，但索引元数据、时间戳、状态、参数路径、本地关系标识、部分会话字段和快照名称存在明文列；偏好设置也不由应用加密。证据：`LinkScopePersistence/ObservationDatabase.swift:106–138,335–347,377–398,709–715,868–956,987–1006`。仪表盘自定义名称保存在加密 payload 内，旧明文名称列被清空，见 `:392–395,1012–1015`。

不得宣传“全部数据均已加密”“端到端加密”“零知识”“每次必须生物认证”“卸载即彻底抹除”。HMAC 是本地带密钥摘要匹配，不是向服务器发送的跟踪标识，也不是对原始值进行可逆加密。

## 4. 加密申报候选答案

| App Store Connect 问题含义 | 候选答案 |
| --- | --- |
| 应用是否使用、访问、包含或集成加密？ | **是 / Yes**。CryptoKit、Security 和 Keychain 提供本地加密。 |
| 加密是否仅限 Apple 操作系统提供的实现？ | **是 / Yes**。当前源码和依赖没有额外加密实现。 |
| 是否含专有、未获国际标准机构认可的加密算法？ | **否 / No**。应用的 salt/context 是标准 API 的参数，不是自定义算法。 |
| 是否在 Apple OS 加密之外自行实现或额外包含标准算法？ | **否 / No**。AES/HKDF/HMAC 调用均来自系统 CryptoKit。 |
| 若界面只列“专有算法”和“OS 之外或之外另加的标准算法” | 与当前事实相符的是 **None of the algorithms mentioned above**；必须先核对实时题目全文。 |
| 使用目的 | 保护本地配件观测与配置 payload，并进行本地标识匹配。产品不提供 VPN、加密通信或通用加密服务。 |
| `ITSAppUsesNonExemptEncryption` | **false / NO**：仅使用豁免加密，不等于“完全不使用加密”。Lite Debug/Release 已设 build setting；本轮本地 Release 归档的生成 Info.plist 已确认 Boolean `false`。 |
| `ITSEncryptionExportComplianceCode` | 留空/不添加；当前路线没有待填写的 Apple 审批码。 |
| App Store Connect 加密文档上传 | 按 Apple 当前 OS-only 表格，无需上传。 |
| France / CCATS | 当前 OS-only 路线不触发该表格中的法国声明或 CCATS 上传项；分发国家和政府侧义务仍需账号持有人核实。 |

Apple 的当前表格将仅使用 OS 内置加密的应用列为无需在 App Store Connect 上传加密文档；OS 外的标准算法和专有算法属于其他分支。[Export compliance documentation for encryption](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/)

Apple 允许仅使用豁免加密的应用将 `ITSAppUsesNonExemptEncryption` 设为 `NO`。本次配置位于 `LinkScope.xcodeproj/project.pbxproj:369,395`，本轮本地 Release 归档的生成 Info.plist 已确认该值；重建或使用 App Store 分发签名导出后应再次检查。[ITSAppUsesNonExemptEncryption](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)

App Store Connect 文档豁免不代表已经取得政府出口分类或免除所有政府报告义务；Apple 特别提示部分豁免加密可能仍涉及年度自分类报告。账号持有人应根据实际分发区域及适用规则确认，不能把本文件视为法律裁定。[Complying with Encryption Export Regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)；[Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)

### 可粘贴的加密说明（English）

> LinkScope Lite uses Apple CryptoKit AES-256-GCM to protect locally stored serialized observation and configuration payloads. Security.framework generates a 256-bit master key stored in the app's macOS Keychain access group. CryptoKit HKDF-SHA256 derives separate payload and HMAC-SHA256 lookup keys. All cryptographic implementations are provided by the Apple operating system. The app contains no proprietary or third-party cryptographic implementation and does not offer encrypted communications or a general-purpose encryption service. Query metadata and user-initiated JSON/CSV exports are not encrypted by LinkScope.

### 对应中文说明

> LinkScope Lite 使用 Apple CryptoKit 的 AES-256-GCM 保护本地保存的序列化观测与配置数据载荷。Security.framework 生成 256 位主密钥，并存放于应用自己的 macOS 钥匙串访问组。CryptoKit HKDF-SHA256 派生独立的载荷加密密钥与 HMAC-SHA256 查询密钥。所有密码实现均由 Apple 操作系统提供。应用没有专有或第三方密码实现，也不提供加密通信或通用加密服务。查询元数据以及用户主动导出的 JSON/CSV 不由 LinkScope 加密。

## 5. Privacy manifest 与应用内政策链接

当前 `Apps/LinkScopeLite/PrivacyInfo.xcprivacy:5–21` 包含：

```text
NSPrivacyTracking: false
NSPrivacyTrackingDomains: []
NSPrivacyCollectedDataTypes: []
NSPrivacyAccessedAPIType: NSPrivacyAccessedAPICategoryUserDefaults
NSPrivacyAccessedAPITypeReasons: [CA92.1]
```

`CA92.1` 对应应用自身偏好设置的读写。实际调用为 `LinkScopeUI/Localization.swift:35` 的 `UserDefaults.standard`、`LinkScopeUI/LinkScopeRootView.swift:16–19` 和 `LinkScopeUI/LinkScopeSettingsView.swift:7–10` 的 `@AppStorage`。未发现 App Group 或 MDM 配置用途，不应为当前实现改选这些理由。[Required-reason API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)；[TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)

没有发现直接使用文件时间戳、可用磁盘空间、系统启动时间或当前键盘列表相关 required-reason API 的业务代码。此结论不能代替最终归档的 privacy report 或 Apple 上传校验。

应用内入口已写入 `LinkScopeUI/LinkScopeSettingsView.swift:39–42`：Settings > General > Privacy Policy / 设置 > 通用 > 隐私政策。Apple 要求 App Store Connect 和应用内都有易访问的隐私政策链接，并解释处理用途、保留/删除及撤销方式。[App Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy)

## 6. 导出、删除与营销用语核对

| 能力 | 可发布的准确说法 | 不应作出的承诺 | 证据 |
| --- | --- | --- | --- |
| 主快照导出 | 用户选定位置的明文 JSON，可含完整原始参数和标识 | 默认脱敏、加密备份、只含匿名统计 | `LinkScopeUI/LinkScopeApplicationModel.swift:777–798`；`LinkScopePersistence/ArchiveCodec.swift:15–20`；`LinkScopeUI/LinkScopeRootView.swift:199–223` |
| 诊断导出 | 明文 CSV，含当前筛选的时间、设备、provider、参数、可用性、值 | 无设备信息或自动安全清理 | `LinkScopeUI/DiagnosticsView.swift:450–470,550–559,739–767` |
| 仪表盘导出 | 明文 JSON，包含配置、名称、来源引用和保留的扩展字段 | 永远不含个人内容 | `LinkScopePersistence/DashboardCodec.swift:10–26`；`LinkScopeUI/DashboardView.swift:100–110,418–432` |
| 保留期限 | 默认无限；选 30/90/365 天后需预览并确认删除较早 observations | 定时自动清理、到期删除全部历史 | `LinkScopeUI/LinkScopeSettingsView.swift:10,56–71,88–101`；`LinkScopeUI/LinkScopeApplicationModel.swift:312–338` |
| 删除范围 | SQL 只删除 observations 表中早于 cutoff 的记录 | 删除所有快照副本、身份/时间线/诊断、规则、密钥、导出 | `LinkScopePersistence/ObservationDatabase.swift:652–669`；快照嵌入内容见 `LinkScopeCore/FutureModels.swift:32–64` |
| 完整重置 | 当前版本没有删除全部本地数据和主密钥的控件 | “一键抹除”“卸载即删除一切” | 当前 UI 与 persistence 删除入口审计 |
| 权限 | Bluetooth 与通知权限可在 macOS 撤销；未配置存储时使用内存 | 撤销权限会删除旧数据或删除主密钥 | `LinkScopeUI/PermissionManagementView.swift:46–83,130–141`；`LinkScopeUI/LinkScopeApplicationModel.swift:65–72` |

推荐宣传短句：**“在 Mac 上处理配件数据。敏感本地载荷加密保存，导出由你掌控。”** / **“Accessory insights processed on your Mac. Sensitive local payloads are encrypted. You choose what to export.”** 正文和政策中应保留明文导出及删除范围说明。

## 7. 账号持有人最终核对

以下是待核实事项，不能由源码自动代答：

1. **产品与版本**：选择 Lite 的正确 App Store Connect 记录和 bundle ID；归档应为 Release，版本 2.0.0、build 9 或最终批准的递增 build。不要上传 Debug、Full 或含私人诊断资源的构建。
2. **最终包一致性**：本轮本地 Release 归档已通过第 8 节列出的静态检查。最终重建及 App Store 分发导出后仍应复查签名/沙盒 entitlement、依赖、bundle 隐私清单、privacy report、生成 Info.plist 的 `ITSAppUsesNonExemptEncryption = false`，并确认政策入口能真实打开正确页面。
3. **开发者实际做法**：确认没有未纳入源码的 SDK、后台数据入口或开发者自行获取并使用的 Apple 服务数据改变标签；仅有源码搜索不能决定全部运营数据实践。
4. **网页与联系渠道**：在隐私 URL 发布两种语言的成稿。元数据沿用用户指定的 Support URL `https://apps.jasonstu.cc/linkscope`；政策联系链接指向 `https://apps.jasonstu.cc/linkscope/support` 支持页，两者用途一致。当前支持入口提供 GitHub Issues，不应要求用户在公开 issue 中附上私人数据。公开邮箱仍待确认，不在本文件中杜撰。支持通信用途、保留方式、删除请求处理和网站基础设施说明应与实际操作一致；若网站独立收集分析数据，应补充对应网站告知。
5. **支持请求保密**：如果接受用户提供的诊断附件，确认收件权限与删除流程；收到导出文件后即产生独立的数据处理责任。不要要求用户公开上传数据库或设备标识。
6. **出口合规**：确认分发地区及最终二进制的算法范围；按实时问题填写 OS-only 分支。出现与底稿不一致的题目或上传要求时先核对事实，不填虚构审批编号。政府分类/年度报告需要另行判断。
7. **账号操作**：由有权角色检查并保存真实答案。本次没有写入 App Store Connect，没有上传加密材料或递交审核。Apple 当前文档列出的加密配置角色为 Account Holder、Admin 或 App Manager。[Determine and upload app encryption documentation](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/)
8. **不可用能力**：政策不承诺完整本地重置。若之后实现全部数据删除、上传、云同步、支持提交或新 provider，重新测试并更新此底稿及公开政策。

## 8. 本轮本地 Release 归档验收证据

2026-09-19 对 `build/AppStore/LinkScopeLite-2.0.0-9-final.xcarchive` 中的 `Products/Applications/LinkScope Lite.app` 进行了实际文件与签名检查：

| 检查 | 已观察结果 |
| --- | --- |
| 生成 Info.plist | Bundle ID `cc.jasonstu.linkscope.lite`；版本 `2.0.0`；build `9`；`ITSAppUsesNonExemptEncryption` 为 Boolean `false`。 |
| 已打包隐私清单 | `Contents/Resources/PrivacyInfo.xcprivacy` 存在；tracking 为 false，tracking domains 和 collected data types 为空；UserDefaults 理由为 `CA92.1`。 |
| 可执行文件架构 | `lipo -archs` 返回 `x86_64 arm64`，为 Universal 2。这不代表已在 Intel 实机运行。 |
| 严格签名检查 | `codesign --verify --deep --strict` 通过，报告 valid on disk 且满足 designated requirement。 |
| 签名类别 | **Apple Development**。这是本地 Release 配置归档，不是 App Store 分发签名导出或已上传构建。 |
| 实际签名权限 | App Sandbox、Bluetooth、用户选择文件读写均为 true，使用一个应用 Keychain group；没有 network client/server entitlement。 |
| 与元数据核对 | 版本、build、bundle ID、英中政策 URL、无需账号及明文导出含设备信息的边界一致；`metadata.json` 的 App Privacy 正式申报值仍为待账号确认。 |

归档中的清单不等于已经生成 Xcode privacy report，也不代表通过 App Store 上传校验、App Review 或政府出口审核。最终若在同一路径重建，应对新生成包重复以上检查，并单独保留实机 UI 测试记录。本次没有部署新的双语政策、写入 App Store Connect、导出商店分发包或提交审核。

本文件与双语政策用于准备发行材料；本地归档检查、实机行为、官网部署、最终账号申报及 App Review 结果分别记录，不能互相替代。
