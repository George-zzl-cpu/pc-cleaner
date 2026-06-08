<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=flat-square" alt="PowerShell">
  <img src="https://img.shields.io/badge/Platform-Windows-10%2F11-informational?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/github/stars/George-zzl-cpu/pc-cleaner?style=flat-square" alt="Stars">
</p>

<h1 align="center">🧹 PC Cleaner</h1>
<p align="center"><strong>对 Claude 说一句话，自动扫描并清理你的 Windows 电脑</strong></p>
<p align="center">A Claude Code Skill powered by PowerShell — no extra dependencies</p>

---

## 🎬 效果预览

在 Claude Code 对话框里说 **"清理电脑"**，它会：

1. 自动扫描 6 类可清理项
2. 展示一份清晰的报告（文件数、占用空间、风险等级）
3. 等你确认后才执行清理
4. 告诉你释放了多少空间

```
📊 PC Cleaner 扫描报告
┌─────────────────┬────────┬──────────┬────────┐
│ 系统临时文件      │ 234    │ 1.20 GB   │ 🟢 低  │
│ 浏览器缓存        │ 1500   │ 850 MB    │ 🟡 中  │
│ 回收站           │ 12     │ 45 MB     │ 🟢 低  │
│ 软件残留         │ 8      │ 320 MB    │ 🔴 高  │
│ 大文件/重复文件   │ 3      │ 4.50 GB   │ 🔴 高  │
│ 用户目录垃圾      │ 67     │ 200 MB    │ 🟡 中  │
├─────────────────┼────────┼──────────┼────────┤
│ 🎉 总计发现      │ 1824   │ 7.11 GB   │        │
└─────────────────┴────────┴──────────┴────────┘
```

---

## 🚀 安装

**前提：** 已安装 [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | Windows 10/11 | PowerShell 5.1+

```bash
# 1. 克隆仓库
git clone https://github.com/George-zzl-cpu/pc-cleaner.git

# 2. 用 Claude CLI 创建插件骨架
claude plugin init pc-cleaner

# 3. 把脚本和 skill 定义复制进去
cp -r pc-cleaner/scripts ~/.claude/skills/pc-cleaner/
cp pc-cleaner/skills/pc-cleaner.md ~/.claude/skills/pc-cleaner/SKILL.md -Force

# 4. 在 Claude Code 中加载
#    直接输入: /reload-plugins
```

---

## 📖 使用

打开 Claude Code，直接说：

| 你对 Claude 说 | 效果 |
|---------------|------|
| `清理电脑` | 全面扫描，按报告确认后清理 |
| `扫描临时文件` | 只查系统临时文件 |
| `清理浏览器缓存` | 只清理 Chrome/Edge/Firefox 缓存 |
| `清空回收站` | 一键清空回收站 |
| `查找大文件` | 列出 Top 20 大文件 + 重复文件 |
| `查找软件残留` | 扫描卸载后留下的文件夹 |

---

## 🛡️ 安全策略

| 原则 | 说明 |
|------|------|
| 🔒 **先扫后清** | 绝不跳过扫描直接删除 — 必须展示报告等确认 |
| 🎯 **分级风险** | 🟢 低（临时文件/回收站）→ 可批量清理<br>🟡 中（浏览器缓存）→ 提醒后果<br>🔴 高（大文件/残留）→ 逐项确认 |
| 🏠 **系统保护** | 黑名单拦截 `C:\Windows`、`System32`、`Program Files` 等关键目录 |
| ⏱️ **时效过滤** | 临时文件只清理 7 天前的，避免影响正在运行的程序 |

---

## 🧩 功能模块

| 模块 | 清理范围 | 风险 |
|------|---------|:----:|
| 🗂️ 系统临时文件 | `%TEMP%`、`Windows\Temp`、Prefetch、更新缓存、缩略图 | 🟢 |
| 🌐 浏览器缓存 | Chrome / Edge / Firefox — Cache、GPUCache、Service Worker | 🟡 |
| 🗑️ 回收站 | 所有驱动器的 `$Recycle.Bin` | 🟢 |
| 📦 软件残留 | `Program Files` + `AppData` 中不在注册表里的文件夹 | 🔴 |
| 🐘 大文件/重复 | 用户目录 >500MB 文件 + MD5 重复检测（保留最新） | 🔴 |
| 📁 用户垃圾 | Downloads 超 30 天、Desktop 的 .tmp/.log/.dmp、WER | 🟡 |

---

## 🧪 开发

```bash
# 运行全部测试 (Pester)
Invoke-Pester tests/
```

9 个 git commit，7 步构建，完整可追溯。

---

## 📄 License

MIT © [George-zzl-cpu](https://github.com/George-zzl-cpu)

---

<p align="center">
  ⭐ <strong>如果觉得有用，给个 Star 吧！</strong> ⭐
</p>
