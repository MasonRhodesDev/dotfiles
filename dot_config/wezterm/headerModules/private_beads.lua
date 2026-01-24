return {
  -- No priority defined - will default to 999 (lowest priority)

  detect = function(pane)
    local cwd = pane:get_current_working_dir()
    if not cwd then
      return false, nil
    end

    local current_dir = cwd.file_path
    local filesystem_root = "/"

    -- Search up directory tree until git root
    while current_dir ~= filesystem_root do
      -- Check if .beads/beads.db exists
      local beads_db = current_dir .. '/.beads/beads.db'
      local file = io.open(beads_db, 'r')
      if file then
        file:close()
        return true, current_dir  -- Return beads directory as data
      end

      -- Stop at git repository root
      local git_dir = current_dir .. '/.git'
      local git_file = io.open(git_dir, 'r')
      if git_file then
        git_file:close()
        return false, nil
      end

      -- Move up one directory
      local parent = current_dir:match("^(.*)/[^/]+$")
      if not parent or parent == "" then
        break
      end
      current_dir = parent
    end

    return false, nil
  end,

  get_component = function(pane, beads_dir)
    if not beads_dir then
      return nil
    end

    local beads_db = beads_dir .. '/.beads/beads.db'

    -- Query total open tasks
    local count_query = string.format(
      'sqlite3 "%s" "SELECT COUNT(*) FROM issues WHERE deleted_at IS NULL AND status != \'closed\';" 2>/dev/null',
      beads_db
    )
    local count_handle = io.popen(count_query)
    local count_str = count_handle:read("*a"):gsub("%s+", "")
    count_handle:close()
    local count = tonumber(count_str) or 0

    -- Don't show module if count is 0
    if count == 0 then
      return nil
    end

    local parts = {}

    -- Show task count
    table.insert(parts, string.format("📋 %d task%s", count, count == 1 and "" or "s"))

    -- Query for in_progress tasks (most recently updated)
    local active_query = string.format(
      'sqlite3 "%s" "SELECT id, title FROM issues WHERE deleted_at IS NULL AND status = \'in_progress\' ORDER BY updated_at DESC LIMIT 1;" 2>/dev/null',
      beads_db
    )
    local active_handle = io.popen(active_query)
    local active_result = active_handle:read("*a")
    active_handle:close()

    if active_result and active_result:match("%S") then
      local task_id, task_title = active_result:match("([^|]+)|(.+)")
      if task_id and task_title then
        -- Extract short ID and truncate title
        local short_id = task_id:match("-([^-]+)$") or task_id
        local display_title = task_title:gsub("^%s+", ""):gsub("%s+$", "")
        if #display_title > 40 then
          display_title = display_title:sub(1, 37) .. "..."
        end
        table.insert(parts, string.format("🔄 %s: %s", short_id, display_title))
      end
    end

    return table.concat(parts, " | ")
  end
}
