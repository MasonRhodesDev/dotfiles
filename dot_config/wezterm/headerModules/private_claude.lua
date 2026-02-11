return {
  priority = 1,

  detect = function(pane)
    local process = pane:get_foreground_process_name() or ""

    -- Check if process is claude directly
    if process:match("claude$") then
      return true, nil
    end

    -- Check for CLAUDE_ACTIVE user variable
    local user_vars = pane:get_user_vars()
    if user_vars.CLAUDE_ACTIVE == "1" then
      return true, nil
    end

    -- Fallback: check if title contains "claude"
    local title = pane:get_title() or ""
    if title:lower():match("claude") then
      return true, nil
    end

    return false, nil
  end,

  get_component = function(pane, data)
    local parts = {}

    -- Get activity and model from user variables
    local user_vars = pane:get_user_vars()
    local activity = user_vars.CLAUDE_ACTIVITY or ""
    local model = user_vars.CLAUDE_MODEL or ""

    -- Build label: "Claude" or "Claude (opus)"
    local label = "Claude"
    if model ~= "" then
      -- Extract short name: "claude-opus-4-6" → "opus", "sonnet" → "sonnet"
      local short = model:match("opus") or model:match("sonnet") or model:match("haiku") or model
      label = "Claude (" .. short .. ")"
    end

    if activity ~= "" then
      table.insert(parts, " 🤖 " .. label .. " | " .. activity)
    else
      table.insert(parts, " 🤖 " .. label)
    end

    -- Add working directory
    local cwd = pane:get_current_working_dir()
    if cwd then
      local cwd_text = cwd.file_path:gsub(os.getenv("HOME") or "", "~")
      table.insert(parts, cwd_text)
    end

    return table.concat(parts, " | ")
  end
}
