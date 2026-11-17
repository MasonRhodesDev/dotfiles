_bedrock_sso_ensure() {
    local p=${1:-bedrock-developer}
    AWS_PROFILE=$p aws sts get-caller-identity --query Account --output text >/dev/null 2>&1 && return 0
    echo "bedrock: SSO session expired, running aws sso login --profile $p" >&2
    aws sso login --profile "$p"
}

codex-bedrock() {
    _bedrock_sso_ensure bedrock-developer || return 1
    codex --profile bedrock "$@"
}

pi-bedrock() {
    local envfile="$HOME/.config/bedrock-aliases.env"
    if [[ ! -r $envfile ]]; then
        echo "pi-bedrock: missing $envfile (see header of ~/.bashrc.d/bedrock-aliases.bashrc)" >&2
        return 1
    fi
    _bedrock_sso_ensure bedrock-developer || return 1
    local BEDROCK_AIP_PREFIX BEDROCK_AIP_SONNET BEDROCK_AIP_OPUS BEDROCK_AIP_HAIKU
    local BEDROCK_AIP_GPT_TERRA BEDROCK_AIP_GPT_SOL BEDROCK_AIP_GPT_LUNA
    # shellcheck source=/dev/null
    source "$envfile"
    local map
    map=$(printf '{"aip.gpt-5.6-terra":"%s","aip.gpt-5.6-sol":"%s","aip.gpt-5.6-luna":"%s",' \
            "$BEDROCK_AIP_GPT_TERRA" "$BEDROCK_AIP_GPT_SOL" "$BEDROCK_AIP_GPT_LUNA"
          printf '"aip.claude-sonnet-5":"%s","aip.claude-opus-5":"%s","aip.claude-haiku-4-5":"%s"}' \
            "$BEDROCK_AIP_SONNET" "$BEDROCK_AIP_OPUS" "$BEDROCK_AIP_HAIKU")
    AWS_PROFILE=bedrock-developer AWS_REGION=us-west-2 PI_BEDROCK_MODEL_MAP="$map" \
        pi --provider amazon-bedrock --model aip.gpt-5.6-terra --models "amazon-bedrock/aip.*" "$@"
}

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
    env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
        CLAUDE_CODE_USE_BEDROCK=1 AWS_REGION=us-west-2 AWS_PROFILE=bedrock-developer \
        ANTHROPIC_MODEL="$BEDROCK_AIP_SONNET" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="$BEDROCK_AIP_SONNET" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="$BEDROCK_AIP_OPUS" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL="$BEDROCK_AIP_HAIKU" \
        ANTHROPIC_SMALL_FAST_MODEL="$BEDROCK_AIP_HAIKU" \
        claude "$@"
}
