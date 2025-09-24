local M = {
  "LunarVim/breadcrumbs.nvim",
  commit = "9f764278784ce2f10dbe2f555ba14be2451d36a0",
}

function M.config()
  require("breadcrumbs").setup()
end

return M
