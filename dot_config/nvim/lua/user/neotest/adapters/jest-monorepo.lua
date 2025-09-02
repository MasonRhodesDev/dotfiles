local lib = require("neotest.lib")

-- Generic Jest monorepo adapter factory
local function create_adapter(config)
  config = config or {}
  
  -- Default configuration
  local default_config = {
    name = "jest-monorepo",
    monorepo_patterns = {},  -- e.g. { "/repos/lifemd/", "/workspace/myproject/" }
    package_roots = {},      -- e.g. { "patient-portal", "physician-portal", "packages/*" }
    jest_command = { "npm", "test", "--" },
    auto_detect_package_root = true,
  }
  
  -- Merge config with defaults
  for k, v in pairs(default_config) do
    if config[k] == nil then
      config[k] = v
    end
  end
  
  local adapter = { name = config.name }

  -- Check if this is a test file
  adapter.is_test_file = function(file_path)
    if not file_path then return false end
    
    -- Check if it's a test file pattern
    local is_test_pattern = file_path:match("%.test%.js$") 
                         or file_path:match("%.test%.ts$")
                         or file_path:match("%.spec%.js$")
                         or file_path:match("%.spec%.ts$")
    
    if not is_test_pattern then return false end
    
    -- Check if we're in one of the configured monorepo patterns
    if #config.monorepo_patterns == 0 then
      return true  -- No patterns specified, accept all test files
    end
    
    for _, pattern in ipairs(config.monorepo_patterns) do
      if file_path:match(pattern) then
        return true
      end
    end
    
    return false
  end

  -- Find project root for this file
  adapter.root = function(path)
    return lib.files.match_root_pattern("package.json", ".git")(path)
  end

  -- Check if a path is ignored by git
  local function is_git_ignored(path, root)
    local cmd = string.format("cd %s && git check-ignore %s", vim.fn.shellescape(root), vim.fn.shellescape(path))
    local result = vim.fn.system(cmd)
    local is_ignored = vim.v.shell_error == 0
    
    return is_ignored
  end

  -- Filter directories to improve performance and reduce clutter
  adapter.filter_dir = function(name, rel_path, root)
    -- Skip only the most essential excludes to keep tests working
    local skip_dirs = {
      "node_modules",
      ".git", 
      ".next",
      "dist", 
      "build",
      "coverage",
      ".turbo",
      ".cache"
    }
    
    for _, skip in ipairs(skip_dirs) do
      if name == skip then
        return false
      end
    end
    
    -- Skip directories that start with . (hidden directories)  
    if name:match("^%.") then
      return false
    end
    
    return true
  end

  -- Discover test positions
  adapter.discover_positions = function(path)
    -- Ensure we have the full absolute path
    local full_path = vim.fn.fnamemodify(path, ":p")
    
    -- Read the file content directly to ensure it's loaded
    local content = lib.files.read(full_path)
    if not content or content == "" then
      return lib.treesitter.parse_positions_from_string(full_path, "", "", {})
    end
    
    local query = [[
      ; -- Namespaces --
      ; Matches: `describe('context', () => {})`
      ((call_expression
        function: (identifier) @func_name (#eq? @func_name "describe")
        arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
      )) @namespace.definition
      ; Matches: `describe('context', function() {})`
      ((call_expression
        function: (identifier) @func_name (#eq? @func_name "describe")
        arguments: (arguments (string (string_fragment) @namespace.name) (function_expression))
      )) @namespace.definition

      ; -- Tests --
      ; Matches: `test('test') / it('test')`
      ((call_expression
        function: (identifier) @func_name (#any-of? @func_name "it" "test")
        arguments: (arguments (string (string_fragment) @test.name) [(arrow_function) (function_expression) (call_expression)])
      )) @test.definition
    ]]
    
    local positions = lib.treesitter.parse_positions_from_string(full_path, content, query, {
      nested_tests = false,
    })
    
    return positions
  end

  -- Find the package root directory for jest execution
  local function find_package_root(file_path)
    if config.auto_detect_package_root then
      -- Walk up from the file path to find the nearest package.json with jest config
      local current_dir = vim.fn.fnamemodify(file_path, ":h")
      
      while current_dir ~= "/" do
        local package_json = current_dir .. "/package.json"
        
        if vim.fn.filereadable(package_json) == 1 then
          local content = vim.fn.readfile(package_json)
          local json_str = table.concat(content, "\n")
          
          -- Check for jest-related dependencies or config
          local has_jest = string.match(json_str, '"jest"') 
                        or string.match(json_str, '"@thecvlb/config%-jest"')
                        or string.match(json_str, '"ts%-jest"')
          
          -- Also check for jest config files in this directory
          local jest_configs = vim.fn.glob(current_dir .. "/jest.config.*", false, true)
          local has_jest_config = #jest_configs > 0
          
          if has_jest or has_jest_config then
            return current_dir
          end
        end
        
        -- Stop at git root to avoid going too far up
        if vim.fn.isdirectory(current_dir .. "/.git") == 1 then
          break
        end
        
        current_dir = vim.fn.fnamemodify(current_dir, ":h")
      end
    end
    
    -- Fallback: check configured package roots
    for _, package_root in ipairs(config.package_roots) do
      if file_path:match("/" .. package_root .. "/") then
        -- Extract the package root path
        local root_pattern = "(.*/" .. package_root .. ")"
        local package_dir = file_path:match(root_pattern)
        if package_dir and vim.fn.isdirectory(package_dir) == 1 then
          return package_dir
        end
      end
    end
    
    -- Final fallback: use the adapter root
    return adapter.root(file_path)
  end

  -- Build the jest command
  adapter.build_spec = function(args)
    local position = args.tree:data()
    local file_path = position.path
    
    -- Find the appropriate package directory
    local package_dir = find_package_root(file_path)
    
    local command = vim.deepcopy(config.jest_command)
    
    -- Handle different position types
    if position.type == "file" then
      -- Running tests for a specific file
      local test_file = vim.fn.fnamemodify(file_path, ":.")
      if package_dir then
        -- Make the test file path relative to the package directory
        local package_name = vim.fn.fnamemodify(package_dir, ":t")
        if file_path:find("/" .. package_name .. "/") then
          test_file = file_path:match(".*/" .. package_name .. "/(.*)")
        end
      end
      
      if test_file then
        table.insert(command, test_file)
      end
      
    elseif position.type == "dir" then
      -- Running tests for a directory - let Jest find all tests in that directory
      local test_dir = vim.fn.fnamemodify(file_path, ":.")
      if package_dir then
        -- Make the directory path relative to the package directory
        local package_name = vim.fn.fnamemodify(package_dir, ":t")
        if file_path:find("/" .. package_name .. "/") then
          test_dir = file_path:match(".*/" .. package_name .. "/(.*)")
        end
      end
      
      if test_dir then
        -- Jest pattern to run all tests in directory and subdirectories
        table.insert(command, test_dir .. "/**/*.(test|spec).(js|ts)")
      end
      
    else
      -- For root or other types, run all tests (no specific file/directory filter)
      -- Jest will find all tests in the package
    end
    
    -- Add test name filters if running specific tests
    if position.type == "test" then
      -- For individual test, also specify the file
      local test_file = vim.fn.fnamemodify(file_path, ":.")
      if package_dir then
        local package_name = vim.fn.fnamemodify(package_dir, ":t")
        if file_path:find("/" .. package_name .. "/") then
          test_file = file_path:match(".*/" .. package_name .. "/(.*)")
        end
      end
      if test_file then
        table.insert(command, test_file)
      end
      table.insert(command, "--testNamePattern=" .. position.name)
    elseif position.type == "namespace" then
      -- For namespace, also specify the file
      local test_file = vim.fn.fnamemodify(file_path, ":.")
      if package_dir then
        local package_name = vim.fn.fnamemodify(package_dir, ":t")
        if file_path:find("/" .. package_name .. "/") then
          test_file = file_path:match(".*/" .. package_name .. "/(.*)")
        end
      end
      if test_file then
        table.insert(command, test_file)
      end
      table.insert(command, "--testNamePattern=" .. position.name)
    end
    
    local spec = {
      command = command,
      cwd = package_dir,
      context = {
        file = position.path,
        position_id = position.id,
      }
    }
    
    -- DAP debugging support 
    local function get_dap_config(strategy, command, cwd)
      local config = {
        dap = function()
          return {
            name = "Debug Jest Tests",
            type = "pwa-node",
            request = "launch", 
            args = { unpack(command, 2) },
            runtimeExecutable = command[1],
            console = "integratedTerminal",
            internalConsoleOptions = "neverOpen",
            rootPath = "${workspaceFolder}",
            cwd = cwd or "${workspaceFolder}",
            skipFiles = {
              "<node_internals>/**"
            },
          }
        end,
      }
      if config[strategy] then
        return config[strategy]()
      end
    end
    
    spec.strategy = get_dap_config(args.strategy, command, package_dir)
    
    return spec
  end

  -- Parse test results
  adapter.results = function(spec, result, tree)
    local output = result.output
    local results = {}
    
    -- If tests passed (exit code 0), mark all positions as passed
    if result.code == 0 then
      -- Get all test positions from the tree
      for _, position in tree:iter() do
        if position.type == "test" then
          results[position.id] = {
            status = "passed",
            short = position.name .. " ✓"
          }
        end
      end
    else
      -- If tests failed, mark all as failed for now
      -- (We could parse the output more carefully to get individual results)
      for _, position in tree:iter() do
        if position.type == "test" then
          results[position.id] = {
            status = "failed",
            short = position.name .. " ✗",
            output = output
          }
        end
      end
    end
    
    return results
  end

  return adapter
end

return create_adapter