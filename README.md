# PC Cleaner — Claude Code Skill

让 Claude 帮你清理 Windows 电脑。支持扫描和清理系统临时文件、浏览器缓存、回收站、软件残留、大文件/重复文件、用户目录垃圾。

## 安装

```bash
# 1. 克隆仓库
git clone https://github.com/<user>/pc-cleaner.git

# 2. 安装到 Claude Code
claude skills install /path/to/pc-cleaner/skills/pc-cleaner.md
```

## 使用

在 Claude Code 中直接说：

- "清理电脑" — 全面扫描并选择清理
- "扫描临时文件" — 只扫描系统临时文件
- "清理浏览器缓存" — 只清理浏览器缓存

## 安全策略

- **先扫描后清理** — 所有操作先展示报告，确认后才执行
- **保守默认** — 默认只清理低风险项（临时文件、回收站）
- **高风险需确认** — 大文件、软件残留等需逐项确认

## 功能

| 模块 | 说明 | 风险 |
|------|------|------|
| 系统临时文件 | Windows Temp, 更新缓存, 缩略图缓存 | 低 |
| 浏览器缓存 | Chrome/Edge/Firefox 缓存 | 中 |
| 回收站 | 清空回收站 | 低 |
| 软件残留 | 卸载后遗留的文件和文件夹 | 高 |
| 大文件/重复文件 | 查找占用空间的大文件和重复文件 | 高 |
| 用户目录垃圾 | 下载文件夹、桌面垃圾文件 | 中 |

## 依赖

- Windows 10/11
- PowerShell 5.1+
- Claude Code CLI

## License

MIT
