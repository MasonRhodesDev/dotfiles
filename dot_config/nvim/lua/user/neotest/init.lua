local M = {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-treesitter/nvim-treesitter",
    -- general tests
    "vim-test/vim-test",
    "nvim-neotest/neotest-vim-test",
    -- language specific tests
    "marilari88/neotest-vitest",
    "nvim-neotest/neotest-python",
    "nvim-neotest/neotest-plenary",
    "rouge8/neotest-rust",
    "lawrence-laz/neotest-zig",
    "rcasia/neotest-bash",
    -- jest only loaded via project-local config in lifemd
    "nvim-neotest/neotest-jest",
  },
}

local function get_vitest_adapter()
  local vitest_config = require("user.neotest.adapters.vitest")
  local create_vitest_wrapper = require("user.neotest.adapters.vitest-enhanced")
  
  -- Use wrapper that adds directory support while keeping everything else
  return create_vitest_wrapper(vitest_config)
end

function M.config()
  local wk = require "which-key"
  wk.add {
    { "<leader>t", group = "Test" },
    { "<leader>tt", "<cmd>lua require'neotest'.run.run()<cr>", desc = "Test Nearest" },
    { "<leader>tf", "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<cr>", desc = "Test File" },
    { "<leader>td", "<cmd>lua require('neotest').run.run({strategy = 'dap'})<cr>", desc = "Debug Test" },
    { "<leader>ts", "<cmd>lua require('neotest').run.stop()<cr>", desc = "Test Stop" },
    { "<leader>ta", "<cmd>lua require('neotest').run.attach()<cr>", desc = "Attach Test" },
    { "<leader>to", "<cmd>lua require('neotest').output.open({ enter = true, auto_close = true })<cr>", desc = "Test Output" },
    { "<leader>tO", "<cmd>lua require('neotest').output_panel.toggle()<cr>", desc = "Test Output Panel" },
    { "<leader>tS", "<cmd>lua require('neotest').summary.toggle()<cr>", desc = "Test Summary" },
    { "<leader>tw", "<cmd>lua require('neotest').watch.toggle(vim.fn.expand('%'))<cr>", desc = "Test Watch" },
  }

  -- Cache for neotest configurations
  local config_cache = {}
  local last_configured_dir = ""

  -- Get git repository identifier for project-based configuration
  local function get_git_repo_id(project_root)
    if not project_root or vim.fn.isdirectory(project_root .. "/.git") ~= 1 then
      return nil
    end
    
    -- Get git remote origin URL
    local cmd = string.format("cd %s && git config --get remote.origin.url 2>/dev/null", vim.fn.shellescape(project_root))
    local remote_url = vim.fn.system(cmd)
    
    if vim.v.shell_error ~= 0 or not remote_url or remote_url == "" then
      return nil
    end
    
    -- Normalize the URL to a consistent format
    remote_url = remote_url:gsub("\n", "")  -- Remove newlines
    
    -- Convert SSH to HTTPS format and remove .git suffix
    remote_url = remote_url:gsub("git@([^:]+):", "https://%1/")  -- SSH to HTTPS
    remote_url = remote_url:gsub("%.git$", "")  -- Remove .git suffix
    remote_url = remote_url:gsub("^https://", "")  -- Remove protocol
    
    return remote_url
  end

  -- Search upward for .neotest.lua configuration file (fallback)
  local function find_neotest_config(start_dir)
    local dir = start_dir or vim.fn.getcwd()
    local original_dir = dir
    
    -- Check cache first
    if config_cache[original_dir] then
      return config_cache[original_dir]
    end
    
    -- Search upward
    while dir ~= "/" do
      local config_file = dir .. "/.neotest.lua"
      if vim.fn.filereadable(config_file) == 1 then
        config_cache[original_dir] = config_file
        return config_file
      end
      
      -- Stop at git root to avoid searching too far
      if vim.fn.isdirectory(dir .. "/.git") == 1 then
        break
      end
      
      dir = vim.fn.fnamemodify(dir, ":h")
    end
    
    -- Cache negative result
    config_cache[original_dir] = nil
    return nil
  end

  -- Load and apply project-specific neotest configuration
  local function configure_neotest(force)
    local cwd = vim.fn.getcwd()
    
    -- Skip if already configured for this directory (unless forced)
    if not force and last_configured_dir == cwd then
      return
    end
    
    last_configured_dir = cwd
    
    -- Start with base adapters
    local adapters = {
      require "neotest-python" {
        dap = { justMyCode = false },
      },
      require "neotest-zig",
      require "neotest-vim-test" {
        ignore_file_types = { "python", "vim", "lua", "javascript", "typescript" },
      },
    }

    -- Default to suppressing notifications unless explicitly enabled
    local suppress_notifications = true
    local project_config = nil
    
    -- Find git repository root (walk up from current directory to find .git)
    local function find_git_root(start_path)
      local path = start_path or cwd
      while path ~= "/" do
        if vim.fn.isdirectory(path .. "/.git") == 1 then
          return path
        end
        path = vim.fn.fnamemodify(path, ":h")
      end
      return nil
    end
    
    -- Always use git root for repository-based configuration
    local git_root = find_git_root(cwd)
    local git_repo_id = nil
    
    if git_root then
      git_repo_id = get_git_repo_id(git_root)
    end
    -- Check for git-based configuration first
    if git_repo_id then
      local ok, project_configs = pcall(require, "config.neotest_projects")
      if ok then
        project_config = project_configs[git_repo_id]
        
        if project_config and not suppress_notifications then
          vim.notify("📁 Loading git-based neotest config for: " .. git_repo_id, vim.log.levels.INFO)
        end
      else
        vim.notify("❌ Failed to load neotest project configs: " .. tostring(project_configs), vim.log.levels.WARN)
      end
    end
    
    -- Fall back to .neotest.lua file if no git-based config
    if not project_config then
      local config_file = find_neotest_config()
      
      if config_file then
        -- Load the configuration file
        package.loaded[config_file] = nil
        local ok, loaded_config = pcall(dofile, config_file)
        if ok and loaded_config then
          project_config = loaded_config
          if not suppress_notifications then
            vim.notify("📁 Loading file-based neotest config: " .. config_file, vim.log.levels.INFO)
          end
        else
          vim.notify("❌ Failed to load neotest config: " .. config_file, vim.log.levels.WARN)
        end
      end
    end
    
    -- Apply project configuration if found
    if project_config then
      -- Check if notifications should be enabled (default is suppressed)
      if project_config.suppress_notifications == false then
        suppress_notifications = false
      end
      
      -- Check if project config wants to disable base adapters
      if project_config.disable_base_adapters then
        adapters = {}
        if not suppress_notifications then
          vim.notify("🚫 Disabled all base adapters per project config", vim.log.levels.INFO)
        end
      end
      
      if project_config.adapters then
        vim.list_extend(adapters, project_config.adapters)
        if not suppress_notifications then
          vim.notify("✅ Loaded " .. #project_config.adapters .. " project-specific adapter(s)", vim.log.levels.INFO)
        end
      end
    else
      -- Default: add vitest for JS/TS projects
      table.insert(adapters, get_vitest_adapter())
      if not suppress_notifications then
        vim.notify("🧪 Using default configuration (vitest)", vim.log.levels.INFO)
      end
    end

    -- Setup neotest with final adapter configuration
    if not suppress_notifications then
      vim.notify("🔧 Final adapters: " .. vim.inspect(vim.tbl_map(function(a) 
        return type(a) == "table" and (a.name or "unknown") or tostring(a):match("neotest%-(%w+)") or "unknown"
      end, adapters)), vim.log.levels.INFO)
    end
    
    ---@diagnostic disable: missing-fields
    require("neotest").setup {
      adapters = adapters,
    }
    
    if not suppress_notifications then
      vim.notify("🚀 neotest configured with " .. #adapters .. " adapter(s)", vim.log.levels.INFO)
    end
  end

  -- Initial configuration
  configure_neotest()

  -- Reconfigure when directory changes or buffer enters
  local function trigger_reconfigure(event_name)
    -- Small delay to let project.nvim settle
    vim.defer_fn(function()
      configure_neotest(true)  -- Force reconfiguration
    end, 200)  -- Longer delay for project.nvim
  end

  vim.api.nvim_create_autocmd("DirChanged", {
    callback = function(ev)
      trigger_reconfigure("DirChanged")
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.test.js,*.test.ts,*.spec.js,*.spec.ts",
    callback = function(ev)
      trigger_reconfigure("BufEnter")
    end,
  })
end

return M