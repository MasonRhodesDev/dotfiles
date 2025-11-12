return {
  {
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
      }
    end,
  },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    commit = "517ef5994ef9d6b738322664d5fdd948f0fdeb46",
    dependencies = { 'mason-org/mason.nvim' },
    config = function()
      require('mason-tool-installer').setup {
        ensure_installed = {
          -- Language Servers (Mason package names)
          'vtsls',                        -- Modern TypeScript LSP wrapper
          'vue-language-server',          -- Vue SFC support
          'html-lsp',                     -- HTML language server
          'eslint-lsp',                   -- ESLint with flat config support
          'css-lsp',                      -- CSS language server
          'tailwindcss-language-server',  -- Tailwind CSS IntelliSense
          'lua-language-server',          -- Lua language server
          'bash-language-server',         -- Bash language server
          'json-lsp',                     -- JSON language server
          'yaml-language-server',         -- YAML language server
          -- Debug Adapters
          'js-debug-adapter',
        },
        auto_update = false,
        run_on_start = true,
      }
    end,
  },
}
