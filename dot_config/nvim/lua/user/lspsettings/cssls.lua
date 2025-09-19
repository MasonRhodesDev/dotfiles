-- CSS Language Server configuration
-- Fixes MethodNotFound errors for workspace/diagnostic/refresh

return {
  cmd = { 'vscode-css-language-server', '--stdio' },
  filetypes = { 'css', 'scss', 'less' },
  root_markers = { 'package.json', '.git' },
  settings = {
    css = {
      validate = true,
    },
    less = {
      validate = true,
    },
    scss = {
      validate = true,
    },
  },
  -- Disable workspace diagnostic refresh capability to fix MethodNotFound errors
  capabilities = (function()
    local capabilities = require('cmp_nvim_lsp').default_capabilities()
    capabilities.workspace = capabilities.workspace or {}
    capabilities.workspace.diagnosticRefresh = false
    return capabilities
  end)(),
}