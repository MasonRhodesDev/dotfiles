local M = {
  "MeanderingProgrammer/render-markdown.nvim",
  commit = "10126effbafb74541b69219711dfb2c631e7ebf8",
  ft = { "markdown" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
}

function M.config()
  require("render-markdown").setup {
    -- Render in normal, command, and terminal modes
    render_modes = { "n", "c", "t" },

    -- Heading icons and highlights
    headings = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },

    -- Code block style
    code = {
      sign = false,
      width = "block",
      right_pad = 1,
    },

    -- Table style
    pipe_table = {
      preset = "round",
    },
  }
end

return M
