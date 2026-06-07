# PC Cleaner — Developer Context

A Claude Code skill plugin for Windows PC cleanup.

## Project layout

- `skills/pc-cleaner.md` — Skill definition entry point
- `scripts/pc-cleaner.psm1` — Shared PowerShell module
- `scripts/scan-*.ps1` — Individual scan/clean scripts (unified `-Action Scan|Clean` interface)
- `tests/` — Pester tests

## Architecture

Every scan script accepts `-Action Scan` (returns JSON, read-only) or `-Action Clean` (deletes, returns report JSON). The skill definition file (`pc-cleaner.md`) tells Claude how to call these scripts, present results, and confirm before cleaning.

## Testing

```powershell
# Run all tests
Invoke-Pester tests/
```
