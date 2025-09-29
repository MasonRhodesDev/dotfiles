-- Vue Language Server configuration for 2025
-- Handles Vue SFC templates, styles, and Vue-specific features
-- Works in hybrid mode with vtsls for TypeScript support

return {
  cmd = { 'vue-language-server', '--stdio' },
  filetypes = { 'vue' },
  root_markers = { 'package.json', 'vue.config.js', 'vite.config.js', 'nuxt.config.js', '.git' },
  settings = {
    vue = {
      -- Enable all modern inlay hints for Vue
      inlayHints = {
        destructuredProps = { enabled = true },
        inlineHandlerLoading = { enabled = true },
        missingProps = { enabled = true },
        optionsWrapper = { enabled = true },
        vBindShorthand = { enabled = true },
      },
      codeLens = {
        references = true,
        pugTools = true,
        scriptSetupTools = true,
        showReferencesNotification = true,
      },
      -- Enhanced Vue-specific features
      completion = {
        casing = {
          tags = 'kebab',
          props = 'camel'
        },
      },
      format = {
        enable = true,
        options = {
          tabSize = 2,
          insertSpaces = true,
        },
      },
      validation = {
        template = true,
        style = true,
        script = false, -- Let vtsls handle TypeScript validation
        templateProps = true,
        interpolation = true,
      },
      -- Disable hybrid mode - both vtsls and vue_ls are active
      hybridMode = false,
      server = {
        maxProjectSize = 20971520, -- 20MB
      },
    },
  },
  -- Configure to work with vtsls as TypeScript provider
  init_options = {
    typescript = {
      tsdk = vim.fn.expand('$MASON/packages/vtsls/node_modules/typescript/lib')
    },
  },
}