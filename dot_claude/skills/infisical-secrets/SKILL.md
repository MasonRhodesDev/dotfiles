---
name: infisical-secrets
description: Where secrets and env vars live on this machine. Use it BEFORE any task needs an API key, token, password, connection string or other credential, before writing a .env, credentials, config or key file, before asking the human to paste a secret, and when a command fails for a missing env var. Secrets come from Infisical; never put them on disk or in chat.
---

# infisical-secrets: credentials come from Infisical

The human keeps secrets in **Infisical** (app.infisical.com), which they edit from the web or their
phone. A background service on this machine syncs them into every shell within about 10 seconds.
You have read-only access through a machine identity. You cannot add or change secrets yourself.

## Rules

1. **Check Infisical first.** Before asking for any credential, check whether it already exists (see
   "Checking" below). Look under likely names too (e.g. `OPENAI_API_KEY`, `OPENAI_KEY`).
2. **Never write secrets to disk.** Do not create or edit `.env`, `.env.local`, `credentials.json`,
   `~/.netrc`, `~/.npmrc` tokens, key files, or config files that contain secret values. Do not hardcode
   secrets in code, scripts, systemd units, shell rc files or Claude settings.
3. **Never ask the human to paste a secret into chat.** Ask them to add it to Infisical instead.
4. **Never print secret values.** Check that a variable is set, never what it contains. No `echo $KEY`,
   no `printenv KEY`, no `cat ~/.config/infisical/env.sh`, no `env | grep`.
5. If a tool insists on a file, prefer running it under `infisical run -- <cmd>` or reading from env vars
   (most frameworks and docker compose accept env vars). If a file truly is the only way, ask the human
   before writing it, and make sure it is gitignored.

## Checking whether a secret exists

Names only, never values:

    # which keys are synced
    grep -o '^export [A-Za-z_][A-Za-z0-9_]*' ~/.config/infisical/env.sh | cut -d' ' -f2

    # is one set in the current shell
    [ -n "${OPENAI_API_KEY+x}" ] && echo set || echo missing

Non-interactive bash (including your Bash tool) re-reads `~/.config/infisical/env.sh` on every command
via `BASH_ENV`, so a secret the human just added is visible to your next command without restarting.
If `BASH_ENV` is unset in your environment (the session was started outside a login shell), run
`. ~/.config/infisical/env.sh` at the start of the command that needs it.

## When a secret is missing

Request it through the **secret inbox**, which gives the human a one-field form on their phone that
writes straight into Infisical:

1. Open the request. Use the conventional name for the tool (what its docs or the code read), in
   UPPER_SNAKE_CASE, and say what the value is and where to get it:

       infisical-ask STRIPE_SECRET_KEY "Stripe test-mode secret key: Stripe → Developers → API keys"

   It prints a link (tailnet only, expires in 30 minutes). For rotating an existing value, add
   `--replace`.
2. Put the link in your reply so they can tap it, and also send it with the `PushNotification` tool
   (e.g. "Need STRIPE_SECRET_KEY for the payments test: <link>"); that reaches their phone when Remote
   Control is connected. Load the tool with ToolSearch if it is deferred.
3. Wait for it with `infisical-ask --wait STRIPE_SECRET_KEY` as a **background** command
   (run_in_background), so you are notified when it lands. Meanwhile continue with work that doesn't
   need the secret, or end your turn. Once it reports the key is set, carry on.

If `infisical-ask` says the inbox isn't running or reachable, fall back to asking them to add it in the
Infisical web app, and be exact:

> Please add `STRIPE_SECRET_KEY` in Infisical: environment `dev`, path `/`.
> It syncs here within about 10 seconds; tell me when it's in.

Then re-check with the commands above. If it is still missing, see Troubleshooting.

Do not work around a missing secret by generating a placeholder, using a hardcoded test key, or
creating a local file "for now".

## Other secret sources

Some machines also load a few keys from GNOME Keyring into the systemd user session at login
(`api-keys.service` → `~/.local/bin/import-api-keys`). Those are fine to use. Don't move keys between the
two or add new ones to the keyring; new secrets go in Infisical. If this machine has no
`~/.config/infisical/machine.env`, Infisical isn't set up here: say so instead of falling back to files.

## Long-running services

Run user services with secrets through the wrapper, which injects them and restarts the process when
they change in Infisical:

    ExecStart=%h/.local/bin/infisical-exec <command> [args...]

## Troubleshooting

    systemctl --user status infisical-env-sync secret-inbox
    journalctl --user -u infisical-env-sync -u secret-inbox -n 20 --no-pager

- "not a member of this project": the machine identity needs to be added to the project
  (project → Access Control → Machine Identities → Assign Existing, role Viewer). Ask the human.
- The inbox form says the write was refused: the inbox identity (`~/.config/infisical/inbox.env`) needs
  write access to the project's environment. Ask the human; never read or print that file.
- "Invalid credentials": the identity's client secret in `~/.config/infisical/machine.env` is wrong or
  revoked. Ask the human to update that file themselves; never read or print it.
- Project, environment and path come from `INFISICAL_PROJECT_ID`, `INFISICAL_ENV` and `INFISICAL_PATH`
  in that file; read them with `grep -E '^INFISICAL_(PROJECT_ID|ENV|PATH)=' ~/.config/infisical/machine.env`
  (never the client ID or secret lines).
