return {
  priority = 0,

  detect = function(pane)
    local process = pane:get_foreground_process_name() or ""
    local active = process:match("ssh$") or pane:get_domain_name():match("^SSH:")
    return active, nil
  end,

  get_component = function(pane, data)
    return " 🔐 SSH"
  end
}
