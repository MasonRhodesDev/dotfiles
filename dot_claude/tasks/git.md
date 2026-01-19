# Git Operations

## Commit Guidelines

- Offer to commit after completing work, wait for confirmation
- Descriptive messages (focus on "why" not "what")
- Use git status/diff to stage all changes
- Retry commits once if pre-commit hooks make changes
- NO attribution footers (no "Generated with Claude Code", no Co-Authored-By)

## Safety Rules

- NEVER update the git config
- NEVER run destructive/irreversible git commands (like push --force, hard reset, etc) unless the user explicitly requests them
- NEVER skip hooks (--no-verify, --no-gpg-sign, etc) unless the user explicitly requests it
- NEVER run force push to main/master, warn the user if they request it
- NEVER use git commands with the -i flag (interactive commands not supported)

## Commit Process

1. Run `git status` and `git diff` to see changes
2. Review all staged changes
3. Draft concise commit message
4. Add relevant untracked files to staging
5. Create commit
6. Run `git status` after to verify success
7. If pre-commit hook fails, fix the issue and create a NEW commit (don't amend)

## Pull Request Creation

Use `gh` command for GitHub operations:
1. Review full commit history since branch divergence
2. Analyze all changes across commits
3. Push to remote with `-u` flag if needed
4. Create PR with format:
```
gh pr create --title "title" --body "$(cat <<'EOF'
## Summary
<bullet points>

## Test plan
[checklist]
EOF
)"
```
