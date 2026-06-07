# PC Cleaner Skill — Design Spec

**Date:** 2026-06-08  
**Status:** Draft  
**Author:** User + Claude

---

## 1. Overview

A Claude Code skill plugin that lets users clean their Windows PC by talking to Claude. The user says "清理电脑" and Claude scans the system, presents a report, and cleans on confirmation.

**Type:** Claude Code Skill Plugin (Option A)  
**Architecture:** Modular PowerShell scripts + intelligent skill frontend (Option C — mixed)  
**Safety model:** Conservative — scan first, report, confirm, then clean (Option A)

---

## 2. Project Structure

```
pc-cleaner/
├── CLAUDE.md                    # Project overview for developers
├── LICENSE                      # MIT License
├── README.md                    # User-facing install & usage guide
├── .gitignore
├── scripts/
│   ├── pc-cleaner.psm1          # Shared module (formatting, safety, privilege check)
│   ├── scan-temp.ps1            # System temp files
│   ├── scan-browser.ps1         # Browser caches (Chrome/Edge/Firefox)
│   ├── scan-recycle.ps1         # Recycle Bin
│   ├── scan-leftovers.ps1       # Software leftovers (orphaned folders)
│   ├── scan-large.ps1           # Large files & duplicate files
│   └── scan-userjunk.ps1        # User directory junk (Downloads, Desktop)
├── skills/
│   └── pc-cleaner.md            # Claude Code skill definition (entry point)
└── tests/
    ├── test-module.ps1          # Module function tests
    ├── test-scan-modes.ps1      # Scan mode: valid JSON output for all scripts
    └── test-edge-cases.ps1      # Edge cases: empty dirs, permission errors, special chars
```

### File Responsibilities

| File | Responsibility |
|------|---------------|
| `skills/pc-cleaner.md` | Defines Claude's behavior: understand user intent, call scan scripts, present report, confirm, call clean scripts, report results |
| `scripts/pc-cleaner.psm1` | Shared module: `Get-SizeDisplay`, `Format-ScanResult`, `Test-AdminPrivilege`, `Safe-RemoveItem` |
| `scripts/scan-*.ps1` | Each accepts `-Action Scan\|Clean`. Scan outputs JSON; Clean deletes and reports. |
| `tests/*.ps1` | Verify module functions, scan-mode output, and edge cases |

---

## 3. Data Flow

```
User: "清理电脑"
        │
        ▼
┌──────────────────────────────────────────┐
│  Claude (guided by pc-cleaner.md)        │
│  1. Parse intent → full scan requested   │
│  2. Call all 6 scan scripts (Scan mode)  │
│  3. Aggregate results                    │
└──────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────┐
│  Claude displays summary table:          │
│                                          │
│  📊 PC Cleaner Scan Report               │
│  ┌────────────┬────────┬────────┬──────┐ │
│  │ Category   │ Files  │ Size   │ Risk │ │
│  ├────────────┼────────┼────────┼──────┤ │
│  │ Temp       │ 234    │ 1.2 GB │ Low  │ │
│  │ Browser    │ 1500   │ 850 MB │ Med  │ │
│  │ Recycle    │ 12     │ 45 MB  │ Low  │ │
│  │ Leftovers  │ 8      │ 320 MB │ High │ │
│  │ Large/Dup  │ 3      │ 4.5 GB │ High │ │
│  │ User Junk  │ 67     │ 200 MB │ Med  │ │
│  ├────────────┼────────┼────────┼──────┤ │
│  │ Total      │ 1824   │ 7.1 GB │      │ │
│  └────────────┴────────┴────────┴──────┘ │
│                                          │
│  Options: [全部清理] [仅低风险] [自定义]   │
└──────────────────────────────────────────┘
        │
        ▼ (user confirms)
┌──────────────────────────────────────────┐
│  Claude calls Clean mode for selected    │
│  items, displays results:                │
│  ✅ Temp: freed 1.2 GB                   │
│  ✅ Recycle: freed 45 MB                 │
│  🎉 Total freed: 1.25 GB                 │
└──────────────────────────────────────────┘
```

---

## 4. Scan Module Details

### Unified Script Interface

Every scan script uses the same interface:

```
.\scan-xxx.ps1 -Action Scan    # Returns JSON, read-only
.\scan-xxx.ps1 -Action Clean   # Executes cleanup, returns report JSON
```

### Standard JSON Output (Scan mode)

```json
{
  "category": "系统临时文件",
  "risk": "low",
  "totalSize": 1288490188,
  "fileCount": 234,
  "items": [
    {
      "path": "C:\\Windows\\Temp\\xxx.tmp",
      "size": 1048576,
      "lastModified": "2026-06-01",
      "safeToDelete": true
    }
  ]
}
```

### Risk Levels

