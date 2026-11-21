local M = {
  "nvim-lualine/lualine.nvim",
  commit = "b8c23159c0161f4b89196f74ee3a6d02cdc3a955",
  dependencies = {
    {
      "AndreM222/copilot-lualine",
      commit = "6bc29ba1fcf8f0f9ba1f0eacec2f178d9be49333",
    },
  },
}

function M.config()
  require("lualine").setup {
    options = {
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
      ignore_focus = { "NvimTree" },
    },
    sections = {
      lualine_a = {},
      lualine_b = { "branch" },
      lualine_c = {
        "diagnostics",
        {
          'filename',
          path = 1, -- Show relative path
          shorting_target = 0, -- Don't shorten the path
        }
      },
      lualine_x = { "copilot", "filetype" },
      lualine_y = { "progress" },
      lualine_z = {},
    },
    extensions = { "quickfix", "man", "fugitive" },
  }
end

return M
