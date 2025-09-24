-- ESLint LSP configuration for 2025 with flat config support
-- Supports TypeScript, Vue, and modern ESLint 9 features

return {
  cmd = { 'vscode-eslint-language-server', '--stdio' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'javascript.jsx',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
    'vue',
  },
  root_markers = {
    '.eslintrc.js', '.eslintrc.json', '.eslintrc.yml', '.eslintrc.yaml',
    'eslint.config.js', 'eslint.config.mjs', 'eslint.config.cjs',
    'package.json', '.git'
  },
  settings = {
    packageManager = 'npm',
    useESLintClass = false,
    experimental = {
      useFlatConfig = true,
    },
    codeActionOnSave = {
      enable = true,
      mode = 'all'
    },
    format = { enable = true },
    lint = { enable = true },
    problems = {
      shortenToSingleLine = false,
    },
    quiet = false,
    onIgnoredFiles = 'off',
    -- Support for ESLint 9 flat config files
    options = {
      configFile = nil, -- Auto-detect eslint.config.js
    },
  },
  -- Fix workspace folder capability warning
  capabilities = (function()
    local capabilities = require('cmp_nvim_lsp').default_capabilities()
    capabilities.workspace = capabilities.workspace or {}
    capabilities.workspace.didChangeWorkspaceFolders = {
      dynamicRegistration = false,
    }
    return capabilities
  end)(),
  -- Auto-fix on save setup
  on_attach = function(client, bufnr)
    -- Enable auto-fix on save for supported file types
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = bufnr,
      callback = function()
        vim.lsp.buf.code_action({
          context = {
            only = { 'source.fixAll.eslint' },
            diagnostics = {},
          },
          apply = true,
        })
      end,
      desc = 'Auto-fix ESLint issues on save',
    })
  end,
}