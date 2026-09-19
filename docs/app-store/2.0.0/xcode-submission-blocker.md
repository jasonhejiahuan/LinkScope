# Xcode 工具链导致的上传拒绝

2026-09-19 用户报告：`This bundle is invalid. Apple is not currently accepting applications built with this version of Xcode.`。

## 已核对证据

- Organizer 中的 `LinkScopeLite-2.0.0-9-final.xcarchive` 与仓库 `build/AppStore` 同名归档均记录 `DTXcodeBuild=27A5252f`、`DTXcode=2700`、`DTSDKBuild=26A5419a`。这是旧 Beta 工具链产物，不是当前正式 Xcode 27 的构建。
- 当前 `/Applications/Xcode.app` 为 **Xcode 27.1 Beta（27A9269）**；`/Applications/Xcode-beta.app` 为 **Xcode 27.2 Beta（27B5019j）**。不能根据应用文件名判断正式版。
- 当前 `xcode-select -p` 指向前者；切换当前这两个安装不能得到正式工具链。常用 Applications / Downloads 目录未找到正式版安装或 XIP。
- Apple 发布列表列出 2026-09-14 的 **Xcode 27 正式版（27A266a）**。9 月 9 日公告已经开放最新系统提交，要求使用相应 Xcode RC / 最新 SDK。

来源：[Apple 发布版本](https://developer.apple.com/news/releases/)、[最新系统提交公告](https://developer.apple.com/cn/news/?id=k1mtkt1k)。工具链接受情况仍以最终上传验证为准。

正式发行与 TestFlight 的接受范围不同，不能把所有 Beta 都视为禁止上传。Apple 的 [App Store Connect 更新记录](https://developer.apple.com/help/app-store-connect/release-notes/) 明确：2026-09-14 开放 Xcode 27 正式版的 App Store 和 TestFlight 上传；2026-09-16 开放 Xcode 27.2 Beta（含 macOS SDK）的 TestFlight 内外部测试；2026-09-18 开放 Xcode 27.1 Beta 的 iOS/iPadOS TestFlight 测试。本次正式上架仍采用正式版重新归档。

## 修复步骤

1. 从 [Apple Developer Downloads](https://developer.apple.com/download/all/?q=Xcode%2027) 安装 **Xcode 27（27A266a）正式版**，建议另存为 `/Applications/Xcode-27.app`，保留现有 Beta。
2. 启动一次该正式版，按 Xcode 提示完成首次组件安装。用下面的命令确认版本，必须为 `Xcode 27.0` / `Build version 27A266a`，不能仅确认界面写着 27。
3. 使用正式版重新执行 Release Archive。用新目录隔离旧产物；不要重复上传旧 `final.xcarchive`，不要手动修改包内 DTXcode / SDK 标记。
4. 核对新归档 `DTXcodeBuild=27A266a`、版本、签名和 entitlements。随后在 Organizer 执行 App Store Connect 的 Validate / Distribute。若 ASC 已占用 build 9，先在 project 级统一递增构建号，再重新归档；此处未擅自修改版本。

正式版安装完成后的命令（尚未执行）：

```sh
DEVELOPER_DIR=/Applications/Xcode-27.app/Contents/Developer xcodebuild -version

env -u LD -u LDPLUSPLUS -u CC -u CXX -u AR -u AS -u NM \
  -u RANLIB -u STRIP -u LIBTOOL -u OTOOL -u INSTALL_NAME_TOOL -u LIPO \
  DEVELOPER_DIR=/Applications/Xcode-27.app/Contents/Developer \
  xcodebuild -project LinkScope.xcodeproj -scheme 'LinkScope Lite' \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData-AppStore-Xcode27 \
  -archivePath build/AppStore/LinkScopeLite-2.0.0-9-Xcode27-stable.xcarchive \
  archive

/usr/libexec/PlistBuddy -c 'Print :DTXcodeBuild' \
  'build/AppStore/LinkScopeLite-2.0.0-9-Xcode27-stable.xcarchive/Products/Applications/LinkScope Lite.app/Contents/Info.plist'
```

本地 strict codesign 成功只能证明该范围的签名验证，不能证明 Apple 接受所用 Xcode/SDK。此前归档应保留为本地测试证据，不再作为待提交包。正式版尚未安装，因此本轮没有生成替代归档，也没有重新上传或宣称错误已消除。
