local M = {
  "ThePrimeagen/harpoon",
  commit = "ed1f853847ffd04b2b61c314865665e1dadf22c7",
  event = "VeryLazy",
  dependencies = {
    {
      "nvim-lua/plenary.nvim",
      commit = "b9fd5226c2f76c951fc8ed5923d85e4de065e509",
    },
  },
}

function M.config()
  local harpoon = require("harpoon")
  
  -- Configure harpoon to use git root as project directory
  harpoon.setup({
    global_settings = {
      save_on_toggle = false,
      save_on_change = true,
    },
    projects = {
      -- Use git root as project key
      [vim.fn.getcwd()] = {
        mark = {
          marks = {},
        },
      },
    },
  })
  
  -- Override project_key to use git root
  local utils = require("harpoon.utils")
  utils.project_key = function()
    -- Get the directory of the current buffer, or cwd if no buffer
    local current_file = vim.api.nvim_buf_get_name(0)
    local search_dir = vim.fn.getcwd()
    
    if current_file and current_file ~= "" then
      search_dir = vim.fn.fnamemodify(current_file, ":h")
    end
    
    -- Try to find git root from the buffer's directory
    local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(search_dir) .. " rev-parse --show-toplevel 2>/dev/null")[1]
    if vim.v.shell_error == 0 and git_root and git_root ~= "" then
      return git_root
    end
    
    -- Fallback to current working directory
    return vim.fn.getcwd()
  end

  local keymap = vim.keymap.set
  local opts = { noremap = true, silent = true }

  keymap("n", "<s-m>", "<cmd>lua require('user.harpoon').mark_file()<cr>", opts)
  keymap("n", "<TAB>", "<cmd>lua require('harpoon.ui').toggle_quick_menu()<cr>", opts)
end

function M.mark_file()
  require("harpoon.mark").add_file()
  vim.notify "󱡅  marked file"
end

return M
