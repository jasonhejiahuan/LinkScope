# LinkScope Lite 2.0.0（9）实机与发行验收

日期：2026-09-19。基线：`5a215341d3a5ea9afb068374e43777579c2f4a1c`，加本轮未提交的发行准备与仪表盘修复。分支整合已在 PR #3 合入 main；本轮发行准备改动未提交、未上传 App Store Connect。

## 实际环境和范围

- Apple Silicon 实体 Mac；macOS **27.2（26B5086k）**，Xcode **27.0（27A5252f）**，路径 `/Applications/Xcode-beta.app`。这是预发布系统环境，不能据此代表 macOS 15 或全部正式系统版本。
- 本地排查使用签名 Debug，并验证本地签名 Release。最终宣传素材采用用户补充的原生应用截图；截图页面静态证据与本轮自动化交互结果分别记录。
- Lite bundle ID：`cc.jasonstu.linkscope.lite`；最低系统设置 15.0。版本号由 project 统一定义，两 target 继承。
- 已连接输入配件可在列表识别。没有执行配对、断连、修改系统网络或配件固件操作。
- 本轮自动化只创建和编辑 `Desk Overview` 演示仪表盘；原有 `Full Layout Portability` 保留。最终选图排除含个人设备名称或 UUID/registry ID 的页面，保留选中原图的完整界面，未改写读数。

## 自动验证

| 检查 | 结果与边界 |
| --- | --- |
| `script/check.sh` | 53 项通过：Providers 2、Persistence 16、Core 35；Full/Lite Debug 构建、entitlements lint、strict codesign 通过 |
| 仪表盘新增回归 | 覆盖延迟提交标题、其他字段修改、调整宽度、复制，以及已删除/不透明/未来 schema 控件保护 |
| 文案验证 | `validate_metadata.py` 检查字段限制、关键词 UTF-8 字节、Review Notes 字节、Markdown/JSON 一致性 |
| Release 归档 | `build/AppStore/LinkScopeLite-2.0.0-9-final.xcarchive`；最终包验收见下节 |

本机 Conda 环境预设了不兼容的 linker 环境变量，首次构建曾报 `ld: unknown option: -Xlinker`。本轮仅对构建进程取消 `LD/LDPLUSPLUS/CC/CXX/AR/AS/NM/RANLIB/STRIP/LIBTOOL/OTOOL/INSTALL_NAME_TOOL/LIPO` 后使用 Xcode 工具链；没有改系统环境或项目 linker 配置。

## 实机交互证据

| 场景 | 实际结果 |
| --- | --- |
| 启动 | Debug 和本地 Release 均启动并呈现原生界面；权限页可访问 |
| 数据源 | 授权前蓝牙数据源明确显示尚未请求；最终 Debug/Release 的 7 个公开数据源均显示运行 |
| 蓝牙状态回退修复 | 重复 start 原先先发送 Starting、再跳过已启动实例，导致界面停在启动中。改为通过 MainActor 首次启动检查后再发送 Starting；Debug 与最终 Release 各两次打开/关闭权限页后，IOBluetooth/CoreBluetooth 持续 Running |
| 仪表盘编辑 | 创建演示仪表盘、添加 Provider Health、选择 Core Audio/CoreHID、移动与调整宽度、复制及撤销成功 |
| 实测缺陷与修复 | 原先标题延迟提交可用旧控件快照覆盖最新宽度。改为按 ID 合并单字段编辑；实机重复“输入标题→加宽三次→提交→复制”，原控件与副本均保留 6 列 |
| 持久化 | 正常退出 Debug 后启动 Release，标题、两个控件与 6 列布局恢复；撤销复制后保持两个控件 |
| 布局可读性 | 将仪表盘列表最小宽度由 130 改为 190，inspector 由 180 改为 240，避免英文标题逐字换行与 Source 控件挤压；最终截图验证实际效果 |
| 双语 | 设置中 English / 简体中文切换生效；权限说明与政策链接均可见 |
| 截图素材 | 用户提供 12 张原生 PNG，逐张查看后选定 4 个场景 × 2 种语言共 8 张；主窗口 2798×1664，权限窗口 1464×1280。选图和排除范围见下节，替代早期 computer-use JPEG 素材 |
| 历史诊断页面 | 用户提供的中英文 Diagnostics 原生截图均显示历史会话 Demo2：2026-08-19、Completed、27 条 RSSI 记录。这验证了截图中的页面内容与历史记录可见，不代表本轮新建、采样、停止或导出流程通过 |
| 隐私入口 | General 的 Privacy Policy 链接实际打开用户指定的公网隐私页面；两个用户网址 HTTP 200 |
| 存储设置 | 显示版本 2.0.0（9），默认 Unlimited；未执行删除历史 |
| 蓝牙授权 | 用户已明确同意。工具不能代操作系统权限窗口；后续实际观察到权限页“已允许”，CoreBluetooth 运行。权限授予通过，主动采样尚未通过 |
| 配件详情 / Diagnostics 自动化 | 自动化读取这些界面触发 computer-use helper 崩溃，无法完成本轮交互验收；不将该结果归因于应用崩溃。后续用户截图补充页面静态证据，不覆盖这项交互测试限制 |

