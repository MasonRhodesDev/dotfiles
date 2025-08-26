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

