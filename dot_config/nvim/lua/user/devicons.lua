local M = {
  "nvim-tree/nvim-web-devicons",
  commit = "6e51ca170563330e063720449c21f43e27ca0bc1",
  event = "VeryLazy",
}

function M.config()
  local devicons = require "nvim-web-devicons"
  
  devicons.setup()
  
  local original_get_icon = devicons.get_icon
  devicons.get_icon = function(name, ext, opts)
    if ext == 'tmpl' then
      local real_ext = name:match('%.([^%.]+)%.tmpl$')
      if real_ext then
        if real_ext == 'conf' and (name:match('chezmoi/dot_config/hypr') or name:match('%.config/hypr')) then
          return original_get_icon('hyprland.conf', 'conf', opts)
        end
        return original_get_icon(name, real_ext, opts)
      end
    end
    
    if ext == 'conf' and (name:match('chezmoi/dot_config/hypr') or name:match('%.config/hypr')) then
      return original_get_icon('hyprland.conf', 'conf', opts)
    end
    
    return original_get_icon(name, ext, opts)
  end
end

return M
