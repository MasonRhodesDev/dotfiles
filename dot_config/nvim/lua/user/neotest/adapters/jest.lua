local function find_jest_config_dir(path)
  local current_dir = path
  while current_dir ~= "/" do
    -- Check for jest.config.* files
    local jest_configs = vim.fn.glob(current_dir .. "/jest.config.*", false, true)
    if #jest_configs > 0 then
      return current_dir
    end
    
    -- Check for package.json with jest dependency
    local package_json = current_dir .. "/package.json"
    if vim.fn.filereadable(package_json) == 1 then
      local content = vim.fn.readfile(package_json)
      local json_str = table.concat(content, "\n")
      if string.match(json_str, '"jest"') then
        return current_dir
      end
    end
    
    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end
  
  return nil
end

return {
  cwd = function(path)
    return find_jest_config_dir(path)
  end
}