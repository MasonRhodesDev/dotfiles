local M = {
  "windwp/nvim-autopairs",
  commit = "23320e75953ac82e559c610bec5a90d9c6dfa743",
}

M.config = function()
  require("nvim-autopairs").setup {
    check_ts = true,
    disable_filetype = { "TelescopePrompt", "spectre_panel" },
  }
end

return M
