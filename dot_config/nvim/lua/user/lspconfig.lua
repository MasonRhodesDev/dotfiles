-- Native LSP configuration using vim.lsp.config (Neovim 0.11+)
-- nvim-lspconfig kept only for neodev compatibility

local M = {
  "neovim/nvim-lspconfig",
  commit = "b3cce1419ca67871ae782b3e529652f8a016f0de",
  event = { "BufReadPre", "BufNewFile" },
  priority = 400,
  dependencies = {
    {
      "folke/neodev.nvim",
      commit = "46aa467dca16cf3dfe27098042402066d2ae242d",
    },
  },
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

M.diagnostic_with_spell = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local line = cursor_pos[1] - 1
  local col = cursor_pos[2]

  -- Get LSP diagnostics
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line })
  local has_diagnostics = false

  for _, diag in ipairs(diagnostics) do
    if diag.col <= col and col <= diag.end_col then
      has_diagnostics = true
      break
    end
  end

  -- Check for spell errors if spell is enabled
  local has_spell_error = false
  if vim.wo.spell then
    local spell_result = vim.fn.spellbadword()
    has_spell_error = spell_result[1] ~= ""
  end

  -- Prioritize: spell error > LSP diagnostic
  if has_spell_error then
    -- Get spelling suggestions and show in picker
    local spell_result = vim.fn.spellbadword()
    local word = spell_result[1]
    local suggestions = vim.fn.spellsuggest(word, 20)

    if #suggestions == 0 then
      vim.notify("No spelling suggestions for '" .. word .. "'", vim.log.levels.INFO)
      return
    end

    -- Add special options
    table.insert(suggestions, 1, "[Add to dictionary]")
    table.insert(suggestions, 2, "[Ignore]")

    vim.ui.select(suggestions, {
      prompt = "Spelling suggestions for '" .. word .. "':",
    }, function(choice)
      if not choice then
        return
      end

      if choice == "[Add to dictionary]" then
        vim.cmd("normal! zg")
      elseif choice == "[Ignore]" then
        vim.cmd("normal! zG")
      else
        -- Replace word with selected suggestion
        local col_start = vim.fn.col(".")
        vim.cmd("normal! ciw" .. choice)
        vim.cmd("stopinsert")
      end
    end)
  elseif has_diagnostics then
    -- Show LSP diagnostics
    vim.diagnostic.open_float()
  else
    -- No issues at cursor, show general diagnostic float
    vim.diagnostic.open_float()
  end
end

M.goto_next_spell = function()
  if not vim.wo.spell then
    vim.notify("Spell check is not enabled", vim.log.levels.WARN)
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor_pos[1]
  local current_col = cursor_pos[2]

  -- Move cursor forward by one character to start search
  vim.fn.cursor(current_line, current_col + 1)

  local search_result = vim.fn.search('\\<\\k*\\>', 'W')
  while search_result ~= 0 do
    local spell_result = vim.fn.spellbadword()
    if spell_result[1] ~= "" then
      -- Found a spelling error, cursor is already positioned
      return
    end
    search_result = vim.fn.search('\\<\\k*\\>', 'W')
  end

  -- No more spelling errors found, restore position
  vim.api.nvim_win_set_cursor(0, cursor_pos)
  vim.notify("No more spelling errors", vim.log.levels.INFO)
end

M.goto_prev_spell = function()
  if not vim.wo.spell then
    vim.notify("Spell check is not enabled", vim.log.levels.WARN)
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)

  local search_result = vim.fn.search('\\<\\k*\\>', 'bW')
  while search_result ~= 0 do
    local spell_result = vim.fn.spellbadword()
    if spell_result[1] ~= "" then
      -- Found a spelling error, cursor is already positioned
      return
    end
    search_result = vim.fn.search('\\<\\k*\\>', 'bW')
  end

  -- No more spelling errors found, restore position
  vim.api.nvim_win_set_cursor(0, cursor_pos)
  vim.notify("No more spelling errors", vim.log.levels.INFO)
end

function M.config()
  -- Setup neodev for Lua development (requires lspconfig.util)
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

  -- Servers that need to start first (VTSLS before Vue LS)
  local priority_servers = {
    "vtsls",
  }

  local servers = {
    "lua_ls",
    "cssls",
    "html",
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
  -- Configure priority servers first (VTSLS before Vue)
  for _, server in pairs(priority_servers) do
    local base_config = {
      on_attach = M.on_attach,
      capabilities = M.common_capabilities(),
    }

    local require_ok, settings = pcall(require, "user.lspsettings." .. server)
    if require_ok then
      base_config = vim.tbl_deep_extend("force", base_config, settings)
    end

    vim.lsp.config[server] = base_config
    vim.lsp.enable(server)
  end

  -- Configure remaining servers
  for _, server in pairs(servers) do
    local base_config = {
      on_attach = M.on_attach,
      capabilities = M.common_capabilities(),
    }

    local require_ok, settings = pcall(require, "user.lspsettings." .. server)
    if require_ok then
      base_config = vim.tbl_deep_extend("force", base_config, settings)
    end

    vim.lsp.config[server] = base_config
    vim.lsp.enable(server)
  end
end

return M
