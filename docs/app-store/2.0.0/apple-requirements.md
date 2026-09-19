# LinkScope Lite · Mac App Store 提交规范核验

核验日期：2026-09-19。范围：Apple 官方 App Store Connect / Developer 文档及必要 BIS 一手法规。此文件是资料准备清单，没有访问开发者账号、填写或提交表单，也没有确定账号主体、交易者身份、地区或最终法律分类。用户已确认本次发行免费，但尚未在 App Store Connect 保存定价。产品事实、真实功能与最终隐私选择由代码/实机审计交叉验证。

## 1. 可填文案与基础记录

| 字段 | 约束/填法 | LinkScope Lite 准备动作 |
|---|---|---|
| Platform | macOS | 使用 Lite 目标对应构建 |
| Name | 2–30 字符，可本地化 | `LinkScope Lite`；账号内核验名称可用性 |
| Subtitle | ≤30 字符，可本地化 | 明确无线配件观察功能，避免无法证明的超绝词 |
| Primary Language | 默认商店元数据语言 | 从实际英文/中文文案中决定 |
| Bundle ID | 与提交构建完全相符；上传后不可更改 | 读取 Release 的生成 Info.plist |
| SKU | 内部标识；创建后不可更改 | 新记录可拟 `linkscope-lite-macos`，先确认既有记录 |
| Apple ID | Apple 自动生成 | 账号依赖，不能编造 |
| Primary / Secondary Category | 主分类必须与 macOS 工程分类相符 | 建议 Utilities，最终对照 `LSApplicationCategoryType`；第二分类可空 |
| Content Rights | 按实际第三方内容及权利回答 | 品牌名/图标/服务内容需逐项判断，不能把“调用系统框架”机械视作第三方内容 |
| License Agreement | 可使用 Apple 标准 EULA | 若没有特别合同需要，保留标准 EULA |
| Made for Kids | 非普通年龄分级的同义项 | 工具类常规不选择 |

来源：[App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)、[Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)。

| 版本级字段 | 上限/性质 |
|---|---|
| Promotional Text | ≤170 字符；可独立更新 |
| Description | ≤4000 字符；纯文本，可换行，不能依赖 HTML/Markdown 渲染 |
| Keywords | 官方字段参考为 ≤100 bytes；用逗号分隔，成品按 UTF-8 字节数检查 |
| Support URL | 必填；必须有真实可用的联系方法 |
| Marketing URL | 可选；介绍产品的完整 URL |
| Version / Build | 与选择的上传构建匹配，版本来自项目共享配置 |
| Copyright | `2026 JASON Studio` 为拟定值；须确认其为实际权利人，无须手填 © |
| What’s New | 后续版本必填，≤4000 字符；首个商店版本无此字段 |
| Release Option | 手动、审核后自动、或不早于指定日期自动 |

来源：[Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)。

