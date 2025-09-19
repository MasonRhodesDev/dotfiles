-- Native LSP configuration for Neovim 0.11+
-- Setup as dependency of neodev since we need it for Lua LSP

local M = {
  "folke/neodev.nvim",
  event = { "BufReadPre", "BufNewFile" },
}

local function lsp_keymaps(bufnr)
  local opts = { noremap = true, silent = true }
  local keymap = vim.api.nvim_buf_set_keymap
  keymap(bufnr, "n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
  keymap(bufnr, "n", "gI", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  keymap(bufnr, "n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  keymap(bufnr, "n", "gl", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
end

M.on_attach = function(client, bufnr)
  lsp_keymaps(bufnr)

  if client.supports_method "textDocument/inlayHint" then
    vim.lsp.inlay_hint.enable(true, { bufnr })
  end

  -- Enable and refresh code lens
  if client.supports_method "textDocument/codeLens" then
    vim.lsp.codelens.refresh()
    -- Auto-refresh code lens on buffer changes
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "CursorHold" }, {
      buffer = bufnr,
      callback = function()
        vim.lsp.codelens.refresh { bufnr = bufnr }
      end,
    })
  end
end

function M.common_capabilities()
  local capabilities
  local status_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if status_ok then
    capabilities = cmp_nvim_lsp.default_capabilities()
  else
    capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.completion.completionItem.snippetSupport = true
  end
  
  -- Enable code lens support
  capabilities.textDocument.codeLens = {
    dynamicRegistration = true,
  }
  
  return capabilities
end

M.toggle_inlay_hints = function()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr }, { bufnr })
end

function M.config()
  -- Setup neodev first for Lua development
  require("neodev").setup {}

  local wk = require "which-key"
  wk.add {
    { "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "Code Action" },
    {
      "<leader>lf",
      function()
        local filter
        if _G.current_project_config and _G.current_project_config.lsp_formatting and _G.current_project_config.lsp_formatting.filter then
          filter = _G.current_project_config.lsp_formatting.filter
        else
          filter = function(client)
            return client.name == 'null-ls' or (client.name ~= 'typescript-tools' and client.name ~= 'vtsls' and client.name ~= 'eslint' and client.name ~= 'vue_ls')
          end
        end
        vim.lsp.buf.format({async = true, filter = filter})
      end,
      desc = "Format",
    },
    { "<leader>lh", "<cmd>lua require('user.lspconfig').toggle_inlay_hints()<cr>", desc = "Hints" },
    { "<leader>li", "<cmd>LspInfo<cr>", desc = "Info" },
    {
      "<leader>lI",
      function()
        vim.lsp.buf.code_action({
          filter = function(action)
            return action.kind and (
              action.kind:match("source%.addMissingImports") or
              action.kind:match("quickfix%..*import") or
              action.title:lower():match("import")
            )
          end,
          apply = true,
        })
      end,
      desc = "Add Missing Imports",
    },
    { "<leader>lj", "<cmd>lua vim.diagnostic.goto_next()<cr>", desc = "Next Diagnostic" },
    { "<leader>lk", "<cmd>lua vim.diagnostic.goto_prev()<cr>", desc = "Prev Diagnostic" },
    { "<leader>ll", "<cmd>lua vim.lsp.codelens.run()<cr>", desc = "CodeLens Action" },
    { "<leader>lq", "<cmd>lua vim.diagnostic.setloclist()<cr>", desc = "Quickfix" },
    { "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "Rename" },
    { "<leader>ls", "<cmd>lua print(vim.inspect(vim.lsp.get_clients()))<cr>", desc = "LSP Status" },
  }

  wk.add {
    { "<leader>la", group = "LSP" },
    { "<leader>laa", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "Code Action", mode = "v" },
  }

  local icons = require "user.icons"

  local servers = {
    "lua_ls",
    "cssls",
    "html",
    "vtsls",
    "vue_ls",
    "eslint",
    "pyright",
    "bashls",
    "jsonls",
    "yamlls",
  }

  local default_diagnostic_config = {
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
        [vim.diagnostic.severity.WARN] = icons.diagnostics.Warning,
        [vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
        [vim.diagnostic.severity.INFO] = icons.diagnostics.Information,
      },
    },
    virtual_text = false,
    update_in_insert = false,
    underline = true,
    severity_sort = true,
    float = {
      focusable = true,
      style = "minimal",
      border = "rounded",
      source = "always",
      header = "",
      prefix = "",
      winhighlight = "FloatBorder:CustomActiveBorder",
    },
  }

  vim.diagnostic.config(default_diagnostic_config)

  -- Configure LSP UI handlers (native approach)
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
    border = "rounded",
    winhighlight = "FloatBorder:CustomActiveBorder"
  })
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
    border = "rounded",
    winhighlight = "FloatBorder:CustomActiveBorder"
  })

  -- Setup servers using native vim.lsp.config (Neovim 0.11+)
  -- No longer dependent on nvim-lspconfig plugin

  for _, server in pairs(servers) do
    local base_config = {
      on_attach = M.on_attach,
      capabilities = M.common_capabilities(),
    }

    local require_ok, settings = pcall(require, "user.lspsettings." .. server)
    if require_ok then
      base_config = vim.tbl_deep_extend("force", base_config, settings)
    end

    -- neodev already setup in config()

    -- Use native vim.lsp.config instead of lspconfig
    vim.lsp.config[server] = base_config
  end

  -- Enable all configured language servers
  vim.lsp.enable(servers)
end

return M
