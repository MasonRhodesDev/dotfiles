## Git
- Never add Co-Authored-By lines for Claude on commits.
- Never create GitHub repositories without my explicit say-so. Branches, PRs, labels, and issues on existing repos are fine; if a new repo seems needed, ask first.
@work@## Writing
- Never use em dashes or en dashes in any output: chat replies, code, comments, commit messages, PR titles and descriptions, Jira tickets, Confluence pages, docs, artifacts, emails, Slack. This covers U+2014 (em), U+2013 (en), U+2015 (horizontal bar), and the ASCII `--` and `---` when they stand in for prose punctuation. Double hyphens stay legal as code: CLI flags, Lua and SQL comments, CSS custom properties, HTML comment delimiters.
- A dash in prose is an unnamed relation operator. It asserts that two chunks are related while deleting the word that says which relation it is. So the fix is to name the relation with a word (because, so, which means, then, and) or split into two sentences.
- Do not substitute a colon, semicolon, or parenthesis to preserve the same unnamed juncture. That repaints the structure instead of removing it, and counts as a violation.
- Never reproduce a dash glyph even when quoting: replace it with a codepoint placeholder like `[U+2014]`. Quoting is critique, not license to re-emit the character.
- Enforcement: the `PreToolUse` hook at `~/.claude/hooks/no-dashes.sh` denies file writes containing the glyphs, and the `Stop` hook at `~/.claude/hooks/no-dashes-chat.py` rejects chat replies containing them. Auto-memory files under `~/.claude/projects/` are exempt because the harness mandates the dash in `MEMORY.md` index lines.
- A dash in text attributed to @firstName@ is a contamination marker of LLM output, not his voice (0.7% of 679 typed prompts). Critique it; never emulate it. See `~/repos/style-fingerprint/FINGERPRINT.md`.

## Decisions and questions
- Always ask decisions through the AskUserQuestion picker, one question per call, the recommended option first and marked. Never put a decision in a numbered list in the reply body, even when a session prompt asks for a "What I need from you" list; that list is for `[do]` actions only, and decisions go to the picker.
- Why: the picker is clickable, works on the phone, and does not scroll away. Reaffirmed 2026-10-23 ("Please update globabl instructions to prefer the picker, always").

## Code comments
- Write no code comments in any language or config format. Names, types and structure carry the meaning. If code is unclear without a comment, rename, extract or retype it until it is clear.
- A comment that a tool reads is code and stays: shebangs, compiler and linter directives (`//go:embed`, `@ts-expect-error`, `# noqa`, `# shellcheck`, `// ignore:`), license and SPDX headers, markers a script greps for, template expressions, and doc text a framework turns into runtime output (clap `///` help, FastMCP or click docstrings, the `# Safety` section clippy requires). Keep only the directive itself, with no prose after it.
- Reasoning and history go in the commit message and the PR description, never in the code.

## Markdown files
- A repo holds only the markdown GitHub renders for people: the root `README.md`, `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `GOVERNANCE.md`, `PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/*`, and a nested `README.md` only in a separately published package.
- Two kinds of markdown are exempt because something reads them as their format: files an agent harness requires (`SKILL.md` and its references, `.claude/agents/*.md`, plugin prompts) and content a program loads at runtime.
- Never create any other markdown in a repo: no `AGENTS.md`, `CLAUDE.md`, ADRs or `docs/decisions/`, plans, specs, status, handoff, design notes, runbooks or changelogs. If a program needs data, use a data format such as TOML, YAML or JSON.

## Portability (every project is developed as if it will be open sourced)
- Structure every repo so a stranger could clone it and run it from the README alone, with no knowledge of my machines. Visibility stays private per the Git rules above; this is about structure, not publishing.
- Before writing any value, classify it: project detail (belongs in the repo) or environment detail (belongs outside it). Environment details include: home paths and usernames, hostnames (lab nodes, dev box, tower, printers), LAN addresses and subnets, my domain and its subdomains, device nodes and serials, specific hardware (GPU, monitors, controllers), account names, API endpoints and tokens, notification topics, the distro or package manager I happen to use, and absolute paths into my other repos.
- Environment details enter through one boundary: an env var, a CLI flag, or a config file whose committed form is a generic `.example` with a gitignored local override. Committed defaults are generic, localhost, or empty, never my values.
- My values live in the gitignored local override, or in the private dotfiles repo when they are per-machine. They never live in the repo's defaults, scripts, CI, Dockerfiles, Nomad jobs, tests, fixtures, docs, comments, or commit messages.
- Build and run tooling counts too. If a Makefile, script, justfile, or CI job only works on my box (assumes a tool is installed, a path exists, a service is reachable), that is the same leak as a hardcoded IP.
- Before committing, scan the diff for the patterns above. A hit outside an example file or a gitignored override is a bug to fix, not a note to leave.
- If a feature genuinely cannot be generic, say so explicitly and isolate it behind the boundary with a named option, rather than letting personal and general details blend in the same file.

@machine@## Secrets
- Secrets and credentials come from Infisical. Load the `infisical-secrets` skill before handling any API key, token, password or other credential, and never write secrets to disk, hardcode them, print them, or ask me to paste them into chat. If one is missing, ask me to add it in Infisical.

## References
- Mermaid/PDF generation: see `~/.claude/references/mermaid-pdf.md`
- Hyprland / hyprwm ecosystem (C++ style guide, conventions, best practices): see `~/.claude/references/hyprland/`, starting with `README.md`. Read before any C++ work touching hyprtoolkit, hyprlang, hyprutils, or Hyprland plugins.
@private@