## 用户提供的原生截图与宣传选图

用户提供了时间标记从 **17.38.29 至 17.42.44** 的 12 张原生 PNG。以下 8 张用于最终宣传构图；表中的时间标记用于对应用户原始文件，不是本轮自动化操作时间。

| 导出顺序 / 场景 | 简体中文原图 | 英文原图 | 原图像素 |
| --- | --- | --- | --- |
| 01 · 数据源 / Providers | 17.39.06 | 17.40.53 | 2798×1664 |
| 02 · 仪表盘 / Dashboard | 17.39.03 | 17.40.49 | 2798×1664 |
| 03 · 诊断 / Diagnostics | 17.39.13 | 17.41.00 | 2798×1664 |
| 04 · 权限 / Permissions | 17.38.29 | 17.42.21 | 1464×1280 |

两张时间线截图含个人设备名称、两张配件详情截图含 UUID/registry ID，均排除在宣传材料之外。选中的截图以完整原始字节嵌入构图，保留整个窗口、等比适配且不放大，不裁剪、不替换文字、不重画图表或修改 UI。输出采用 **2880×1800、8-bit RGB、无 alpha PNG**；原图与输出的 SHA-256、源像素和输出检查以 `Design/AppStore/2.0.0/exports/manifest.json` 为准。导出后的 8 张图片已逐张检查标题、界面对应、可读性及个人标识；标题无裁切，未发现私人设备名称或唯一 ID。仪表盘右侧组件保留原应用滚动视口的截断状态，没有后期拼接。

Diagnostics 图片中的 **Demo2 是 2026-08-19 已完成的真实历史会话，包含 27 条 RSSI 记录**。可以据此展示诊断历史界面，不能将这些旧记录写成 2026-09-19 本轮新建会话的采样结果，也不能据一张静态图判定开始/停止、采样间隔、会话对比或 CSV 导出的运行测试已通过。

## 工具故障证据

用户重启 computer-use MCP 后已重试。简单页面恢复；详情/Diagnostics 仍出现 `Sky Computer Use native pipe closed before response`。本地两份 SkyComputerUseService crash report 均为 `EXC_BREAKPOINT/SIGTRAP`，栈含 `_assertionFailure → Array.remove(at:)` 和 helper 的遍历帧。没有发现对应 LinkScope crash report；两秒进程采样显示 AppKit/CoreFoundation 正常等待事件。这证明 helper 发生崩溃，**并不证明被阻断的应用功能通过验收**。

原始 crash report、进程采样和构建日志留在本机临时位置，未放进发行材料；可能包含个人路径和诊断标识。

另外，IOBluetooth 状态排查的三秒主线程采样正常等待事件，没有框架或锁等待栈。状态回退根因由源码与修复后双配置实测共同支持；统一日志查询没有完成，不能用空日志声称已排除全部沙盒问题。

## 最终 Release 包检查

后续上传阻塞：用户报告 Apple 不接受构建所用 Xcode。复核此归档确为旧 Beta `27A5252f`；下列本地验证结果不等于工具链接受验证。必须以正式 Xcode 27（27A266a）重新归档替代该包，详见 [修复说明](xcode-submission-blocker.md)。

最终归档仍为 **Apple Development 本机签名**，不是已通过 App Store 分发签名、上传处理或审核的包。核对项目包括版本、Universal 2 架构、严格签名、sandbox 权限、Required Reason manifest、加密标志；最终核验通过：2.0.0（9）、arm64 + x86_64、strict codesign 有效、sandbox/Bluetooth/user-selected read-write 权限正确，包内包含 UserDefaults CA92.1 manifest，`ITSAppUsesNonExemptEncryption` 为 Boolean false。

## 提交前仍需完成

1. 系统蓝牙授权已完成，用户截图也显示既有会话的 RSSI 历史记录；仍需在本轮新建会话中验证当前连接设备的可用 RSSI、主动采样、停止、间隔/时长、诊断对比与 CSV 导出。无读数应按实际不可用原因验收。
2. 在可正常访问详情/Diagnostics 的测试环境完成页面、JSON 导入导出、快照、规则通知和 Shortcuts 的端到端检查。本轮源码与单元测试不能替代这些交互验收。
3. 在最低支持系统及正式系统版本、Intel Mac（或合适测试设备）验证；补断连/重连、睡眠唤醒和较长会话测试。本轮没有覆盖这些组合。
4. 发布已审阅的新隐私正文，更新网站待发布状态；在 App Store Connect 设置用户已确认的 **Free / 免费**，并填写真实审核联系人、地区、账号合规与协议等 `accountPending` 项。
5. 用正式分发流程核对 App ID、profile、可用 build 号并导出/上传，完成 App Store Connect processing 和最终 App Privacy/加密声明确认，再提交审核。

不得用这份报告宣传“全面通过实机测试”“所有设备均支持 RSSI”或“已经可以直接上架”。
