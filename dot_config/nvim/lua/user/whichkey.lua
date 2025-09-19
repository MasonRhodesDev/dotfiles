local M = {
  "folke/which-key.nvim",
  event = "VimEnter",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
}

function M.config()
  local which_key = require "which-key"

  -- Create sticky buffer navigation
  local function sticky_buffer_nav(initial_direction)
    local sticky_active = false

    local function navigate(direction)
      if direction == "next" then
        vim.cmd("bnext")
      else
        vim.cmd("bprevious")
      end

      -- Show buffer name
      local bufname = vim.fn.bufname("%")
      local filename = vim.fn.fnamemodify(bufname, ":t")
      if filename == "" then
        filename = "[No Name]"
      end

      -- Display buffer info with navigation hint
      vim.notify("Buffer: " .. filename .. " (n=next, p=prev, ESC=exit)", vim.log.levels.INFO, { timeout = 1000 })

      -- Only set up keymaps if not already active
      if not sticky_active then
        sticky_active = true

        -- Set up global temporary keymaps
        vim.keymap.set("n", "n", function() navigate("next") end, { silent = true })
        vim.keymap.set("n", "p", function() navigate("prev") end, { silent = true })
        vim.keymap.set("n", "<Esc>", function()
          -- Clear temporary keymaps
          pcall(vim.keymap.del, "n", "n")
          pcall(vim.keymap.del, "n", "p")
          pcall(vim.keymap.del, "n", "<Esc>")
          sticky_active = false
          vim.notify("", vim.log.levels.INFO, { timeout = 1 })
        end, { silent = true })
      end
    end

    return function()
      navigate(initial_direction)
    end
  end

  local navigate_next = sticky_buffer_nav("next")
  local navigate_prev = sticky_buffer_nav("prev")

  which_key.setup {
    preset = "modern",
    delay = 500,  -- Show after 500ms
    plugins = {
      marks = true,
      registers = true,
      spelling = {
        enabled = true,
        suggestions = 20,
      },
      presets = {
        operators = false,
        motions = false,
        text_objects = false,
        windows = false,
        nav = false,
        z = false,
        g = false,
      },
    },
    win = {
      padding = { 2, 2, 2, 2 },
      border = "rounded",
      wo = {
        winblend = 0,
      },
    },
  }

  -- Add keymaps after setup
  which_key.add {
    { "<leader>q", "<cmd>confirm q<CR>", desc = "Quit" },
    { "<leader>h", "<cmd>nohlsearch<CR>", desc = "NOHL" },
    { "<leader>;", "<cmd>tabnew | terminal<CR>", desc = "Term" },
    { "<leader>v", "<cmd>vsplit<CR>", desc = "Split" },
    { "<leader>b", group = "Buffers" },
    { "<leader>d", group = "Debug" },
    { "<leader>f", group = "Find" },
    { "<leader>g", group = "Git" },
    { "<leader>l", group = "LSP" },
    { "<leader>p", group = "Plugins" },
    { "<leader>t", group = "Test" },
    { "<leader>a", group = "AI" },
    { "<leader>T", group = "Treesitter" },
  }

  -- Buffer management keymaps
  which_key.add {
    { "<leader>bc", "<cmd>bd<CR>", desc = "Close Buffer" },
    { "<leader>bC", "<cmd>bd!<CR>", desc = "Force Close Buffer" },
    { "<leader>ba", "<cmd>%bd|e#<CR>", desc = "Close All But Current" },
    { "<leader>bA", "<cmd>%bd!|e#<CR>", desc = "Force Close All But Current" },
    { "<leader>bn", navigate_next, desc = "Next Buffer (Sticky)" },
    { "<leader>bp", navigate_prev, desc = "Previous Buffer (Sticky)" },
    { "<leader>bd", "<cmd>bdelete<CR>", desc = "Delete Buffer" },
    { "<leader>bD", "<cmd>bdelete!<CR>", desc = "Force Delete Buffer" },
    { "<leader>br", "<cmd>e!<CR>", desc = "Reload Buffer (Discard Changes)" },
    { "<leader>bs", "<cmd>w<CR>", desc = "Save Buffer" },
    { "<leader>bS", "<cmd>wa<CR>", desc = "Save All Buffers" },
    { "<leader>bl", "<cmd>Telescope buffers<CR>", desc = "List Buffers" },
    { "<leader>bm", "<cmd>set modified<CR>", desc = "Mark Modified" },
    { "<leader>bM", "<cmd>set nomodified<CR>", desc = "Mark Unmodified" },
  }
end

return M
