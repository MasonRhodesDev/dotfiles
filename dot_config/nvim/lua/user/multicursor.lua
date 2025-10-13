local M = {
  "jake-stewart/multicursor.nvim",
  branch = "1.0",
  event = "VeryLazy",
}

function M.config()
  local mc = require("multicursor-nvim")

  mc.setup()

  local set = vim.keymap.set

  -- Add cursors vertically (up/down)
  set({"n", "x"}, "<leader><up>", function() mc.lineAddCursor(-1) end, { desc = "Add cursor above" })
  set({"n", "x"}, "<leader><down>", function() mc.lineAddCursor(1) end, { desc = "Add cursor below" })

  -- VS Code style - Ctrl+d to add cursor on next match
  set({"n", "x"}, "<c-d>", function()
    mc.matchAddCursor(1)
    -- If in visual mode after adding cursor, stay in visual mode
    -- If in normal mode, the cursor will have a visual selection
    -- Press v to exit visual mode and use normal mode commands on all cursors
  end, { desc = "Add cursor on next match" })

  -- Keymap layer only active when multiple cursors exist
  mc.addKeymapLayer(function(layerSet)
    -- Escape to clear cursors
    layerSet("n", "<esc>", function()
      if not mc.cursorsEnabled() then
        mc.enableCursors()
      else
        mc.clearCursors()
      end
    end)
  end)

  -- Customize how cursors look (important for visibility!)
  local hl = vim.api.nvim_set_hl
  hl(0, "MultiCursorCursor", { link = "Cursor" })
  hl(0, "MultiCursorVisual", { link = "Visual" })
  hl(0, "MultiCursorSign", { link = "SignColumn" })
  hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
  hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
  hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
end

return M
