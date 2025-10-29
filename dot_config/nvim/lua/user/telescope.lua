local M = {
  "nvim-telescope/telescope.nvim",
  commit = "b4da76be54691e854d3e0e02c36b0245f945c2c7",
  dependencies = {
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      commit = "1f08ed60cafc8f6168b72b80be2b2ea149813e55",
      build = "make",
      lazy = true
    },
    {
      "nvim-telescope/telescope-ui-select.nvim",
      commit = "6e51d7da30bd139a6950adf2a47fda6df9fa06d2",
    },
    {
      "nvim-lua/plenary.nvim",
      commit = "b9fd5226c2f76c951fc8ed5923d85e4de065e509",
    },
  },
  -- lazy = true,
  cmd = "Telescope",
}

function M.config()
  local wk = require "which-key"
  wk.add {
    { "<leader>bb", "<cmd>Telescope buffers<cr>", desc = "Find Buffers" },
    { "<leader>fb", "<cmd>Telescope git_branches<cr>", desc = "Checkout branch" },
    { "<leader>fc", "<cmd>Telescope colorscheme<cr>", desc = "Colorscheme" },
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>fF", "<cmd>Telescope find_files no_ignore=true<cr>", desc = "Find ALL files" },
    { "<leader>fp", "<cmd>lua require('telescope').extensions.projects.projects()<cr>", desc = "Projects" },
    { "<leader>ft", "<cmd>Telescope live_grep<cr>", desc = "Find Text" },
    { "<leader>fT", "<cmd>Telescope live_grep additional_args={'--no-ignore'}<cr>", desc = "Find ALL Text" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
    { "<leader>fl", "<cmd>Telescope resume<cr>", desc = "Last Search" },
    { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent File" },
  }

  local icons = require "user.icons"
  local actions = require "telescope.actions"

  require("telescope").setup {
    defaults = {
      prompt_prefix = icons.ui.Telescope .. " ",
      selection_caret = icons.ui.Forward .. " ",
      entry_prefix = "   ",
      initial_mode = "insert",
      selection_strategy = "reset",
      path_display = { "smart" },
      color_devicons = true,
      borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
      winblend = 0,
      vimgrep_arguments = {
        "rg",
        "--color=never",
        "--no-heading",
        "--with-filename",
        "--line-number",
        "--column",
        "--smart-case",
        "--hidden",              -- Search hidden files
        -- Respects .gitignore by default
        -- ~/.ignore file contains negation patterns to whitelist specific gitignored files
        "--glob=!.git/",         -- Always exclude .git directory
      },

      mappings = {
        i = {
          ["<C-n>"] = actions.cycle_history_next,
          ["<C-p>"] = actions.cycle_history_prev,

          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
        },
        n = {
          ["<esc>"] = actions.close,
          ["j"] = actions.move_selection_next,
          ["k"] = actions.move_selection_previous,
          ["q"] = actions.close,
        },
      },
    },
    pickers = {
      live_grep = {
        theme = "dropdown",
      },

      grep_string = {
        theme = "dropdown",
      },

      find_files = {
        theme = "dropdown",
        previewer = false,
        hidden = true,
        -- Respect .gitignore (no no_ignore flag)
        -- Use vimgrep_arguments --glob patterns above for exceptions
      },

      buffers = {
        theme = "dropdown",
        previewer = true,
        initial_mode = "normal",
        mappings = {
          i = {
            ["<C-d>"] = actions.delete_buffer,
          },
          n = {
            ["dd"] = actions.delete_buffer,
            ["<C-q>"] = actions.delete_buffer + actions.move_to_top,
          },
        },
        show_all_buffers = true,
        sort_mru = true,
        ignore_current_buffer = false,
        sort_lastused = true,
      },

      planets = {
        show_pluto = true,
        show_moon = true,
      },

      colorscheme = {
        enable_preview = true,
      },

      lsp_references = {
        theme = "dropdown",
        initial_mode = "normal",
      },

      lsp_definitions = {
        theme = "dropdown",
        initial_mode = "normal",
      },

      lsp_declarations = {
        theme = "dropdown",
        initial_mode = "normal",
      },

      lsp_implementations = {
        theme = "dropdown",
        initial_mode = "normal",
      },
    },
    extensions = {
      fzf = {
        fuzzy = true, -- false will only do exact matching
        override_generic_sorter = true, -- override the generic sorter
        override_file_sorter = true, -- override the file sorter
        case_mode = "smart_case", -- or "ignore_case" or "respect_case"
      },
      ["ui-select"] = {
        require("telescope.themes").get_dropdown({
          previewer = false,
        })
      },
    },
  }

  -- Load extensions
  require("telescope").load_extension("ui-select")

  -- Use theme default borders for telescope
end

return M
