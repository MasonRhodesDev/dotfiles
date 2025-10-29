vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    vim.cmd "set formatoptions-=cro"
  end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = {
    "netrw",
    "Jaq",
    "qf",
    "git",
    "help",
    "man",
    "lspinfo",
    "oil",
    "spectre_panel",
    "lir",
    "DressingSelect",
    "tsplayground",
    "",
  },
  callback = function()
    vim.cmd [[
      nnoremap <silent> <buffer> q :close<CR>
      set nobuflisted
    ]]
  end,
})

vim.api.nvim_create_autocmd({ "CmdWinEnter" }, {
  callback = function()
    vim.cmd "quit"
  end,
})

vim.api.nvim_create_autocmd({ "VimResized" }, {
  callback = function()
    vim.cmd "tabdo wincmd ="
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  pattern = { "!vim" },
  callback = function()
    vim.cmd "checktime"
  end,
})

vim.api.nvim_create_autocmd({ "TextYankPost" }, {
  callback = function()
    vim.highlight.on_yank { higroup = "Visual", timeout = 40 }
  end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "gitcommit", "markdown", "NeogitCommitMessage" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true

    -- Spell checking keymaps (buffer-local)
    local opts = { noremap = true, silent = true, buffer = true }
    vim.keymap.set("n", "gl", "<cmd>lua require('user.lspconfig').diagnostic_with_spell()<CR>", opts)
    vim.keymap.set("n", "gj", "<cmd>lua require('user.lspconfig').goto_next_spell()<CR>", opts)
    vim.keymap.set("n", "gk", "<cmd>lua require('user.lspconfig').goto_prev_spell()<CR>", opts)
  end,
})

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    local status_ok, luasnip = pcall(require, "luasnip")
    if not status_ok then
      return
    end
    if luasnip.expand_or_jumpable() then
      -- ask maintainer for option to make this silent
      -- luasnip.unlink_current()
      vim.cmd [[silent! lua require("luasnip").unlink_current()]]
    end
  end,
})

-- Custom filetype detection for Hyprland config files
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = {
    "*/chezmoi/dot_config/hypr/*.conf",
    "*/chezmoi/dot_config/hypr/*.conf.tmpl", 
    "*/chezmoi/dot_config/hypr/configs/*.conf",
    "*/chezmoi/dot_config/hypr/configs/*.conf.tmpl",
    "*/.config/hypr/*.conf",
    "*/.config/hypr/configs/*.conf"
  },
  callback = function()
    vim.bo.filetype = 'hypr'
  end,
})

-- Set working directory early before plugins load, then let existing logic handle git repos
vim.api.nvim_create_augroup("EarlyWorkingDir", { clear = true })
vim.api.nvim_create_autocmd("VimEnter", {
  group = "EarlyWorkingDir",
  once = true,
  callback = function()
    local arg = vim.fn.argv(0)
    if arg and arg ~= "" then
      local path = vim.fn.fnamemodify(arg, ":p")
      local target_path = path
      
      -- If it's a file, use its directory
      if vim.fn.isdirectory(path) == 0 then
        target_path = vim.fn.fnamemodify(path, ":h")
      end
      
      -- Check if it's in a git repo and find the root
      local git_root = vim.fn.system("cd " .. vim.fn.shellescape(target_path) .. " && git rev-parse --show-toplevel 2>/dev/null")
      git_root = vim.trim(git_root)
      
      if vim.v.shell_error == 0 and git_root ~= "" then
        vim.cmd("cd " .. vim.fn.fnameescape(git_root))
      elseif vim.fn.isdirectory(path) == 1 then
        -- Only change to directory if we explicitly opened a directory
        vim.cmd("cd " .. vim.fn.fnameescape(path))
      end
    end
  end,
})

-- Highlight active/inactive windows
vim.api.nvim_create_autocmd({"WinEnter", "BufEnter"}, {
  callback = function()
    local ft = vim.bo.filetype
    if ft ~= "opencode" and ft ~= "claudecode" and ft ~= "opencode_terminal" and ft ~= "opencode_ask" then
      vim.opt_local.cursorline = true
      vim.opt_local.relativenumber = true
    end
  end
})

vim.api.nvim_create_autocmd({"WinLeave", "BufLeave"}, {
  callback = function()
    vim.opt_local.cursorline = false
    vim.opt_local.relativenumber = false
  end
})

vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
  pattern = {"opencode", "claudecode", "opencode_terminal", "opencode_ask"},
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.numberwidth = 1
    vim.opt_local.foldcolumn = "0"
    vim.opt_local.statuscolumn = ""
    vim.opt_local.sidescrolloff = 0
  end,
})

-- Custom filetype detection for .tmpl files (chezmoi templates)
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = "*.tmpl",
  callback = function()
    local filename = vim.fn.expand("%:t")
    local filepath = vim.fn.expand("%:p")
    local real_ext = filename:match('%.([^%.]+)%.tmpl$')
    if real_ext then
      -- Special case for Hyprland config files in chezmoi
      if real_ext == 'conf' and filepath:match('/chezmoi/dot_config/hypr/') then
        vim.bo.filetype = 'hypr'
        return
      end

      -- Map common extensions to filetypes
      local ext_to_filetype = {
        lua = 'lua',
        js = 'javascript',
        ts = 'typescript',
        py = 'python',
        sh = 'sh',
        bash = 'bash',
        zsh = 'zsh',
        css = 'css',
        html = 'html',
        json = 'json',
        yaml = 'yaml',
        yml = 'yaml',
        toml = 'toml',
        xml = 'xml',
        sql = 'sql',
        md = 'markdown',
        txt = 'text',
        conf = 'conf',
        config = 'conf',
        ini = 'dosini',
        vim = 'vim',
        go = 'go',
        rs = 'rust',
        c = 'c',
        cpp = 'cpp',
        h = 'c',
        hpp = 'cpp',
      }

      local filetype = ext_to_filetype[real_ext]
      if filetype then
        vim.bo.filetype = filetype
      end
    end
  end,
})

-- Refresh syntax highlighting after Treesitter loads
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  callback = function(args)
    if args.data == "nvim-treesitter" then
      vim.schedule(function()
        -- Refresh all current buffers to apply Treesitter highlighting
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
            vim.api.nvim_buf_call(buf, function()
              -- Force refresh the buffer highlighting
              vim.cmd([[edit!]])
            end)
          end
        end
      end)
    end
  end,
})

-- Force highlighting refresh for buffers that load before Treesitter is ready
vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "" then
      -- Check if Treesitter is available and has highlighting for this filetype
      local ts_available, ts_highlight = pcall(require, "nvim-treesitter.highlight")
      if ts_available and ts_highlight then
        local has_parser = pcall(vim.treesitter.get_parser, buf)
        if has_parser then
          -- Treesitter is ready, force a highlight refresh
          vim.schedule(function()
            vim.api.nvim_buf_call(buf, function()
              vim.cmd([[TSBufEnable highlight]])
            end)
          end)
        end
      end
    end
  end,
})

-- Note: First buffer syntax highlighting issue was caused by session restoration
-- timing - fixed in session.lua post_restore_cmds instead of here

