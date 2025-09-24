return {
  'mason-org/mason.nvim',
  commit = "7dc4facca9702f95353d5a1f87daf23d78e31c2a",
  config = function()
    -- import mason
    local mason = require 'mason'

    -- enable mason and configure icons
    mason.setup {
      ui = {
        border = 'rounded',
        winhighlight = 'FloatBorder:CustomBorder',
        icons = {
          package_installed = '✓',
          package_pending = '➜',
          package_uninstalled = '✗',
        },
      },
      -- Direct installation management (correct Mason package names)
      ensure_installed = {
        -- Language Servers (Mason package names)
        'vtsls',                        -- Modern TypeScript LSP wrapper
        'vue-language-server',          -- Vue SFC support ✓
        'html-lsp',                     -- HTML language server ✓
        'eslint-lsp',                   -- ESLint with flat config support ✓
        'css-lsp',                      -- CSS language server ✓
        'tailwindcss-language-server',  -- Tailwind CSS IntelliSense ✓
        'lua-language-server',          -- Lua language server
        'bash-language-server',         -- Bash language server
        'json-lsp',                     -- JSON language server ✓
        'yaml-language-server',         -- YAML language server ✓
        -- Debug Adapters
        'js-debug-adapter',
      },
    }

  end,
}
