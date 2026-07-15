-- ssh options that consume the next argument (from ssh(1)) — needed to find
-- the first non-option word, the destination.
local OPTS_WITH_ARG = "BbcDEeFIiJLlmOoPpRSWw"

local function ssh_destination(argv)
  if type(argv) ~= "table" then return nil end
  local dest
  local i = 2
  while i <= #argv do
    local a = argv[i]
    if a == "--" then
      dest = argv[i + 1]
      break
    elseif a:sub(1, 1) == "-" and #a > 1 then
      if #a == 2 and OPTS_WITH_ARG:find(a:sub(2, 2), 1, true) then
        i = i + 2
      else
        i = i + 1
      end
    else
      dest = a
      break
    end
  end
  if not dest or dest == "" then return nil end

  local url_host = dest:match("^ssh://([^/]+)")
  if url_host then
    dest = url_host:gsub(":%d+$", "")
  end
  dest = dest:match("@([^@]+)$") or dest
  if dest == "" then return nil end
  return dest
end

local function destination_host(pane)
  local ok, info = pcall(function()
    return pane:get_foreground_process_info()
  end)
  if not ok or not info then return nil end
  return ssh_destination(info.argv)
end

return {
  priority = 0,

  detect = function(pane)
    local process = pane:get_foreground_process_name() or ""
    local active = process:match("ssh$") or pane:get_domain_name():match("^SSH:")
    return active, nil
  end,

  get_component = function(pane, data)
    local host = destination_host(pane)
    if host then
      return " 🔐 " .. host
    end
    return " 🔐 SSH"
  end
}
