# Neovim Configuration Documentation

Complete guide to the Neovim setup with lazy.nvim plugin management, LSP integration, and development workflow optimization.

## Overview

This Neovim configuration provides:
- **Modern plugin management** - lazy.nvim with modular loading
- **Complete LSP integration** - Language servers for multiple languages
- **Intelligent completion** - nvim-cmp with multiple sources
- **File navigation** - Telescope fuzzy finder and nvim-tree
- **Development tools** - Git integration, debugging, formatting
- **Theme integration** - Dynamic theming with system colors

## Configuration Structure

```
~/.config/nvim/
├── init.lua                 # Entry point and core settings
├── lazy-lock.json          # Plugin version lockfile
├── lua/user/               # Modular configuration
│   ├── launch.lua          # Core Neovim settings
│   ├── lazy.lua            # Plugin manager setup
│   ├── keymaps.lua         # Custom keybindings
│   ├── autocmds.lua        # Autocommands
│   ├── colorscheme.lua     # Theme configuration
│   ├── lspconfig.lua       # LSP client configuration
│   ├── cmp.lua             # Completion configuration
│   ├── telescope.lua       # Fuzzy finder setup
│   ├── nvimtree.lua        # File explorer
│   ├── gitsigns.lua        # Git integration
│   ├── lualine.lua         # Status line
│   └── extras/             # Additional configurations
│       ├── dap.lua         # Debug adapter protocol
│       ├── formatter.lua   # Code formatting
│       └── snippets.lua    # Code snippets
└── lspsettings/            # LSP server configurations
    ├── lua_ls.json         # Lua language server
    ├── tsserver.json       # TypeScript server
    └── ...
```

## Plugin Management

### lazy.nvim Setup

