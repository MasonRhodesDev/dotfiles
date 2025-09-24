local M = {}

-- Create a replacement for neotest-jest that bypasses the problematic detection
function M.create_patched_adapter(opts)
  -- Get the original neotest-jest module - but call it like a function
  local jest = require("neotest-jest")
  local lib = require("neotest.lib")
  
  -- Get the configured adapter
  local adapter = jest(opts or {})
  
  -- Store original functions we want to override
  local original_is_test_file = adapter.is_test_file
  
  -- Override the problematic is_test_file function
  adapter.is_test_file = function(file_path)
    if file_path == nil then
      return false
    end
    
    -- Check if it matches test file patterns
    local is_test_file = false
    
    if file_path:match("__tests__") or
       file_path:match("%.test%.[jt]sx?$") or 
       file_path:match("%.spec%.[jt]sx?$") then
      is_test_file = true
    end
    
    if not is_test_file then
      return false
    end
    
    -- Use our improved jest detection
    return M.has_jest_in_project(file_path)
  end
  
  -- The adapter should already be properly configured from the jest(opts) call above
  -- No need for additional configuration setup
  
  return adapter
end

function M.patch_jest_detection()
  -- This function is no longer needed with the new approach
  return M.create_patched_adapter
end

function M.has_jest_in_project(file_path)
  local lib = require("neotest.lib")
  local current_dir = vim.fn.fnamemodify(file_path, ":h")
  
  while current_dir and current_dir ~= "/" do
    -- Check if we're still in a git repository
    if not M.is_in_git_repo(current_dir) then
      break
    end
    
    -- Look for package.json in current directory
    local package_json_path = current_dir .. "/package.json"
    if vim.fn.filereadable(package_json_path) == 1 then
      if M.package_has_jest(package_json_path) then
        return true
      end
    end
    
    -- Check for jest binary in node_modules
    local jest_bin = current_dir .. "/node_modules/.bin/jest"
    if vim.fn.executable(jest_bin) == 1 then
      return true
    end
    
    -- Check for jest config files
    local jest_configs = {
      "jest.config.js",
      "jest.config.mjs", 
      "jest.config.json",
      "jest.config.ts"
    }
    
    for _, config in ipairs(jest_configs) do
      if vim.fn.filereadable(current_dir .. "/" .. config) == 1 then
        return true
      end
    end
    
    -- Move up one directory
    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end
  
  return false
end

function M.is_in_git_repo(dir)
  -- Check if we're in a git repository by looking for .git directory
  local git_dir = dir .. "/.git"
  return vim.fn.isdirectory(git_dir) == 1 or 
         vim.fn.finddir(".git", dir .. ";") ~= ""
end

function M.package_has_jest(package_json_path)
  local lib = require("neotest.lib")
  
  local success, content = pcall(lib.files.read, package_json_path)
  if not success then
    return false
  end
  
  local ok, package_json = pcall(vim.json.decode, content)
  if not ok then
    return false
  end
  
  -- Check dependencies
  if package_json.dependencies then
    for key, _ in pairs(package_json.dependencies) do
      if string.match(key, "jest") then
        return true
      end
    end
  end
  
  -- Check devDependencies  
  if package_json.devDependencies then
    for key, _ in pairs(package_json.devDependencies) do
      if string.match(key, "jest") then
        return true
      end
    end
  end
  
  -- Check scripts for jest
  if package_json.scripts then
    for _, value in pairs(package_json.scripts) do
      if string.find(value or "", "jest") then
        return true
      end
    end
  end
  
  return false
end

return M