# App Store Connect 发行操作顺序

此文件是待执行流程。资料已经准备；没有代用户接受协议、创建商店记录、上传构建或提交审核。

**当前优先阻塞：** 用户已报告旧包因 Xcode 版本被拒。先按 [工具链修复说明](xcode-submission-blocker.md) 安装正式 Xcode 27（27A266a）并重新归档；旧 `final.xcarchive` 不可继续提交。当前名为 `Xcode.app` 的安装也是 Beta。

1. **关闭实机验收缺口。** 按 `real-device-qa.md` 补齐 Diagnostics/RSSI、导入导出、通知/Shortcuts，以及正式/最低系统验证。使用已修复的代码；不要把 provider Running 当作 RSSI 已通过。
2. **更新公网内容。** 将审阅后的双语政策发布到用户指定的 `/linkscope/privacy`，更新产品页的发行信息，确保 Support URL 可找到有效联系方式，再检查实际正文。
3. **核对开发者账号。** 在 My Apps 查找既有 LinkScope Lite，确认 macOS、bundle `cc.jasonstu.linkscope.lite`、SKU/Apple ID、合法权利人、会员、协议、DSA 与地区。保留已有记录；用户已确认本次发行免费，在 App Store Connect 选择 Free 并保存（目前尚未保存）。
4. **归档并上传正式包。** 使用 Release / LinkScope Lite；若 build 9 已使用，先仅在 project 级递增 build 并同时核对两个 target。通过 Xcode Organizer 的 App Store Connect 分发流程重新核对签名和 provisioning，Validate 后 Upload。当前本地 final.xcarchive 是 Apple Development 验证归档，不能当作分发成功证明。
5. **填写两套文案。** 从 `metadata.md` 或 `metadata.json` 填 Name、Subtitle、Promotional Text、Description、Keywords、URL 与 copyright；首次商店版本不填 What's New。确认税类、已保存的 Free 定价和地区，使用真实审核联系人，不复制 null/待定文字。
6. **填隐私、加密和年龄问卷。** 参照 `privacy-and-encryption.md`：当前源码候选为 Data Not Collected、No Tracking；加密由 Apple OS 提供，非“完全未使用加密”。选处理完的构建，核对 `ITSAppUsesNonExemptEncryption=false`。年龄问卷逐题按准备表回答，使用 Apple 算出的地区评级。尚未验证的辅助功能不要声称支持。
7. **上传并复核视觉内容。** 每种语言选择 `Design/AppStore/2.0.0/exports/<locale>/01…04-*.png`，顺序为来源、仪表盘、历史诊断、权限。8 张原生素材的成品已检查尺寸、色彩通道和画面；在 ASC 预览确认顺序、语言、裁切和配套文案。视频可不填。
8. **完成 App Review 区域。** 填真实姓名/邮箱/电话，无登录则不要求演示账号，粘贴英文 Review Notes；硬件依赖和公开 API 边界已写在稿件中。最终包有行为变化时同步更新 notes。
9. **最后审核和发布。** 清除 ASC 验证项，逐页复核账号声明和所有未决项，再由用户授权提交审核；建议选择手动发布。审核通过后再确认产品页、隐私页、支持渠道和 Free 定价，执行发布并核验真实商店链接。

Apple 来源和字段限制见 [规范核验](apple-requirements.md)，账号待定事实见 `metadata.json` 的 `accountPending`。开发者账号内的实时提示优先于静态清单。
