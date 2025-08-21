local M = {
  "williamboman/mason-lspconfig.nvim",
  commit = "56e435e09f8729af2d41973e81a0db440f8fe9c9", -- Compatible with Neovim 0.10.4
  dependencies = {
    "williamboman/mason.nvim",
  },
}

function M.config()
  local servers = {
    "lua_ls",
    "cssls",
    "html",
    "tsserver",
    "volar",
    "pyright",
    "bashls",
    "jsonls",
    "eslint",
    "yamlls",
  }

  require("mason").setup {
    ui = {
      border = "rounded",
    },
  }

  require("mason-lspconfig").setup {
    ensure_installed = servers,
  }
end

return M
