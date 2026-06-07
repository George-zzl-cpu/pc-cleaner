---
name: pc-cleaner
description: Windows PC cleaner. Scan and clean system temp files, browser caches, recycle bin, software leftovers, large/duplicate files, and user directory junk. Conservative strategy: scan first, present report, confirm, then clean.
version: 1.0.0
author: user
---

# PC Cleaner — Windows PC Cleanup

When the user expresses intent to clean their PC, use this skill. Supports both Chinese and English commands.

## Core Principles

1. **Always scan before cleaning** — NEVER run Clean directly. Run Scan first, collect data, present report, wait for user confirmation.
2. **Risk-tiered display** — Low risk (temp files, recycle bin) = safe to bulk clean. Medium risk (browser cache, user junk) = warn about consequences. High risk (software leftovers, large files) = require per-item confirmation.
3. **Admin privilege check** — Most clean operations require admin. If not running as admin, guide the user how to elevate.

## Script Locations

All scripts are in the `scripts/` folder next to this skill file. Replace `<SKILL_DIR>` with the actual directory containing this skill file.

```
scripts/
├── pc-cleaner.psm1       # Shared module
├── scan-temp.ps1          # System temp files (risk: low)
├── scan-browser.ps1       # Browser caches (risk: medium)
├── scan-recycle.ps1       # Recycle Bin (risk: low)
├── scan-leftovers.ps1     # Software leftovers (risk: high)
├── scan-large.ps1         # Large/duplicate files (risk: high)
└── scan-userjunk.ps1      # User junk (risk: medium)
```

## Workflow

### Step 1: Understand User Intent

Map user input to scan modules:

| User says | Module to run |
|-----------|--------------|
| "clean PC" / "full scan" / "清理电脑" / "全盘扫描" | All 6 modules |
| "clean temp files" / "清理临时文件" | scan-temp.ps1 |
| "clean browser cache" / "清理浏览器缓存" | scan-browser.ps1 |
| "empty recycle bin" / "清空回收站" | scan-recycle.ps1 |
| "find software leftovers" / "查找软件残留" | scan-leftovers.ps1 |
| "find large files" / "查找大文件" | scan-large.ps1 |
| "clean downloads" / "清理下载" | scan-userjunk.ps1 |

If ambiguous ("help me clean"), default to scanning all modules.

### Step 2: Check Admin Privilege

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Module '<SKILL_DIR>/scripts/pc-cleaner.psm1' -Force; Test-AdminPrivilege"
```

If not admin:
> ⚠️ This operation requires administrator privileges. Please restart Claude Code as administrator, or run:
> ```
> Start-Process pwsh -Verb RunAs
> ```
> Then try again.

### Step 3: Run Scans (Scan Mode)

For each selected module, run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/scan-<name>.ps1" -Action Scan
```

Parse the JSON output from each script:
- `category` — Category name
- `risk` — Risk level: `low`, `medium`, `high`
- `totalSize` — Total size in bytes
- `fileCount` — Number of files/items
- `items` — Array of file entries (path, size, lastModified, safeToDelete)

### Step 4: Present Scan Report

Display a summary table (convert bytes to human-readable sizes). Example format:

```
📊 PC Cleaner Scan Report
┌──────────────────┬────────┬──────────┬──────┐
│ Category         │ Files  │ Size     │ Risk │
├──────────────────┼────────┼──────────┼──────┤
│ System Temp      │ 234    │ 1.20 GB  │ 🟢 Low │
│ Browser Cache    │ 1500   │ 850 MB   │ 🟡 Med │
│ Recycle Bin      │ 12     │ 45 MB    │ 🟢 Low │
│ Software Leftovers│ 8     │ 320 MB   │ 🔴 High│
│ Large/Dup Files  │ 3      │ 4.50 GB  │ 🔴 High│
│ User Junk        │ 67     │ 200 MB   │ 🟡 Med │
├──────────────────┼────────┼──────────┼──────┤
│ Total            │ 1824   │ 7.11 GB  │      │
└──────────────────┴────────┴──────────┴──────┘

💡 Suggestions:
- 🟢 Low risk items (X.XX GB) can be safely cleaned
- 🟡 Medium risk items (X.XX GB): cleaning may require re-login or re-download
- 🔴 High risk items (X.XX GB): require per-item review to avoid deleting important data
```

### Step 5: Get User Confirmation

Present options (in the user's language):
> Choose cleaning scope:
> 1. 🟢 Clean low-risk items only (safe)
> 2. 🟢🟡 Clean low + medium risk items
> 3. 🔴 Clean everything (high-risk items will be confirmed one by one)
> 4. ✏️ Custom selection
> 5. ❌ Cancel

For high-risk items selected for cleaning, list each item's path and size and ask for confirmation.

### Step 6: Execute Clean (Clean Mode)

For each confirmed module, run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/scan-<name>.ps1" -Action Clean
```

Parse the clean report JSON:
- `category` — Category name
- `freed` — Bytes freed
- `display` — Human-readable size freed
- `failed` — Number of files that failed to delete
- `note` — Notes (if any)

### Step 7: Display Clean Results

```
✅ Cleanup Complete!
┌──────────────────┬──────────┬────────┐
│ Category         │ Freed    │ Failed │
├──────────────────┼──────────┼────────┤
│ System Temp      │ 1.20 GB  │ 0      │
│ Recycle Bin      │ 45 MB    │ 0      │
├──────────────────┼──────────┼────────┤
│ 🎉 Total Freed   │ 1.25 GB  │        │
└──────────────────┴──────────┴────────┘

⚠️ Note: Browser cache has been cleaned. Some websites may require re-login.
```

## Safety Rules

1. NEVER skip the scan step and go directly to Clean
2. NEVER perform bulk delete on system directories like `C:\Windows`, `C:\Program Files`, `C:\Windows\System32`
3. High-risk items (risk: high) MUST be listed one by one with paths for user confirmation — no bulk cleaning
4. If a scan returns empty results (fileCount = 0), tell the user "No cleanable files found" — do not report an error
5. If a scan script fails, continue with other scripts — do not abort the entire workflow
6. Convert byte sizes to human-readable format when displaying to the user

## Error Handling

- If PowerShell version < 5.1, inform the user to upgrade
- If path access is denied, note "permission denied" in the report
- If a script execution fails, show the error but continue with remaining modules
