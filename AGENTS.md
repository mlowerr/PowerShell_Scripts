# Repository agent notes

## Documentation scope
- `README.md` should stay task-oriented and concise (what to run, in what order, and safety notes).
- Keep per-script behavior details in `SCRIPTS_OVERVIEW.md` to avoid duplication.
- When script defaults change, update both `README.md` and `SCRIPTS_OVERVIEW.md` in the same commit.

## Accuracy checks before doc edits
- Confirm parameter defaults directly from each `.ps1` file.
- Verify example commands match script defaults or explicitly pass parameters when defaults are inconsistent.
- Treat `G:\` as an example path only; do not assume it exists.

## Safety language
- Keep warnings explicit for scripts that delete or move files.
- Prefer examples that generate scripts/reports before destructive actions.
