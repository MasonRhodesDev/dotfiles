---
name: chezmoi
description: This skill should be used whenever the user mentions "chezmoi" in any way. Manages dotfiles with chezmoi including tracking config files, comparing dotfiles, checking status, working with chezmoi templates, and handling local file changes. CRITICAL SAFETY RULES ENFORCED.
---

# Chezmoi Dotfiles Management

## CRITICAL SAFETY RULES

⚠️ **NEVER run these without explicit user confirmation:**
- `chezmoi apply` — overwrites local files with source state (destructive to local edits)
- Anything with `--force`

✅ Safe anytime: `chezmoi add`, `chezmoi diff`, `chezmoi status`, `chezmoi managed`, `chezmoi source-path`, `chezmoi execute-template`.

## Reading `chezmoi diff` — direction matters

`chezmoi diff` shows the patch that `chezmoi apply` WOULD make:

- **`-` lines = current LOCAL file content** (destination, what you have now)
- **`+` lines = SOURCE-rendered content** (what apply would write)

So if the user edited a local file and hasn't run `chezmoi add`, their new
edits appear on `-` lines (apply would remove them). The `-`/`+` symbols show
direction of apply, NOT chronology. To decide which side is newer, compare
timestamps:

```bash
stat -c '%y %n' <local-file>; chezmoi source-path <local-file> | xargs stat -c '%y %n'
```

- Local newer → user's edits should be saved to source (`chezmoi add` or edit the template)
- Source newer → changes came from git/another machine; `chezmoi apply` (with confirmation) syncs them in

When in doubt, read BOTH files directly rather than reasoning from the diff alone.

## Key commands

```bash
chezmoi add ~/.bashrc          # save local file → source (the normal direction)
chezmoi diff [file]            # what apply would change
chezmoi status                 # drifted files (MM = both sides changed, A = apply would create, M = apply would modify, R = run script)
chezmoi source-path <file>     # locate the source file (dot_*, .tmpl, executable_*, private_*)
chezmoi execute-template < x.tmpl   # preview template rendering
chezmoi managed | grep <name>  # is a file tracked?
```

Source dir: `~/.local/share/chezmoi/`. `dot_*` → `.*`, `executable_*` → +x,
`private_*` → restricted perms, `.tmpl` → Go template. This repo has
`autoCommit`/`autoPush` enabled: chezmoi operations (add/forget) commit and
push automatically, but direct edits to source files need a manual git
commit + push.

## Pull-and-apply workflow (MANDATORY when asked to pull/update)

1. `chezmoi status` — note `MM` (local changes apply would overwrite) and `DA` (local files apply would delete).
2. If any `MM`/`DA` exist: run `chezmoi diff`, show it, and **explicitly warn which local changes will be lost**. Get confirmation before continuing.
3. `chezmoi git pull`
4. `chezmoi diff` — show what the pull will apply.
5. Get explicit confirmation.
6. `chezmoi apply` (use `--force` only if chezmoi prompts interactively AND the user already confirmed).

## Local changes to a managed file

The user has usually ALREADY made the change locally and wants it saved to
source — do NOT suggest `chezmoi apply` (that would destroy their edit).

- **Plain files:** `chezmoi add <file>`.
- **Template (`.tmpl`) files:** edit the source template manually (`chezmoi add` would flatten it):
  1. Read the template first — note every `{{ if }}`/`{{ range }}` conditional and `{{ .var }}` variable.
  2. **NEVER remove template conditionals or variables** unless explicitly asked. They exist for cross-machine logic (e.g. `is_work`). If the local file differs only because of conditional logic, the local file is correct as-rendered — don't "fix" the template.
  3. Apply the user's change in the right branch of the template, preserving whitespace exactly (use `cat -A` if trailing whitespace might matter).
  4. Verify: `chezmoi diff <file>` should show nothing.
- Template changes take effect from the filesystem immediately — no git commit needed for `chezmoi diff`/`apply` to see them.

## Pitfall checklist

- Don't describe direction backwards: the local file already HAS the changes; they're being SAVED TO source.
- `chezmoi add` cannot add files that exist only in source; it copies live → source.
- File not tracked? Check `chezmoi managed | grep <name>` and `.chezmoiignore` (it's templated — test with `chezmoi execute-template < .chezmoiignore`).
- Don't manage app-rewritten files (they churn): this repo deliberately ignores `.claude/settings.json`, `.config/zed/settings.json`, `btop.conf`, `fish_variables`, `mako/config`.
- Secrets: never `chezmoi add` credentials; use chezmoi's encryption or keep them ignored.
