# Git for this workspace

**Canonical repository (commit and push here):**

`C:\Users\shuji\OneDrive\Documents\GitHub\Yso`

This Desktop folder is for editing Mudlet/Yso sources. It is not a separate git repository anymore.

## Commit from the Desktop workspace

Sync `Ysindrolir/` into the GitHub clone, then run git there:

```powershell
.\Ysindrolir\scripts\Invoke-YsoGit.ps1 status
.\Ysindrolir\scripts\Invoke-YsoGit.ps1 add -A
.\Ysindrolir\scripts\Invoke-YsoGit.ps1 commit -m "Your message"
.\Ysindrolir\scripts\Invoke-YsoGit.ps1 push origin main
```

## Commit directly in the GitHub clone

```powershell
cd C:\Users\shuji\OneDrive\Documents\GitHub\Yso
git status
git commit -am "Your message"
git push origin main
```
