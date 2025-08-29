-- Minimal wrapper for neotest-vitest to add directory support
-- Only overrides build_spec, keeps everything else intact

local function create_vitest_wrapper(user_config)
  user_config = user_config or {}
  
  -- Get the base vitest adapter
  local base_adapter = require("neotest-vitest")(user_config)
  
  -- Store the original build_spec
  local original_build_spec = base_adapter.build_spec
  
  -- Store the original results function too
  local original_results = base_adapter.results

  -- Override only build_spec to handle directories
  base_adapter.build_spec = function(args)
    local position = args.tree:data()
    
    -- If it's a directory, modify the command
    if position.type == "dir" then
      -- Get the original spec for the file
      local spec = original_build_spec(args)
      
      -- Find relative directory path
      local cwd = spec.cwd or vim.fn.getcwd()
      local relative_dir = position.path
      
      if position.path:find(cwd, 1, true) == 1 then
        relative_dir = position.path:sub(#cwd + 2) -- +2 to skip trailing slash
      end
      
      -- Build clean command, preserving binary and flags but removing file/pattern args
      local command = { spec.command[1] } -- Keep the vitest binary
      local skip_next = false
      
      for i = 2, #spec.command do
        local arg = spec.command[i]
        if skip_next then
          skip_next = false
        elseif arg:match("^--testNamePattern") then
          -- Remove testNamePattern for directory runs (let it run all tests in dir)
          if not arg:match("=") then
            skip_next = true -- Skip the next arg if pattern is separate
          end
        elseif not arg:match("%.test%.") and not arg:match("%.spec%.") and not arg:match("test$") then
          -- Keep config, reporters, etc. but remove specific test files/dirs
          table.insert(command, arg)
        end
      end
      
      -- Add directory to command (just the relative path)
      if relative_dir and relative_dir ~= "" then
        table.insert(command, relative_dir)
      end
      
      spec.command = command
      return spec
    else
      -- For files and tests, use original behavior
      return original_build_spec(args)
    end
  end
  
  -- Use original results function
  base_adapter.results = original_results
  
  return base_adapter
end

return create_vitest_wrapper