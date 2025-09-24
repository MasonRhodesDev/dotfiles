local M = {
  "nvim-tree/nvim-tree.lua",
  commit = "e179ad2f83b5955ab0af653069a493a1828c2697",
}

local function tree_keymaps(bufnr)
  local opts = { noremap = true, silent = true }
  local keymap = vim.api.nvim_buf_set_keymap
  
  -- Telescope commands
  keymap(bufnr, "n", "<leader>ff", "<cmd>Telescope find_files<cr>", opts)
  keymap(bufnr, "n", "<leader>ft", "<cmd>Telescope live_grep<cr>", opts)
  keymap(bufnr, "n", "<leader>fb", "<cmd>Telescope git_branches<cr>", opts)
  keymap(bufnr, "n", "<leader>fc", "<cmd>Telescope colorscheme<cr>", opts)
  keymap(bufnr, "n", "<leader>fh", "<cmd>Telescope help_tags<cr>", opts)
  keymap(bufnr, "n", "<leader>fl", "<cmd>Telescope resume<cr>", opts)
  keymap(bufnr, "n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", opts)
  keymap(bufnr, "n", "<leader>bb", "<cmd>Telescope buffers previewer=false<cr>", opts)
  
  -- Other common commands
  keymap(bufnr, "n", "<leader>gg", "<cmd>Neogit<cr>", opts)
  keymap(bufnr, "n", "<leader>q", "<cmd>confirm q<cr>", opts)
  keymap(bufnr, "n", "<leader>h", "<cmd>nohlsearch<cr>", opts)
  keymap(bufnr, "n", "<leader>;", "<cmd>tabnew | terminal<cr>", opts)
  keymap(bufnr, "n", "<leader>v", "<cmd>vsplit<cr>", opts)
  
  -- Harpoon
  keymap(bufnr, "n", "<TAB>", "<cmd>lua require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())<cr>", opts)
end

local function on_attach(bufnr)
  local api = require('nvim-tree.api')
  
  -- Default mappings
  api.config.mappings.default_on_attach(bufnr)
  
  -- Add our leader key mappings
  tree_keymaps(bufnr)
end

function M.config()
  local wk = require "which-key"
  wk.add {
    { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "Explorer" },
  }

  local icons = require "user.icons"

  require("nvim-tree").setup {
    on_attach = on_attach,
    hijack_netrw = true,
    sync_root_with_cwd = true,
    hijack_directories = {
      enable = true,
      auto_open = true,
    },
    view = {
      relativenumber = true,
    },
    renderer = {
      add_trailing = false,
      group_empty = false,
      highlight_git = false,
      full_name = false,
      highlight_opened_files = "none",
      root_folder_label = ":t",
      indent_width = 2,
      indent_markers = {
        enable = false,
        inline_arrows = true,
        icons = {
          corner = "└",
          edge = "│",
          item = "│",
          none = " ",
        },
      },
      icons = {
        git_placement = "before",
        padding = " ",
        symlink_arrow = " ➛ ",
        web_devicons = {
          file = {
            enable = true,
            color = true,
          },
          folder = {
            enable = false,
            color = true,
          },
        },
        glyphs = {
          default = icons.ui.Text,
          symlink = icons.ui.FileSymlink,
          bookmark = icons.ui.BookMark,
          folder = {
            arrow_closed = icons.ui.ChevronRight,
            arrow_open = icons.ui.ChevronShortDown,
            default = icons.ui.Folder,
            open = icons.ui.FolderOpen,
            empty = icons.ui.EmptyFolder,
            empty_open = icons.ui.EmptyFolderOpen,
            symlink = icons.ui.FolderSymlink,
            symlink_open = icons.ui.FolderOpen,
          },
          git = {
            unstaged = icons.git.FileUnstaged,
            staged = icons.git.FileStaged,
            unmerged = icons.git.FileUnmerged,
            renamed = icons.git.FileRenamed,
            untracked = icons.git.FileUntracked,
            deleted = icons.git.FileDeleted,
            ignored = icons.git.FileIgnored,
          },
        },
      },
      special_files = { "Cargo.toml", "Makefile", "README.md", "readme.md" },
      symlink_destination = true,
    },
    update_focused_file = {
      enable = true,
      debounce_delay = 15,
      update_root = true,
      ignore_list = {},
    },

    diagnostics = {
      enable = true,
      show_on_dirs = false,
      show_on_open_dirs = true,
      debounce_delay = 50,
      severity = {
        min = vim.diagnostic.severity.HINT,
        max = vim.diagnostic.severity.ERROR,
      },
      icons = {
        hint = icons.diagnostics.BoldHint,
        info = icons.diagnostics.BoldInformation,
        warning = icons.diagnostics.BoldWarning,
        error = icons.diagnostics.BoldError,
      },
    },
  }
end

return M