| Level | Meaning | Examples |
|-------|---------|----------|
| `low` | Auto-generated, safe to delete | Temp files, Recycle Bin |
| `medium` | May require re-login or re-download | Browser cache, Cookies |
| `high` | Requires per-item user confirmation | Large files, software leftovers |

---

### 4.1 scan-temp.ps1 (risk: low)

**Scan targets:**
- `C:\Windows\Temp\` — system temp
- `$env:TEMP` — user temp
- `C:\Windows\Prefetch\` — prefetch cache
- `C:\Windows\SoftwareDistribution\Download\` — Windows Update download cache
- `thumbcache_*.db` — thumbnail cache

**Clean strategy:** Delete only files older than 7 days. Do not delete directories.

---

### 4.2 scan-browser.ps1 (risk: medium)

**Scan targets:**

| Browser | Cache Path |
|---------|------------|
| Chrome | `%LocalAppData%\Google\Chrome\User Data\*\Cache\` |
| Edge | `%LocalAppData%\Microsoft\Edge\User Data\*\Cache\` |
| Firefox | `%LocalAppData%\Mozilla\Firefox\Profiles\*\cache2\` |

**Clean strategy:** Delete cache files. Warn user they may need to re-login to sites.

---

### 4.3 scan-recycle.ps1 (risk: low)

**Scan targets:** All drive root `$Recycle.Bin` directories.  
**Clean strategy:** `Clear-RecycleBin -Force`

---

### 4.4 scan-leftovers.ps1 (risk: high)

**Scan targets:**
- `C:\Program Files\`, `C:\Program Files (x86)\` — folders not in registry uninstall list
- `%AppData%`, `%LocalAppData%` — software folders not matching installed programs

**Clean strategy:** Report only. Each item requires explicit user confirmation to delete.

---

### 4.5 scan-large.ps1 (risk: high)

**Scan targets:**
- Large files: user directory, files > 500 MB, top 20 by size
- Duplicate files: MD5 hash comparison of files in user directories

**Clean strategy:** For duplicates, keep newest copy, delete rest. Large files: report only, user decides.

---

### 4.6 scan-userjunk.ps1 (risk: medium)

**Scan targets:**
- `$env:USERPROFILE\Downloads\` — files not accessed in 30+ days
- Desktop: `.tmp`, `.log`, `.dmp` files
- `%AppData%\Recent\` — recent document shortcuts
- `.crashreport`, `.dmp`, Windows Error Reporting files

**Clean strategy:** Delete matching files, report freed space.

---

## 5. Safety Principles

1. **Scan/Clean separation** — Scan is always read-only. Clean only runs after user confirms.
2. **Path whitelist validation** — `Safe-RemoveItem` rejects deletion of system-critical paths (`C:\Windows`, `C:\Program Files`, `C:\Windows\System32`)
3. **Admin privilege check** — Most clean operations require admin. Scripts check and guide the user to elevate if needed.
4. **Age-based filtering** — Temporary files only deleted if older than 7 days to avoid disrupting active processes.
5. **Confirmation gate** — Claude MUST present the scan report and wait for user selection before calling any Clean action. This is enforced in the skill definition file.

---

## 6. Error Handling

| Scenario | Handling |
|----------|----------|
| Not running as admin | Prompt user to elevate, show command |
| File locked / in use | Skip file, mark "in use" in report |
| Path does not exist | Skip path gracefully |
| PowerShell < 5.1 | Check `$PSVersionTable.PSVersion`, show upgrade link |
| No browsers installed | Return empty result for browser scan |

---

## 7. Testing Strategy

### test-module.ps1
- `Get-SizeDisplay` correct for 0 B, 1024 B, 1048576 B, 1073741824 B
- `Safe-RemoveItem` rejects system paths
- `Test-AdminPrivilege` returns boolean

### test-scan-modes.ps1
- Each script `-Action Scan` outputs valid JSON
- JSON contains required fields: `category`, `risk`, `totalSize`, `fileCount`, `items`
- Empty scan (nothing to clean) returns valid empty result

### test-edge-cases.ps1
- Empty directories → no error, empty items array
- Inaccessible paths → handled gracefully
- Paths with special characters → handled correctly

---

## 8. Dependencies

- **Windows 10/11** with PowerShell 5.1+
- **Claude Code CLI** installed
- No external PowerShell modules required — uses built-in cmdlets only
- No Python, Node.js, or other runtime dependencies

---

## 9. Installation (for end users)

```bash
# 1. Clone the repo
git clone https://github.com/<user>/pc-cleaner.git

# 2. Install as Claude Code skill
claude skills install /path/to/pc-cleaner/skills/pc-cleaner.md
```

---

## 10. GitHub Repository Checklist

- [ ] `README.md` — install guide, usage examples, screenshots
- [ ] `LICENSE` — MIT
- [ ] `CLAUDE.md` — developer context
- [ ] All script files with comment headers
- [ ] `skills/pc-cleaner.md` — skill definition
- [ ] Tests passing
