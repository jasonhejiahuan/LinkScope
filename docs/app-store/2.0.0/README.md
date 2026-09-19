# LinkScope Lite 2.0.0 · App Store 发行材料

本目录面向 Mac App Store 的 **LinkScope Lite 2.0.0（9）**，准备英语和简体中文材料。资料准备不代表已经上传、提交审核或具备 App Store 发行签名。

**工具链阻塞更新：** 用户报告上传因 Xcode 版本被拒；旧 `final.xcarchive` 使用 27A5252f Beta，不能继续作为提交包。当前两套 Xcode 安装也均为 Beta，须安装 Xcode 27 正式版（27A266a）后重新归档。证据与命令见 [Xcode 上传拒绝处理](xcode-submission-blocker.md)。

| 文件 | 用途 |
| --- | --- |
| [metadata.md](metadata.md) | 可复制的双语商店字段、英文 Review Notes、宣传短句及功能证据 |
| [metadata.json](metadata.json) | 同一文案的结构化版本；`locales`、`shared` 与 `accountPending` 分别保存本地化字段、共享信息和待确认账号信息 |
| [validate_metadata.py](validate_metadata.py) | 检查字符/UTF-8 字节上限、JSON 与 Markdown 文案一致性、URL 格式 |
| [apple-requirements.md](apple-requirements.md) | Apple 官方字段、截图、隐私、加密及账号要求，附原始来源 |
| [privacy-and-encryption.md](privacy-and-encryption.md) | 源码隐私审计、App Privacy 填写建议及加密声明依据 |
| [privacy-policy.en.md](privacy-policy.en.md) / [privacy-policy.zh-Hans.md](privacy-policy.zh-Hans.md) | 待发布到用户指定网址的双语隐私政策 |
| [real-device-qa.md](real-device-qa.md) | 本轮实际测试证据、Release 归档检查和未完成的验收项 |
| [submission-runbook.md](submission-runbook.md) | 从验收、签名上传、填写字段到提交及手动发布的操作顺序 |
| [截图制作目录](../../../Design/AppStore/2.0.0) | 视觉方案、真实界面素材和最终截图；验收状态以该目录说明为准 |

从仓库根目录检查文案：

```sh
python3 docs/app-store/2.0.0/validate_metadata.py
```

修改粘贴文本时同步更新 Markdown 与 JSON。Keywords 以 UTF-8 **100 bytes**、Review Notes 以 **4000 bytes** 检查；其他文案按 Apple 的字符上限检查。`null` 为待确认值，不是应粘贴到 App Store Connect 的文字。首次商店版本省略 What's New，已有版本更新才填写。

`script/check.sh` 已通过 **53 项测试**（包括新增的 2 项仪表盘回归），以及 Full/Lite Debug 构建与签名检查。最终本地 Release 归档 `build/AppStore/LinkScopeLite-2.0.0-9-final.xcarchive` 已成功构建，包验收范围见 `real-device-qa.md`。本机 Release 使用 Apple Development 签名，App Store distribution 签名及上传处理尚未完成。

蓝牙已实测为 Allowed；Debug 与最终 Release 中重复打开/关闭 Settings > Permissions 后，IOBluetooth 与 CoreBluetooth 保持 Running，最终 Release 的 7 个公共数据源均为 Running。自动化读取 Diagnostics 曾触发原生 helper 崩溃。用户随后提供的原生截图展示了真实历史会话 **Demo2（2026-08-19，Completed，27 条 RSSI 记录）**，补充了该页面与历史读数的静态证据；这不等于本轮新建诊断、持续采样、停止或导出的端到端测试通过。完整已测与未测范围以 QA 报告为准。

最终截图方案为 **4 个场景 × 2 种语言，共 8 张**：数据源、仪表盘、诊断、权限。素材来自用户提供的 12 张原生 PNG 中选定的 8 张，主窗口原图为 **2798×1664**，权限窗口为 **1464×1280**，替代早期 computer-use JPEG 素材。包含个人设备名称的两张时间线及含 UUID/registry ID 的两张详情截图不进入宣传材料。选中原图完整字节原样嵌入、等比适配且不放大，不裁剪或重画界面；最终输出规格为 **2880×1800、8-bit RGB、无 alpha PNG**，8 张输出已逐张完成视觉检查，尺寸、通道与 SHA-256 以截图目录的 manifest 和说明为准。

用户指定的支持/产品地址为 <https://apps.jasonstu.cc/linkscope>，隐私地址为 <https://apps.jasonstu.cc/linkscope/privacy>，均已返回 HTTP 200。支持子页 `/linkscope/support` 提供 GitHub Issues 渠道。当前公网隐私正文仍为 2026-08-20 的简短说明，需要发布审核后的新政策。

隐私审计候选答案为 **Data Not Collected / 未收集数据**，加密为 Apple OS-only、`ITSAppUsesNonExemptEncryption = false`。这些是有源码依据的填写草案，尚未在 App Store Connect 保存或提交；最终包和实际运营行为需保持一致。

用户已明确确认本次发行 **Free / 免费**；该定价尚未在 App Store Connect 保存。提交前还需补齐真实审核联系人，核对既有 App 记录、版权主体、发行地区、DSA、协议及适用税银信息，完成受限测试项，并在 ASC 上传后复核截图展示。完整待定字段保存在 `metadata.json` 的 `accountPending`；不要用推测值替代账号事实。