**官方文档存在一个实际差异**：字段参考写 Keywords 100 bytes，而营销指南写 100 characters。为避免中文输入超限，产出稿件以 UTF-8 ≤100 bytes 为保守验收值；最终以 ASC 校验为准。不要重复 app/company 名、竞品名和无关词；宣传文本不用于堆关键词。来源：[Creating your product page](https://developer.apple.com/app-store/product-page/)。

用户已指定：Support / Marketing URL 为 `https://apps.jasonstu.cc/linkscope`；Privacy Policy URL 为 `https://apps.jasonstu.cc/linkscope/privacy`。2026-09-19 两个地址均返回 HTTP 200；现有隐私正文仍为 2026-08-20 的简短说明，需要发布本轮审核后的完整政策。`/linkscope/support` 已返回 HTTP 200 并提供 GitHub Issues 支持渠道。提交前再次核验入口、适用版本及保留/删除说明。网页可访问不等于正文已经符合提交要求。

元数据中文/英文是两套本地化，与二进制中实际支持的界面语言分别管理；添加一个商店语言不会自动让 app 支持该语言。来源：[Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information)。

## 2. App Review 信息

联系人姓名、电子邮件、带 `+国家代码` 的电话号码属于账号/人员依赖字段，不应从 Git 作者信息推断。Review Notes 最多 **4000 bytes**，建议用简练英文。无登录功能时关闭 Sign-in required；有登录功能才提供不会过期的审核专用账号。来源：[App Review information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)。

针对本产品应准备的审核说明内容（为工作建议，须与实机结果一致）：

1. App 用于查看 macOS 公开的配件信息；明确 Lite 仅使用公开数据源，不提供任意附近 BLE 扫描，也不执行配对、断开或配件设置写入。
2. 说明首次启动、按需授权、刷新、详情、历史、仪表盘与导出的实际操作路径；不要加入产品不存在的扫描步骤。
3. 解释已保存历史、蓝牙访问与可选通知各自用途及拒绝后的行为；当前产品不提供定位功能。明确特定数据受系统版本、权限及硬件限制。
4. 是否需要真实蓝牙配件、可用哪些常见配件验证；给出没有配件时仍可检查的界面路径。
5. 无账号/订阅/广告等陈述仅在审计证实时写入。
6. 本地存储、清除记录方法、真实隐私政策 URL；不要提交含私人设备标识的日志。

可把精简测试说明、权限演示或设备依赖说明作为审核附件；它们与面向消费者的截图分开。来源：[App Store review attachments](https://developer.apple.com/documentation/appstoreconnectapi/app-store-review-attachments)、[App Review](https://developer.apple.com/app-store/review/)。

## 3. 隐私政策与 App Privacy 标签

隐私政策 URL 必填；Privacy Choices URL 可选。ASC 的声明要涵盖 app 自身和集成的第三方合作方；如果同一个记录有多个平台，要完整覆盖。若确认都不收集，选择 **No, we do not collect data from this app**。来源：[Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)。

Apple 的标签定义中，仅设备内处理不属于收集；发送离开设备并以可读形式保留超过服务请求所需时间，才属于其定义的收集。可读内容在服务器处理后立即丢弃与持久日志留存不同。Apple 自身采集的数据无需由开发者代声明，开发者从 Apple 服务取得并使用的数据则要判断。来源：[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)。

据此应逐项核对：配件名称/系统标识、蓝牙地址（若可见）、信号/电量、观察时间、连接状态历史、导出文件、故障日志、任何自动联网与第三方 SDK。**读到本地设备标识不自动等于 ASC 的“收集 Device ID”**；也不能仅因没有自建后端就保证“不收集”。最终取决于实际离机路径和留存。

隐私政策至少完整解释收集/处理的数据、用途、第三方共享、保留/删除与撤销同意方式；政策入口需在 app 内易于找到。提交资料及截图必须真实并使用虚构展示身份；Mac App Store 版须沙盒化并通过商店更新，不可要求 root 或安装额外功能代码。来源：[App Review Guidelines 5.1.1、2.3、2.4.5](https://developer.apple.com/app-store/review/guidelines/)。

`PrivacyInfo.xcprivacy` 是构建中的隐私清单，App Privacy 是商店披露，公开隐私政策是用户文档，三者须一致，不能互相替代。Required Reason APIs 还需按真正用途选择 Apple 批准的原因。来源：[Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)、[Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)。

## 4. 加密出口声明

Apple 的三个文档分支：

| 实际使用方式 | ASC 文档要求 |
|---|---|
| 加密完全由 Apple 操作系统提供 | 无需上传加密文档 |
| 系统以外提供的行业标准算法 | 法国发行时要求法国加密声明 |
| 未获国际标准机构认可的自有/非标准算法 | CCATS；法国发行时另需法国声明 |

来源：[Export compliance documentation for encryption](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption)。

`CryptoKit.AES.GCM` 是 Apple 框架提供的标准 AES-GCM。自己写的存储管理器调用该 API，不会因此变成“自己发明的加密算法”。普通 JSON 封装、密钥标识和文件格式也不自动构成非标准加密算法；但自制密码协议/额外算法必须单独审查。来源：[Apple CryptoKit](https://developer.apple.com/documentation/cryptokit)、[AES.GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm)。

**建议的声明决策（待全量源码、链接依赖与最终 Release 构建核验）**：

- 若仅调用 Apple CryptoKit、Security/Keychain、系统 TLS，并无其他密码实现：声明“使用加密，且加密限于 Apple 操作系统提供的功能”。
- 如果界面询问是否有专有/非标准算法，回答 No；若问是否有“除 Apple 操作系统加密以外、或额外的标准算法实现”，回答 No。
- 如界面提供与这两类相对应的算法多选题，应选择“None of the algorithms mentioned above”，其意义是“不属于所列的非豁免实现”，不是谎称 app 从不加密。
- 在前述条件成立后，`ITSAppUsesNonExemptEncryption = false`（Boolean）。如果存在非豁免加密，则为 true，并按 Apple 要求提供文档与可能的 `ITSEncryptionExportComplianceCode`。

这是根据官方分类表推导的填写建议；当前没有进入账号看到实际问卷，不能保证按钮文案/顺序。该布尔值表示有无**非豁免加密**，不是有无任何 AES/TLS。来源：[Complying with Encryption Export Regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)、[Determine and upload app encryption documentation](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation)。

可供最终审核资料使用的英文技术说明模板（确认代码后补全/删减）：

> LinkScope Lite uses the Apple CryptoKit framework for AES-GCM encryption of locally stored app data and Apple Security services for key storage. The app does not implement or bundle proprietary cryptographic algorithms or a third-party cryptographic library. Its cryptographic functionality is provided by Apple operating system frameworks.

这是描述性声明草案，并非 Apple/BIS 签发的认证。AES 密钥长度、加密范围、Keychain 是否同步/迁移等应只填源码确认值。

**未核实法律事项**：Apple 无需上传文档不能直接推出美国年度自分类报告也一概免除。BIS 将报告要求与 EAR §740.17(b)(1)、§740.17(e)(3) 和产品分类相连，具体取决于发布主体、功能、目的地等；没有确定这些事实，不应擅自写“EAR99”或“5D992.c”，也不应生成已签署出口认证。来源：[Apple export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)、[BIS EAR 742 Supplement No. 8](https://www.bis.gov/regulations/ear/742)、[BIS EAR 740](https://media.bis.gov/regulations/ear/740)。

## 5. 年龄分级

必须完成现行问卷；由 Apple 生成全球及地区评级。26 及以后系统使用新评级显示，旧系统显示可能不同；不要把历史 4+/9+/12+/17+ 表直接套用。若无高龄内容，且无额外年龄限制，可不覆写。来源：[Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)。

无线配件观察工具的填写草案：

| 问卷内容 | 按当前产品定位的候选回答 |
|---|---|
| Parental Controls / Age Assurance | No，除非实际有相应功能 |
| Unrestricted Web Access | No，前提是没有能自由访问任意网页的内置浏览器 |
| User-Generated Content / Social Media | No，前提是没有面向大众分发用户内容 |
| Messaging and Chat / Advertising | No，前提是实际不存在 |
| 粗俗/恐怖/烟酒毒品、医疗/健康、性或裸体、暴力、赌博/竞赛/loot boxes 等 | 每一项均按真实内容选择 None/No，不应跳题 |
| Kids / Higher Age Override | Not Applicable，除非法律/合同另有年龄要求 |
| Age Suitability URL | 可空 |

设备名称、用户本机命名的仪表盘和手动导入/导出不自动符合“广泛分发用户内容”的 UGC 定义；外部浏览器打开支持页面不自动等于 app 内无限制网页访问。以上是基于 Apple 定义的判断，需对实际 UI 路径确认。若所有相关内容确实为 None/No，可预期 4+，最终以 ASC 算出的地区结果为准。来源：[Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)。

## 6. Accessibility Nutrition Labels

当前官方总览仍说明自愿提供；尚未提供时商店会显示尚未声明。声称支持某项特性前，用户必须能用该特性完成全部常见任务。Mac **没有 Larger Text 标签**。适用候选包括 VoiceOver、Voice Control、Dark Interface、Differentiate Without Color Alone、Sufficient Contrast、Reduced Motion；音视频类标签仅在有相应内容时评估。来源：[Overview of Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)。

建议针对实际 Lite 版评估首次启动、权限说明、设备列表/详情、筛选刷新、历史、导出、设置等，记录“已验证/未验证/不适用”。能看到深色界面或 AX 元素不等于已通过整套评估。未实测的特性不填支持；Accessibility URL 可选，若提供应有针对本 app 的说明。来源：[Manage Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels)。

## 7. 账号与商业字段

- **DSA Trader**：即使不在 EU 发售也需声明状态；是否 trader 由主体自评，不可因“免费”或“个人账号”直接选非 trader。若为 trader，EU 页面公示地址、电话、邮箱；组织地址来自 D-U-N-S，个人可提供地址或 P.O. Box。还可能需付款账户、证明材料和联系方式验证。最终由 Account Holder/Admin 完成。来源：[DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)。
- **Price**：用户已明确确认本次发行 **Free / 免费**，App Store Connect 中尚未保存。提审前选择 Free 并核对保存结果；若未来增加付费发行或 IAP，再按适用要求由 Account Holder 接受 Paid Apps Agreement，并处理税务/银行信息。来源：[Set a price](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price)、[Sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements)。
- **Availability**：选择发行 storefronts、预购与否、公开/私有分发。当前目标是公众 Mac App Store，可建议 Public；不应自行代用户勾选全部地区。Tax Category 可审阅默认 App Store Software；教育批量折扣等为商业选择。来源：[App pricing and availability](https://developer.apple.com/help/app-store-connect/reference/pricing-and-availability/app-pricing-and-availability)、[Set distribution methods](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/set-distribution-methods)。
- 区域许可、ICP 或特定内容审批只有适用时填写，不应凭一个 Mac 工具类名称认定必需或豁免。已选地区、账号页面提示和适用条件需最终核验。
- 签名团队、合法 Seller/Developer Name、开发者会员及协议有效状态、实际 App ID、已有记录与版本、审核联系人、公开客服联系方式、DSA 和税银均不能从本地代码完整推断。

## 8. 最后制作截图时使用的规范

Mac 截图每种本地化 1–10 张，`.jpeg` / `.jpg` / `.png`；不能有 alpha/透明度；比例 16:10。允许像素尺寸：**1280×800、1440×900、2560×1600、2880×1800**。建议最终统一用 2880×1800 RGB PNG。来源：[Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)。

必须以正在使用的真实 app 界面为核心；可以叠加文字/图形说明。不能只交标题海报、启动页，不能把 Full 才有的 UI 当作 Lite 功能。避免私人设备名、标识、账号等，使用受控演示环境的数据；保留实际 UI 并在明确的示例数据流程中采集。来源：[App Review Guidelines 2.3.3、2.3.9](https://developer.apple.com/app-store/review/guidelines/)。

可选视频不是必交：每种设备尺寸/本地化最多 3 条；本轮用户要求的是截图，可不制作预览视频。审核通过后更新截图通常需要新版本，因此本轮应在上传前完成像素、透明通道、文案与实际 Lite 功能的一致性检查。来源：[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)。

“参考 Apple 27.0 宣传页”属于视觉方向，不改变上述 ASC 要求，也不等于复制 Apple 标识、硬件或制造官方背书。本文件不提前设计截图；待实机验证与功能事实冻结后再进行设计。

## 9. 提交前未决检查

1. 真实设备运行与 Release 发行归档是不同证据：Debug 测试可帮助发现问题，但不能当作 Release/App Store 签名已通过。
2. 最终构建的版本、Bundle ID、权限/沙盒、图标、版权、最低系统、隐私清单和加密布尔值逐一核对。
3. 官网/隐私页必须可访问且无占位文字，Support URL 有真实联系方式。
4. 在 App Store Connect 保存用户已确认的 Free 定价；已勾选商店地区的合规、DSA、账号协议与审核联系人由账号事实完成。
5. 当前 Apple Upcoming Requirements 列出的 2026-04-28 SDK 规则明确列 iOS/iPadOS/tvOS/visionOS/watchOS，并未在该条中列 macOS；不要未经证据写“所有 Mac 必须 macOS 26 SDK”。该页另要求 Mac 上传构建内不得包含 `com.apple.quarantine`，以及适用 Required Reason APIs 要声明批准原因。来源：[Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/)。

本次未完成：开发者账号内最终校验、实际问卷截图、App Store 构建上传验证、Free 定价在账号内的保存核验及发行地区确认、BIS 产品法律分类、新隐私政策公网发布后的正文核验。上述没有被宣称完成。
