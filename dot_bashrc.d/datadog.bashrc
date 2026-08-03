# Datadog API Keys (from Secret Service). timeout 2: a wedged keyring must
# not hang every new shell (parity with the retired fish conf.d/datadog.fish).
export DD_API_KEY=$(timeout 2 secret-tool lookup service datadog type api-key 2>/dev/null || echo "")
export DD_APP_KEY=$(timeout 2 secret-tool lookup service datadog type app-key 2>/dev/null || echo "")
