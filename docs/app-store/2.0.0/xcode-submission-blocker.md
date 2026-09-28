# 旧归档提交错误与 GUI 发布约定

## 用户验证结果

2026-09-19 用户提交此前由助手生成的归档时遇到：

> This bundle is invalid. Apple is not currently accepting applications built with this version of Xcode.

用户随后反馈：使用当前 Xcode 自行重新 Archive 后，不再出现这条错误。此前被检查的旧 `LinkScopeLite-2.0.0-9-final.xcarchive` 记录 `DTXcodeBuild=27A5252f`；该元数据描述旧包，不能据此判定用户当前 Xcode 27.2 Beta 不支持提交。

**更正：** 撤回此前“必须安装 Xcode 27 正式版才能解决”的结论。已确认的处理方式是用户重新生成归档，不是已证明需要更换 Xcode。重新归档为何消除错误尚未作进一步隔离验证，也不能将此结果写成 App Store 最终审核通过。

## 后续发布约定

- 用户在 **Xcode GUI** 中手动执行 **Product > Archive**，并通过 **Organizer** 完成验证、分发和上传；审核提交也由用户操作。
- 除非用户在当前任务明确要求，助手不自动构建 Release 发布产物，不运行 archive/export/upload，不通过 GUI 自动化或 CI 代替用户提交。
- 助手负责代码、Debug 构建与测试、商店文案、隐私和加密声明、截图以及交接说明。发布准备不隐含自动打包授权。
- 不再将助手之前生成的 `final.xcarchive` 作为默认提交包。以用户本次在 GUI 新建的归档及其实际验证结果为准。
- 如果再次出现类似错误，先核对**实际提交归档**的创建时间、Xcode/SDK 构建号和验证日志，再判断原因；不只根据已安装 Xcode 的名称或是否带 Beta 推断。

完整操作顺序见 [发行流程](submission-runbook.md)，长期约定同步保存在仓库根目录 `AGENTS.md`。
