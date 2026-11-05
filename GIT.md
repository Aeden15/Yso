# Git for this workspace

The Desktop folder is an editing copy. The canonical Git clone is:

`C:/Users/shuji/OneDrive/Documents/GitHub/Yso`

All `git add`, `commit`, and `push` commands belong in that clone. A successful
workspace build does not mean the clone has been synchronized or committed.

## Preview and sync

```powershell
.\Ysindrolir\scripts\Invoke-YsoGit.ps1 -DryRun
.\Ysindrolir\scripts\Invoke-YsoGit.ps1 status
```

`-DryRun` previews copies and retirements without running any Git command.
Without it, the helper synchronizes `Ysindrolir/` plus the root README/Git/sync
documents, then runs the requested Git command (default: `status`). Review the
resulting diff before staging or committing. Commit/push remain separate actions.

Both this helper and `sync_workspace.ps1` use `scripts/Sync-YsoWorkspace.ps1`:

- Copy changed content even when source timestamps are older.
- Preserve unrelated destination files; do not mirror whole directories.
- Delete only paths explicitly listed in `scripts/retired-files.json`, whose
  destination SHA-256 matches the recorded pre-removal version.
- Validate every retirement path and destination conflict before copying.
- Refuse symlink/junction destinations; allow ordinary OneDrive cloud files.
- Exclude local environment/editor files, logs, backups, and `.workspace-link-publish/`.

If a retired destination file was modified, synchronization stops before copying.
Review and preserve those edits explicitly before resolving the retirement;
do not bypass the guard by using an unrestricted directory mirror.

The retirement manifest is relative to `Ysindrolir/` and contains `files` entries
with `path` and `sha256`. Keep it in source control so downstream workspaces also
receive deletions. It must never name absolute paths or paths outside that tree.

Run `Ysindrolir/scripts/test_workspace_sync.ps1` to verify sync behavior using
disposable directories. Publishing receipts is local and separate from Git.
