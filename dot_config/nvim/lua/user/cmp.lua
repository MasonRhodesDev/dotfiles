local M = {
  "hrsh7th/nvim-cmp",
  commit = "b5311ab3ed9c846b585c0c15b7559be131ec4be9",
  event = "InsertEnter",
  dependencies = {
    {
      "hrsh7th/cmp-nvim-lsp",
      commit = "bd5a7d6db125d4654b50eeae9f5217f24bb22fd3",
      event = "InsertEnter",
    },
    {
      "hrsh7th/cmp-emoji",
      commit = "e8398e2adf512a03bb4e1728ca017ffeac670a9f",
      event = "InsertEnter",
    },
    {
      "hrsh7th/cmp-buffer",
      commit = "b74fab3656eea9de20a9b8116afa3cfc4ec09657",
      event = "InsertEnter",
    },
    {
      "hrsh7th/cmp-path",
      commit = "c642487086dbd9a93160e1679a1327be111cbc25",
      event = "InsertEnter",
    },
    {
      "hrsh7th/cmp-cmdline",
      commit = "d126061b624e0af6c3a556428712dd4d4194ec6d",
      event = "InsertEnter",
    },
    {
      "saadparwaiz1/cmp_luasnip",
      commit = "98d9cb5c2c38532bd9bdb481067b20fea8f32e90",
      event = "InsertEnter",
    },
    {
      "L3MON4D3/LuaSnip",
      commit = "b3104910bb5ebf40492aadffae18f2528fa757d9",
      event = "InsertEnter",
      dependencies = {
        {
          "rafamadriz/friendly-snippets",
          commit = "572f5660cf05f8cd8834e096d7b4c921ba18e175",
        },
      },
    },
    {
      "hrsh7th/cmp-nvim-lua",
      commit = "f12408bdb54c39c23e67cab726264c10db33ada8",
    },
  },
}

function M.config()
  local cmp = require "cmp"
  local luasnip = require "luasnip"
  require("luasnip/loaders/from_vscode").lazy_load()

  vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })
  vim.api.nvim_set_hl(0, "CmpItemKindTabnine", { fg = "#CA42F0" })
  vim.api.nvim_set_hl(0, "CmpItemKindEmoji", { fg = "#FDE030" })

  local check_backspace = function()
    local col = vim.fn.col "." - 1
    return col == 0 or vim.fn.getline("."):sub(col, col):match "%s"
  end

  local icons = require "user.icons"

  cmp.setup {
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body) -- For `luasnip` users.
      end,
    },
    mapping = cmp.mapping.preset.insert {
      ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "c" }),
      ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "c" }),
      ["<Down>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "c" }),
      ["<Up>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "c" }),
      ["<C-b>"] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
      ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),
      ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
      ["<C-e>"] = cmp.mapping {
        i = cmp.mapping.abort(),
        c = cmp.mapping.close(),
      },
      -- Accept currently selected item. If none selected, `select` first item.
      -- Set `select` to `false` to only confirm explicitly selected items.
      ["<CR>"] = cmp.mapping.confirm { select = true },
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.expandable() then
          luasnip.expand()
        elseif luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        elseif check_backspace() then
          fallback()
          -- require("neotab").tabout()
        else
          fallback()
          -- require("neotab").tabout()
        end
      end, {
        "i",
        "s",
      }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, {
        "i",
        "s",
      }),
    },
    formatting = {
      fields = { "kind", "abbr", "menu" },
      format = function(entry, vim_item)
        vim_item.kind = icons.kind[vim_item.kind]
        vim_item.menu = ({
          nvim_lsp = "",
          nvim_lua = "",
          luasnip = "",
          buffer = "",
          path = "",
          emoji = "",
          minuet = "󰧑",
        })[entry.source.name]

        if entry.source.name == "emoji" then
          vim_item.kind = icons.misc.Smiley
          vim_item.kind_hl_group = "CmpItemKindEmoji"
        end

        if entry.source.name == "cmp_tabnine" then
          vim_item.kind = icons.misc.Robot
          vim_item.kind_hl_group = "CmpItemKindTabnine"
        end

        if entry.source.name == "minuet" then
          vim_item.kind = icons.misc.Robot
          vim_item.kind_hl_group = "CmpItemKindTabnine"
        end


        return vim_item
      end,
    },
    sources = {
      { name = "nvim_lsp" },
      { name = "luasnip" },
      { name = "cmp_tabnine" },
      { name = "nvim_lua" },
      { name = "buffer" },
      { name = "path" },
      { name = "calc" },
      { name = "emoji" },
    },
    confirm_opts = {
      behavior = cmp.ConfirmBehavior.Replace,
      select = false,
    },
    window = {
      completion = {
        border = "rounded",
        scrollbar = false,
        winhighlight = "FloatBorder:CustomActiveBorder",
      },
      documentation = {
        border = "rounded",
        winhighlight = "FloatBorder:CustomActiveBorder",
      },
    },
    experimental = {
      ghost_text = false,
    },
  }
end

return M
