local M = {
  "NvChad/nvim-colorizer.lua",
  commit = "51cf7c995ed1eb6642aecf19067ee634fa1b6ba2",
  event = { "BufReadPost", "BufNewFile" },
}

function M.config()
  require("colorizer").setup {
    filetypes = {
      "typescript",
      "typescriptreact",
      "javascript",
      "javascriptreact",
      "css",
      "html",
      "astro",
      "lua",
    },
    user_default_options = {
      names = false,
      rgb_fn = true,
      hsl_fn = true,
      tailwind = "both",
    },
    buftypes = {},
  }
end

return M
