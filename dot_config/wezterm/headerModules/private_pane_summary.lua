local wezterm = require 'wezterm'

local TTL_MS = 2 * 60 * 1000

local function runtime_root(name)
  local runtime = os.getenv("XDG_RUNTIME_DIR")
  if runtime and runtime ~= "" then
    return runtime .. "/" .. name
  end

  local home = os.getenv("HOME") or "."
  return home .. "/.cache/" .. name
end

local function state_root()
  return runtime_root("wezterm-pane-summary")
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

local function pane_tty(pane)
  local ok, tty = pcall(function()
    return pane:get_tty_name()
  end)
  if ok and tty ~= nil then
    return tostring(tty)
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

local function fresh_ms(state, ttl_ms)
  if type(state.updatedAtMs) ~= "number" then return false end
  return ((os.time() * 1000) - state.updatedAtMs) <= ttl_ms
end

local function looks_like_hook_lifecycle_summary(value)
  local normalized = value:gsub("[_-]+", " ")
  local toolish = normalized:match("%f[%w](command)%f[%W]")
      or normalized:match("%f[%w](commands)%f[%W]")
      or normalized:match("%f[%w](tool)%f[%W]")
      or normalized:match("%f[%w](tools)%f[%W]")
      or normalized:match("%f[%w](agent)%f[%W]")
      or normalized:match("%f[%w](agents)%f[%W]")
      or normalized:match("%f[%w](search)%f[%W]")
      or normalized:match("%f[%w](searches)%f[%W]")
      or normalized:match("%f[%w](file)%f[%W]")
      or normalized:match("%f[%w](files)%f[%W]")
      or normalized:match("%f[%w](read)%f[%W]")
      or normalized:match("%f[%w](reads)%f[%W]")
      or normalized:match("%f[%w](write)%f[%W]")
      or normalized:match("%f[%w](writes)%f[%W]")
      or normalized:match("%f[%w](edit)%f[%W]")
      or normalized:match("%f[%w](edits)%f[%W]")
      or normalized:match("%f[%w](bash)%f[%W]")
      or normalized:match("%f[%w](glob)%f[%W]")
      or normalized:match("%f[%w](globs)%f[%W]")
      or normalized:match("%f[%w](grep)%f[%W]")
      or normalized:match("%f[%w](greps)%f[%W]")
      or normalized:match("%f[%w](mcp)%f[%W]")
      or normalized:match("mcp health")
      or normalized:match("ctx reduce")
      or normalized:match("todo write")
      or normalized:match("todowrite")
      or normalized:match("structured output")
      or normalized:match("file search")
  local lifecycle = normalized:match("%f[%w](running)%f[%W]")
      or normalized:match("%f[%w](using)%f[%W]")
      or normalized:match("%f[%w](reading)%f[%W]")
      or normalized:match("%f[%w](writing)%f[%W]")
      or normalized:match("%f[%w](editing)%f[%W]")
      or normalized:match("%f[%w](searching)%f[%W]")
      or normalized:match("%f[%w](started)%f[%W]")
      or normalized:match("%f[%w](starting)%f[%W]")
      or normalized:match("%f[%w](failed)%f[%W]")
      or normalized:match("%f[%w](finished)%f[%W]")
      or normalized:match("%f[%w](completed)%f[%W]")
      or normalized:match("%f[%w](complete)%f[%W]")
      or normalized:match("%f[%w](done)%f[%W]")
  return toolish and lifecycle
end

local function word_count(value)
  local count = 0
  for _ in value:gmatch("%S+") do
    count = count + 1
  end
  return count
end

local function safe_summary(value)
  if type(value) ~= "string" then return nil end
  local summary = value:gsub("[\r\n]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""):lower()
  if summary == "" or #summary > 60 then return nil end
  if word_count(summary) > 6 then return nil end
  if summary:match(",") or summary:match(";") then return nil end
  if summary:match("[{}%[%]:]") then return nil end
  if summary:match("^json%f[%W]") then return nil end
  if summary == "unknown" or summary == "n/a" or summary == "none" or summary == "terminal activity" or summary == "working in terminal" then return nil end
  if summary:match("^working%f[%W]") then return nil end
  if summary:match("https?://") then return nil end
  if summary:match("[%w._%%+-]+@[%w.-]+%.[%a][%a]+") then return nil end
  if summary:match("%f[%w]sk%-[%w_-][%w_-][%w_-][%w_-][%w_-][%w_-][%w_-][%w_-]+%f[%W]")
      or summary:match("%f[%w]pk%-[%w_-][%w_-][%w_-][%w_-][%w_-][%w_-][%w_-][%w_-]+%f[%W]")
      or summary:match("%f[%w]rk%-[%w_-][%w_-][%w_-][%w_-][%w_-][%w_-][%w_-][%w_-]+%f[%W]") then return nil end
  if summary:match("%f[%w]%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x+%f[%W]") then return nil end
  if summary:match("%f[%w][%a][%w]*_[%w_]+%f[%W]") then return nil end
  if summary:match("%S+/%S+") then return nil end
  if looks_like_hook_lifecycle_summary(summary) then return nil end
  return summary
end

local function read_state(pane)
  local id = pane_id(pane)
  if not id then return nil end

  local content = read_file(state_root() .. "/pane-" .. id .. ".json")
  if not content then return nil end

  local ok, state = pcall(wezterm.json_parse, content)
  local summary = ok and type(state) == "table" and safe_summary(state.summary) or nil
  local tty = pane_tty(pane)
  local trusted_source = (state and state.source == "terminal-task-stack" and state.summarizer == "ollama")
      or (state and state.source == "transcript"
        and (state.summarizer == "transcript" or state.summarizer == "ollama"))
  if summary and state.active and trusted_source and (state.paneTty and tty and state.paneTty == tty) and fresh_ms(state, TTL_MS) and (state.confidence == "medium" or state.confidence == "high") then
    state.summary = summary
    return state
  end

  return nil
end

return {
  -- Pane summary is intentionally last/right-most.
  priority = 10000,

  detect = function(pane)
    local state = read_state(pane)
    if state then
      return true, state
    end
    return false, nil
  end,

  get_component = function(pane, state)
    local summary = state and state.summary or ""
    if summary == "" then return nil end
    return summary
  end
}