The configuration uses [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management:

```lua
-- lua/user/lazy.lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("user", {
  defaults = { lazy = true },
  install = { colorscheme = { "theme", "habamax" } },
  checker = { enabled = true },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "matchit", "matchparen", "netrwPlugin",
        "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
```

### Plugin Loading Strategy

Plugins are loaded using the `spec()` function for lazy loading:

```lua
-- Example plugin specification
return {
  spec = function()
    return {
      {
        "nvim-telescope/telescope.nvim",
        cmd = "Telescope",
        dependencies = { "nvim-lua/plenary.nvim" },
        opts = {
          defaults = {
            prompt_prefix = " ",
            selection_caret = " ",
          },
        },
      },
    }
  end,
}
```

## Language Server Protocol (LSP)

### LSP Configuration

The setup provides comprehensive LSP support:

```lua
-- lua/user/lspconfig.lua
local servers = {
  "lua_ls",           -- Lua
  "tsserver",         -- TypeScript/JavaScript  
  "pyright",          -- Python
  "rust_analyzer",    -- Rust
  "clangd",          -- C/C++
  "gopls",           -- Go
  "html",            -- HTML
  "cssls",           -- CSS
  "jsonls",          -- JSON
  "yamlls",          -- YAML
  "marksman",        -- Markdown
}
```

### Mason Integration

Automatic LSP server installation with Mason:

```lua
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = servers,
  automatic_installation = true,
})
```

### Custom LSP Settings

Server-specific configurations in `lspsettings/`:

**lua_ls.json:**
```json
{
  "Lua": {
    "diagnostics": {
      "globals": ["vim"]
    },
    "workspace": {
      "library": {
        "${3rd}/luv/library": true,
        "${3rd}/busted/library": true
      }
    }
  }
}
```

**tsserver.json:**
```json
{
  "typescript": {
    "preferences": {
      "includePackageJsonAutoImports": "auto"
    }
  },
  "javascript": {
    "preferences": {
      "includePackageJsonAutoImports": "auto"
    }
  }
}
```

## Completion System

### nvim-cmp Configuration

Intelligent completion with multiple sources:

```lua
-- lua/user/cmp.lua
local cmp = require("cmp")

cmp.setup({
  snippet = {
    expand = function(args)
      require("luasnip").lsp_expand(args.body)
    end,
  },
  sources = cmp.config.sources({
    { name = "nvim_lsp" },      -- LSP completions
    { name = "luasnip" },       -- Snippet completions
    { name = "buffer" },        -- Buffer text
    { name = "path" },          -- File paths
    { name = "nvim_lua" },      -- Neovim Lua API
  }),
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping.select_next_item(),
    ["<S-Tab>"] = cmp.mapping.select_prev_item(),
  }),
})
```

### Snippet Engine

LuaSnip integration for code snippets:

```lua
-- Custom snippets example
local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.add_snippets("lua", {
  s("fn", {
    t("local function "), i(1, "name"), t("("), i(2), t(")"),
    t({"", "  "}), i(3, "-- body"),
    t({"", "end"}),
  }),
})
```

## File Navigation

### Telescope Fuzzy Finder

Powerful file and content searching:

```lua
-- lua/user/telescope.lua
require("telescope").setup({
  defaults = {
    prompt_prefix = " ",
    selection_caret = " ",
    mappings = {
      i = {
        ["<C-j>"] = "move_selection_next",
        ["<C-k>"] = "move_selection_previous",
        ["<Esc>"] = "close",
      },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
    },
  },
})
```

### Key Bindings for Telescope

```lua
-- Telescope keymaps
vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>")
vim.keymap.set("n", "<leader>fg", ":Telescope live_grep<CR>")
vim.keymap.set("n", "<leader>fb", ":Telescope buffers<CR>")
vim.keymap.set("n", "<leader>fh", ":Telescope help_tags<CR>")
vim.keymap.set("n", "<leader>fr", ":Telescope oldfiles<CR>")
vim.keymap.set("n", "<leader>fc", ":Telescope colorscheme<CR>")
```

### File Explorer (nvim-tree)

Integrated file browser:

```lua
-- lua/user/nvimtree.lua
require("nvim-tree").setup({
  view = {
    width = 30,
    side = "left",
  },
  renderer = {
    group_empty = true,
    icons = {
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
        git = true,
      },
    },
  },
  filters = {
    dotfiles = false,
    custom = { ".git", "node_modules" },
  },
})
```

## Git Integration

### Gitsigns

Git change indicators and navigation:

```lua
-- lua/user/gitsigns.lua
require("gitsigns").setup({
  signs = {
    add = { text = "│" },
    change = { text = "│" },
    delete = { text = "_" },
    topdelete = { text = "‾" },
    changedelete = { text = "~" },
  },
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns
    
    -- Navigation
    vim.keymap.set("n", "]c", gs.next_hunk, { buffer = bufnr })
    vim.keymap.set("n", "[c", gs.prev_hunk, { buffer = bufnr })
    
    -- Actions
    vim.keymap.set("n", "<leader>hs", gs.stage_hunk, { buffer = bufnr })
    vim.keymap.set("n", "<leader>hr", gs.reset_hunk, { buffer = bufnr })
    vim.keymap.set("n", "<leader>hp", gs.preview_hunk, { buffer = bufnr })
  end,
})
```

### Neogit

Advanced Git interface:

```lua
-- Git interface
vim.keymap.set("n", "<leader>gg", ":Neogit<CR>")
vim.keymap.set("n", "<leader>gc", ":Neogit commit<CR>")
vim.keymap.set("n", "<leader>gp", ":Neogit push<CR>")
```

## Theme and Appearance

### Dynamic Theme Integration

The configuration integrates with the system theme:

```lua
-- lua/user/colorscheme.lua
local function apply_theme()
  -- Read system theme colors
  local theme_file = os.getenv("HOME") .. "/.config/matugen/colors.json"
  local file = io.open(theme_file, "r")
  
  if file then
    local content = file:read("*all")
    file:close()
    
    local colors = vim.json.decode(content)
    
    -- Apply colors to Neovim
    vim.api.nvim_set_hl(0, "Normal", { 
      bg = colors.colors.background,
      fg = colors.colors.on_background 
    })
    vim.api.nvim_set_hl(0, "Visual", { 
      bg = colors.colors.primary 
    })
    -- More highlight groups...
  end
end

-- Auto-apply theme on changes
vim.api.nvim_create_autocmd("User", {
  pattern = "ThemeChanged",
  callback = apply_theme,
})
```

### Transparency Support

Background transparency configuration:

```lua
-- lua/user/bg.lua
local bg_transparent = true

local function toggle_transparency()
  bg_transparent = not bg_transparent
  
  if bg_transparent then
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "none" })
  else
    -- Restore background colors
    apply_theme()
  end
end

vim.keymap.set("n", "<leader>bg", toggle_transparency)
```

## Key Bindings

### Leader Key Configuration

```lua
-- Set leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "
```

### Essential Keymaps

**File Operations:**
```lua
vim.keymap.set("n", "<leader>w", ":w<CR>")          -- Save file
vim.keymap.set("n", "<leader>q", ":q<CR>")          -- Quit
vim.keymap.set("n", "<leader>x", ":x<CR>")          -- Save and quit
```

**Window Management:**
```lua
vim.keymap.set("n", "<C-h>", "<C-w>h")              -- Move left
vim.keymap.set("n", "<C-j>", "<C-w>j")              -- Move down
vim.keymap.set("n", "<C-k>", "<C-w>k")              -- Move up
vim.keymap.set("n", "<C-l>", "<C-w>l")              -- Move right
```

**LSP Keymaps:**
```lua
vim.keymap.set("n", "gd", vim.lsp.buf.definition)        -- Go to definition
vim.keymap.set("n", "gr", vim.lsp.buf.references)        -- Find references
vim.keymap.set("n", "K", vim.lsp.buf.hover)              -- Show documentation
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)    -- Rename symbol
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action) -- Code actions
```

## Development Features

### Debug Adapter Protocol (DAP)

Debugging integration:

```lua
-- lua/user/extras/dap.lua
local dap = require("dap")

-- Node.js debugging
dap.adapters.node2 = {
  type = "executable",
  command = "node",
  args = { os.getenv("HOME") .. "/.local/share/nvim/dap/vscode-node-debug2/out/src/nodeDebug.js" },
}

dap.configurations.javascript = {
  {
    name = "Launch",
    type = "node2",
    request = "launch",
    program = "${file}",
    cwd = vim.fn.getcwd(),
    sourceMaps = true,
    protocol = "inspector",
    console = "integratedTerminal",
  },
}

-- Debug keymaps
vim.keymap.set("n", "<F5>", dap.continue)
vim.keymap.set("n", "<F10>", dap.step_over)
vim.keymap.set("n", "<F11>", dap.step_into)
vim.keymap.set("n", "<F12>", dap.step_out)
vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint)
```

### Code Formatting

Automatic code formatting:

```lua
-- lua/user/extras/formatter.lua
require("formatter").setup({
  filetype = {
    lua = { require("formatter.filetypes.lua").stylua },
    javascript = { require("formatter.filetypes.javascript").prettier },
    typescript = { require("formatter.filetypes.typescript").prettier },
    python = { require("formatter.filetypes.python").black },
    rust = { require("formatter.filetypes.rust").rustfmt },
  },
})

-- Auto-format on save
vim.api.nvim_create_autocmd("BufWritePost", {
  command = "FormatWrite",
})
```

## Claude Code Integration

### Claude Code Plugin

```lua
-- lua/user/claudecode.lua
return {
  spec = function()
    return {
      {
        dir = "~/.local/share/nvim/lazy/claudecode.nvim",
        name = "claudecode.nvim",
        opts = {
          claude_api_key = "your-api-key-here", -- Or use environment variable
          model = "claude-3-sonnet-20240229",
          max_tokens = 4000,
        },
        config = function(_, opts)
          require("claudecode").setup(opts)
        end,
        keys = {
          { "<leader>cc", ":ClaudeCode<CR>", desc = "Open Claude Code" },
          { "<leader>ce", ":ClaudeExplain<CR>", desc = "Explain code" },
          { "<leader>cr", ":ClaudeRefactor<CR>", desc = "Refactor code" },
        },
      },
    }
  end,
}
```

## Performance Optimization

### Lazy Loading

Plugins are loaded only when needed:

```lua
-- Example of conditional loading
{
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPost", "BufNewFile" },
  build = ":TSUpdate",
}

{
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
  },
}
```

### Startup Time Optimization

```lua
-- Disable unused built-in plugins
vim.g.loaded_gzip = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1
```

## Troubleshooting

### Common Issues

**LSP not working:**
```bash
# Check LSP status
:LspInfo

# Check Mason installations
:Mason

# Manually install server
:MasonInstall lua-language-server
```

**Slow startup:**
```bash
# Profile startup time
nvim --startuptime startup.log

# Check plugin loading
:Lazy profile
```

**Theme not applying:**
```bash
# Check colorscheme
:colorscheme

# Reload theme
:source ~/.config/nvim/lua/user/colorscheme.lua
```

### Configuration Validation

```lua
-- Check configuration health
:checkhealth

-- Validate specific components
:checkhealth lsp
:checkhealth mason
:checkhealth telescope
```

## Customization Tips

### Adding New Languages

1. **Add LSP server to Mason:**
```lua
-- In lspconfig.lua, add to servers table
local servers = {
  -- ... existing servers
  "new_language_server",
}
```

2. **Configure formatting:**
```lua
-- In formatter.lua
filetype = {
  -- ... existing filetypes
  newlang = { require("formatter.filetypes.newlang").formatter },
}
```

3. **Add file type detection:**
```lua
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = {"*.newext"},
  callback = function()
    vim.bo.filetype = "newlang"
  end,
})
```

### Custom Plugins

```lua
-- Example custom plugin spec
return {
  spec = function()
    return {
      {
        "author/plugin-name",
        config = function()
          require("plugin-name").setup({
            -- Plugin configuration
          })
        end,
        keys = {
          { "<leader>cp", ":PluginCommand<CR>", desc = "Plugin command" },
        },
      },
    }
  end,
}
```

---

This Neovim configuration provides a modern, efficient development environment with comprehensive language support, intelligent completion, and seamless integration with the system theme and workflow.