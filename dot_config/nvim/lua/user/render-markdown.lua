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
    render_modes = { "n", "c", "t" },

    headings = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },

    code = {
      sign = false,
      width = "block",
      right_pad = 1,
    },

    pipe_table = {
      preset = "round",
    },
  }
end

return M
