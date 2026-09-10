# Bedrock-scoped harness entry points: codex-bedrock and claude-bedrock.
#
# Both run the work Bedrock developer catalog (SSO profile bedrock-developer,
# us-west-2) WITHOUT touching the default auth of either harness. Everything
# is scoped to the child process:
#   - codex: a separate profile file (~/.codex/bedrock.config.toml) using
#     codex's native Amazon Bedrock provider with SigV4 from the SSO profile.
#   - claude: Bedrock env vars set only for that invocation, with the
#     personal ANTHROPIC_API_KEY unset so it cannot leak into the work call.
# Plain `codex` and `claude` keep using the OpenAI subscription and the
# claude.ai login respectively.
#
# The application inference profile ARNs live in ~/.config/bedrock-aliases.env
# (not in this public repo). Copy them from the developer managed-settings.json
# in terraform-infrastructure on a new machine.

_bedrock_sso_ensure() { # $1 = AWS profile (default bedrock-developer)
    local p=${1:-bedrock-developer}
    AWS_PROFILE=$p aws sts get-caller-identity --query Account --output text >/dev/null 2>&1 && return 0
    echo "bedrock: SSO session expired, running aws sso login --profile $p" >&2
    aws sso login --profile "$p"
}

# Bedrock account (developer role). Config is correct and signs correctly, but it
# cannot work as of 2026-09-10 and an IAM change would not fix it: codex speaks
# only the OpenAI Responses API, which rejects application inference profiles
# (400), and the catalog is AIP-only by policy (LCO-208, LCO-448). Kept so the
# 403 is reproducible; use codex-sandbox or claude-bedrock instead.
codex-bedrock() {
    _bedrock_sso_ensure bedrock-developer || return 1
    codex --profile bedrock "$@"
}

# Sandbox account via sbx-admin. Works today (no enforced guardrail there).
codex-sandbox() {
    _bedrock_sso_ensure sbx-admin || return 1
    codex --profile sandbox "$@"
}

claude-bedrock() {
    local envfile="$HOME/.config/bedrock-aliases.env"
    if [[ ! -r $envfile ]]; then
        echo "claude-bedrock: missing $envfile (see header of ~/.bashrc.d/bedrock-aliases.bashrc)" >&2
        return 1
    fi
    _bedrock_sso_ensure || return 1
    local BEDROCK_AIP_PREFIX BEDROCK_AIP_SONNET BEDROCK_AIP_OPUS BEDROCK_AIP_HAIKU
    # shellcheck source=/dev/null
    source "$envfile"
    # Same env block as the developer-tier managed-settings.json, minus the MCP
    # allowlist. Sonnet 5 default; Opus 5 and Haiku 4.5 via --model.
    env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
        CLAUDE_CODE_USE_BEDROCK=1 AWS_REGION=us-west-2 AWS_PROFILE=bedrock-developer \
        ANTHROPIC_MODEL="$BEDROCK_AIP_SONNET" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="$BEDROCK_AIP_SONNET" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="$BEDROCK_AIP_OPUS" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL="$BEDROCK_AIP_HAIKU" \
        ANTHROPIC_SMALL_FAST_MODEL="$BEDROCK_AIP_HAIKU" \
        claude "$@"
}
