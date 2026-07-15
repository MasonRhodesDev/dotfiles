local wezterm = require 'wezterm'

local agents = {
  claude = { label = "Claude", icon = "🤖" },
  codex = { label = "Codex", icon = "✦" },
  pi = { label = "Pi", icon = "π" },
}

local agent_kind = {
  ["1"] = "pi",
  ["2"] = "codex",
  ["3"] = "claude",
}

local STATE_TTL_MS = 2 * 60 * 1000

local function short_model(model)
  if model == nil or model == "" then return "" end
  return model:match("opus")
      or model:match("sonnet")
      or model:match("haiku")
      or model:gsub("^amazon%-bedrock/", "")
end

local function runtime_root(name)
  local runtime = os.getenv("XDG_RUNTIME_DIR")
  if runtime and runtime ~= "" then
    return runtime .. "/" .. name
  end

  local home = os.getenv("HOME") or "."
  return home .. "/.cache/" .. name
end

local function state_root()
  return runtime_root("wezterm-agent-status")
end

local function pane_id(pane)
  local ok, id = pcall(function()
    return pane:pane_id()
  end)
  if ok and id ~= nil then
    return tostring(id)
  end
  return nil
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

local function fresh_enough(state)
  if type(state.updatedAtMs) ~= "number" then return false end
  local now_ms = os.time() * 1000
  return (now_ms - state.updatedAtMs) <= STATE_TTL_MS
end

local function read_pane_state(pane, agent)
  local id = pane_id(pane)
  if not id or not agent then return nil end

  -- AGENT_ACTIVE/AGENT_KIND/AGENT_SEQ are numeric WezTerm user-var signals.
  -- String details live in this explicit hook-fed pane state file because this
  -- WezTerm build ignores non-numeric SetUserVar values.
  local path = state_root() .. "/" .. agent .. "/pane-" .. id .. ".json"
  local content = read_file(path)
  if not content then return nil end

  local ok, state = pcall(wezterm.json_parse, content)
  if ok and type(state) == "table" and state.active and agents[state.agent] then
    return state
  end

  return nil
end

local function cwd_component(pane)
  local ok, url = pcall(function()
    return pane:get_current_working_dir()
  end)
  if not ok or url == nil then return "" end

  -- Url object (newer wezterm) or "file://host/path" string (older).
  local path
  if type(url) == "userdata" or type(url) == "table" then
    path = url.file_path
  else
    path = tostring(url):gsub("^file://[^/]*", "")
  end
  if not path or path == "" then return "" end

  local home = os.getenv("HOME")
  if home and home ~= "" and path:sub(1, #home) == home then
    path = "~" .. path:sub(#home + 1)
  end
  if #path > 40 then
    path = "…" .. path:sub(-39)
  end
  return " | 📁 " .. path
end

local function render_component(agent, model, state, activity, pane)
  local definition = agents[agent] or agents.claude
  local label = definition.label
  local short = short_model(model)

  if short ~= "" then
    label = label .. " (" .. short .. ")"
  end

  local detail = activity or ""

  local result = " " .. definition.icon .. " " .. label
  if detail ~= "" then
    result = result .. " | " .. detail
  end

  return result .. cwd_component(pane)
end

return {
  priority = 1,

  detect = function(pane)
    local user_vars = pane:get_user_vars()

    if user_vars.AGENT_ACTIVE == "1" then
      local agent = agent_kind[user_vars.AGENT_KIND]
      if not agent then return false, nil end
      local state = read_pane_state(pane, agent)
      if state then
        return true, { agent = state.agent, state = state }
      end
      return true, { agent = agent, state = { agent = agent } }
    end

    if user_vars.CLAUDE_ACTIVE == "1" then
      return true, { agent = "claude", legacy_claude = true }
    end

    return false, nil
  end,

  get_component = function(pane, data)
    local user_vars = pane:get_user_vars()

    if data and data.legacy_claude then
      return render_component(
        "claude",
        user_vars.CLAUDE_MODEL or "",
        "",
        "",
        pane
      )
    end

    local state = data and data.state or {}
    return render_component(
      state.agent or (data and data.agent) or "claude",
      state.model or "",
      "",
      "",
      pane
    )
  end
}
