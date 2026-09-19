# LinkScope Lite · App Store 截图

2026-09-19 制作；英语、简体中文各 4 张，共 8 张。发行对象为 **LinkScope Lite 免费版**，免费定价已获用户确认，尚未在 App Store Connect 保存。打开 [预览页面](index.html)，上传文件位于 [en-US](exports/en-US) 与 [zh-Hans](exports/zh-Hans)。`exports/manifest.json` 记录每张图的实际尺寸、色彩通道、缩放比例、原图及成品哈希。

| 顺序 | 内容 | 真实素材 |
| --- | --- | --- |
| 01 | 明确的数据来源 | Lite Release 的 7 个公开 provider 运行状态 |
| 02 | 自定义工作区 | Desk Overview 的四个 Provider Health 组件，显示来源及网格布局 |
| 03 | 诊断历史 | 已有会话 Demo 2 的 27 条 RSSI 记录、统计和时间序列 |
| 04 | 清楚的权限管理 | Saved History、Bluetooth、Notifications 权限页 |

视觉参考为本轮核验的 [Apple macOS 27 宣传页](https://www.apple.com/os/macos/)：黑色背景、银白大字、居中主体、充足留白和克制的玻璃边缘。它是美术方向，不是 Apple 发布的独立“App Store 27 截图标准”。实际交付按 [Apple Mac 截图规范](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) 制作 **2880×1800、16:10、8-bit RGB、无透明通道 PNG**。未使用 Apple 标识、硬件外壳、官方背书或虚构功能。

源文件在 [source](source/README.md)：可编辑 SVG/HTML、双语 copy.json 和可重复执行的渲染器。原始界面以整张 PNG 字节嵌入，保留原生文字、读数、圆角和阴影；没有重画 UI、生成 RSSI 曲线或替换状态。技术数据源名称和用户自定义的仪表盘/组件名称不会因切换界面语言自动翻译。

本次使用用户提供的 17:38:29–17:42:44 范围内 12 张原生截图中的 8 张，替代先前 computer-use JPEG。主窗口为 2798×1664，按 78.125% 等比放入画布；权限窗口为 1464×1280，按原始像素放入。没有放大、裁剪或改变原图。两张含个人设备名称的时间线与两张含 UUID/registry ID 的详情图未进入素材包。原始文件名及 SHA-256 对照见 [native-provenance.json](captured/native-provenance.json)。

已逐张检查 8 张成品：标题、副标题没有裁切，语言与场景对应，未发现私人设备名称或唯一 ID。仪表盘保留原应用可视区域，右侧组件在应用滚动视口边缘被截住，未通过后期拼接改变布局。诊断图展示的是 2026-08-19 的历史会话；它补充页面静态证据，不代表本轮新建、持续采样、停止、导出的交互测试通过。完整实测边界见 [QA 报告](../../../docs/app-store/2.0.0/real-device-qa.md)。

重新生成：

```sh
node Design/AppStore/2.0.0/source/render.mjs
```

替换原图时按其真实格式使用 `.jpg` 或 `.png`，同一场景只保留一份；不要仅改扩展名冒充无损 PNG。原图可以透明，但最终输出会在完整图层合成后转成无 alpha 的 RGB PNG。
