# Printly

macOS 批量打印工具。拖入文件夹后自动递归扫描、分类、排序，将 PDF / 图片 / Markdown / Word / Excel 统一转为 PDF，再静默发送到所选打印机。

最低系统版本：**macOS 12.4**

仓库：<https://github.com/maqing1024/Printly>

## 功能

- 拖入或选择文件夹，递归扫描
- 按文件名自然序排序（忽略大小写，`A2` < `A10`）
- 支持 PDF、JPG / JPEG、PNG、HEIC、Markdown（`.md` / `.markdown`）、DOCX、XLSX
- PDF / 图片直接进入打印管线；图片转为单页 PDF
- Markdown 本地渲染为多页 PDF（不依赖 Office）
- Word / Excel：优先 Microsoft Office，失败则回退 LibreOffice
- 一键下载并安装 LibreOffice（带进度条）
- 串行批量打印、进度、失败自动重试 1 次，支持重试失败项
- 选择系统中已添加的打印机；可打开系统设置添加附近打印机
- 窗口工具栏：选文件夹 / 开始 / 取消 / 打印机
- 界面文案：简体中文、English

## 系统要求

- macOS 12.4 或更高
- Xcode 用于从源码编译
- 打印 Word / Excel 需要其一：
  - 已安装 Microsoft Word / Excel
  - 或 LibreOffice（可用应用内「一键安装」）

## 从源码运行

1. 用 Xcode 打开 `Printly.xcodeproj`
2. 选择 scheme `Printly`，目标为本机 Mac
3. Run（⌘R）

单元测试：

```bash
xcodebuild -scheme Printly -destination 'platform=macOS' test -only-testing:PrintlyTests
```

## 使用说明

1. 将文件夹拖到窗口中的拖入区，或点击拖入区 / 工具栏选择文件夹
2. 查看文件数量与类型统计
3. 在打印机列表中选择目标打印机（必要时先「刷新」或「添加附近打印机」）
4. 若有 Word / Excel 且未安装转换工具，可一键安装 LibreOffice
5. 点击「开始批量打印」
6. 打印中可取消；结束后可对失败项重试

隐藏文件、`__MACOSX` 以及不支持的扩展名会被忽略。

## 架构

精简 Clean Architecture + MVVM：

```text
View → ViewModel → UseCase → Protocol ← Data Adapter
```

- `Domain`：实体、用例、协议
- `Data`：扫描、分类、PDF 转换、CUPS / AppKit 打印
- `Presentation`：批量打印界面与状态
- `App`：依赖组装

后续增加文件类型时，扩展 `FileKind` / 分类表，并实现 `FileConverting` 注册到 `PDFPipeline` 即可。

## 品牌

应用图标为 Printly 自有图形（墨青背景 + 白色叠页），不使用第三方打印机或办公软件商标。

## 许可

本仓库尚未指定开源许可证。使用或分发前请联系仓库维护者。
