# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Neovim Configuration Architecture

This Neovim configuration uses **lazy.nvim** plugin manager with a modular architecture for maintainability and organization.

## Key Commands

### Plugin Management
- `:Lazy` - Open lazy.nvim plugin manager
- `:Lazy sync` - Update/install/clean plugins
- `:Lazy profile` - Profile startup time

### LSP Operations
- `<leader>la` - LSP code action
- `gd` - Go to definition
- `gr` - Show references  
- `K` - Show hover documentation
- `gl` - Show diagnostic float

### Telescope (Fuzzy Finding)
- `<leader>ff` - Find files
- `<leader>ft` - Find text (live grep)
- `<leader>fb` - Git branches
- `<leader>bb` - Find buffers

## Configuration Structure

### Core Files
- `init.lua` - Entry point, loads user modules
- `lua/user/launch.lua` - Defines the `spec()` function for lazy loading
- `lua/user/lazy.lua` - Lazy.nvim setup and configuration

### Module Loading Pattern
```lua
-- In init.lua
spec "user.telescope"  -- Loads lua/user/telescope.lua as lazy plugin spec
require "user.options" -- Loads immediately (settings, keymaps, autocmds)
```

### Plugin Architecture
Each plugin file (`lua/user/*.lua`) returns a lazy.nvim plugin specification:
```lua
local M = {
  "plugin/repository",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "other-plugin" },
}

function M.config()
  -- Plugin configuration
end

return M
```

### Key Directories
- `lua/user/` - Main plugin configurations
- `lua/user/lspsettings/` - Language server specific settings
- `lua/user/extras/` - Optional/experimental plugins

## Development Workflow

### Adding New Plugins
1. Create new file in `lua/user/new-plugin.lua` 
2. Add `spec "user.new-plugin"` to `init.lua`
3. Run `:Lazy sync` to install

### LSP Configuration
- Language servers managed through `mason.lua` + `lspconfig.lua`
- Server-specific settings in `lua/user/lspsettings/`
- Common capabilities and keymaps defined in `lspconfig.lua:22`

### Testing Configuration
- Use `:checkhealth` for diagnostics
- `:Lazy profile` for performance analysis
- Test new plugins in isolated branch before main integration