local M = {
  "nvim-tree/nvim-web-devicons",
  event = "VeryLazy",
}

function M.config()
  local devicons = require "nvim-web-devicons"
  
  -- Setup default icons
  devicons.setup()
  
  -- Override get_icon for .tmpl files and hyprland configs
  local original_get_icon = devicons.get_icon
  devicons.get_icon = function(name, ext, opts)
    -- Handle .tmpl files
    if ext == 'tmpl' then
      local real_ext = name:match('%.([^%.]+)%.tmpl$')
      if real_ext then
        -- Special case for .conf.tmpl in chezmoi hypr directories
        if real_ext == 'conf' and (name:match('chezmoi/dot_config/hypr') or name:match('%.config/hypr')) then
          return original_get_icon('hyprland.conf', 'conf', opts)
        end
        return original_get_icon(name, real_ext, opts)
      end
    end
    
    -- Handle hyprland .conf files
    if ext == 'conf' and (name:match('chezmoi/dot_config/hypr') or name:match('%.config/hypr')) then
      return original_get_icon('hyprland.conf', 'conf', opts)
    end
    
    return original_get_icon(name, ext, opts)
  end
end

return M
