local function find_vitest_config_dir(path)
  local config_files = {
    "vitest.config.js",
    "vitest.config.ts", 
    "vitest.config.mjs",
    "vite.config.js",
    "vite.config.ts",
    "vite.config.mjs"
  }
  
  local current_dir = path
  while current_dir ~= "/" do
    for _, config_file in ipairs(config_files) do
      local config_path = current_dir .. "/" .. config_file
      if vim.fn.filereadable(config_path) == 1 then
        return current_dir
      end
    end
    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end
  
  return nil
end

return {
  cwd = function(path)
    return find_vitest_config_dir(path)
  end
}