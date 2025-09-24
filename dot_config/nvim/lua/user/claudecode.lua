-- Helper function to get Claude terminal job ID
local function get_claude_terminal_job_id()
  -- Try native provider first
  local native_ok, native = pcall(require, "claudecode.terminal.native")
  if native_ok and native.get_active_bufnr then
    local bufnr = native.get_active_bufnr()
    
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      -- Get job ID from buffer variable
      local job_id = vim.b[bufnr].terminal_job_id
      if job_id then return job_id end
    end
  end
  
  -- Fallback: search all terminal buffers for Claude
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buftype_ok, buftype = pcall(vim.api.nvim_buf_get_option, buf, "buftype")
      if buftype_ok and buftype == "terminal" then
        local bufname = vim.api.nvim_buf_get_name(buf)
        if bufname:match("claude") or bufname:match("Claude") then
          return vim.b[buf].terminal_job_id
        end
      end
    end
  end
  
  return nil
end

-- Function to send text directly to Claude terminal
local function send_text_to_claude(text)
  local job_id = get_claude_terminal_job_id()

  if not job_id then
    -- Open Claude if not already open
    vim.cmd("ClaudeCode")
    vim.notify("Opening Claude Code...", vim.log.levels.INFO)

    -- Wait for terminal to initialize, then send text
    vim.defer_fn(function()
      local new_job_id = get_claude_terminal_job_id()
      if new_job_id then
        local success = pcall(vim.fn.chansend, new_job_id, text .. "\n")
        if success then
          -- Ensure terminal stays visible and focused
          vim.cmd("ClaudeCode")
          vim.defer_fn(function() vim.cmd("ClaudeCodeFocus") end, 100)
          vim.notify("Text sent to Claude Code", vim.log.levels.INFO)
        else
          vim.notify("Failed to send text to Claude terminal", vim.log.levels.ERROR)
        end
      else
        vim.notify("Failed to find Claude terminal", vim.log.levels.ERROR)
      end
    end, 1000)
  else
    -- Validate channel is still open before sending
    local success = pcall(vim.fn.chansend, job_id, text .. "\n")
    if success then
      -- Ensure terminal stays visible and focused
      vim.cmd("ClaudeCode")
      vim.defer_fn(function() vim.cmd("ClaudeCodeFocus") end, 100)
      vim.notify("Text sent to Claude Code", vim.log.levels.INFO)
    else
      -- Channel is closed, just notify user
      vim.notify("Claude terminal connection lost. Please try again.", vim.log.levels.WARN)
    end
  end
end

local function send_diagnostics_to_claude()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-indexed
  local diagnostics = vim.diagnostic.get(0, {lnum = cursor_line})
  
  if #diagnostics == 0 then
    vim.notify("No diagnostic at cursor position", vim.log.levels.INFO)
    return
  end
  
  local lines = {}
  table.insert(lines, "I have this diagnostic error in my code:")
  table.insert(lines, "")
  
  for _, diag in ipairs(diagnostics) do
    local severity = vim.diagnostic.severity[diag.severity]
    local line_num = diag.lnum + 1
    local col_num = diag.col + 1
    table.insert(lines, string.format("%s:%d:%d: %s - %s", 
      vim.fn.expand("%"), line_num, col_num, severity, diag.message))
  end
  
  table.insert(lines, "")
  table.insert(lines, "Can you help me understand and fix this?")
  
  local content = table.concat(lines, "\n")
  send_text_to_claude(content)
end

local function send_quickfix_to_claude()
  -- Check if quickfix window is open and has items
  local qf_winid = vim.fn.getqflist({ winid = 0 }).winid
  local qflist = vim.fn.getqflist()
  
  vim.notify(string.format("Quickfix: window_id=%s, list_size=%d", qf_winid, #qflist), vim.log.levels.INFO)
  
  if qf_winid ~= 0 then
    -- Quickfix window is open, get current item
    local current_idx = vim.fn.getqflist({ idx = 0 }).idx
    
    vim.notify(string.format("Quickfix window open: current_idx=%d, list_size=%d", current_idx, #qflist), vim.log.levels.INFO)
    
    if current_idx > 0 and current_idx <= #qflist then
      local item = qflist[current_idx]
      local filename = item.bufnr > 0 and vim.api.nvim_buf_get_name(item.bufnr) or ""
      local line_num = item.lnum or 0
      local col_num = item.col or 0
      local text = item.text or ""
      
      local lines = {}
      table.insert(lines, "I have this error/issue from my quickfix list:")
      table.insert(lines, "")
      
      if filename ~= "" then
        table.insert(lines, string.format("%s:%d:%d: %s", filename, line_num, col_num, text))
      else
        table.insert(lines, text)
      end
      
      table.insert(lines, "")
      table.insert(lines, "Can you help me understand and resolve this?")
      
      local content = table.concat(lines, "\n")
      send_text_to_claude(content)
      return
    else
      vim.notify("No current quickfix item selected", vim.log.levels.WARN)
    end
  else
    vim.notify("Quickfix window not open, checking for diagnostics at cursor", vim.log.levels.INFO)
  end
  
  -- Quickfix not open or no current item, get diagnostic at cursor instead
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local diagnostics = vim.diagnostic.get(0, {lnum = cursor_line})
  
  if #diagnostics == 0 then
    vim.notify("No quickfix item selected and no diagnostic at cursor", vim.log.levels.INFO)
    return
  end
  
  local lines = {}
  table.insert(lines, "I have this diagnostic error in my code:")
  table.insert(lines, "")
  
  for _, diag in ipairs(diagnostics) do
    local severity = vim.diagnostic.severity[diag.severity]
    local line_num = diag.lnum + 1
    local col_num = diag.col + 1
    table.insert(lines, string.format("%s:%d:%d: %s - %s", 
      vim.fn.expand("%"), line_num, col_num, severity, diag.message))
  end
  
  table.insert(lines, "")
  table.insert(lines, "Can you help me understand and fix this?")
  
  local content = table.concat(lines, "\n")
  send_text_to_claude(content)
end

return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    claude_executable = "/home/mason/.claude/local/claude",
    diff_opts = {
      layout = "vertical",
      open_in_new_tab = true,         -- Opens diff in dedicated tab for clean review
      keep_terminal_focus = true,    -- Focus on diff when opened
      hide_terminal_in_new_tab = false, -- Hide terminal in diff tab for maximum space
      on_new_file_reject = "keep_empty",
    },
  },
  keys = {
    { "<leader>a", nil, desc = "AI/Claude Code" },
    { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    {
      "<leader>as",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Add file",
      ft = { "NvimTree", "neo-tree", "oil", "minifiles" },
    },
    -- Diff management
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    -- Send diagnostics/errors to Claude
    { "<leader>aj", function() send_diagnostics_to_claude() end, desc = "Send diagnostics to Claude" },
    { "<leader>aq", function() send_quickfix_to_claude() end, desc = "Send quickfix to Claude" },
    -- Debug config
    { "<leader>aD", function()
      local claudecode = require("claudecode")
      if claudecode.state and claudecode.state.config then
        local config = claudecode.state.config
        print("ClaudeCode config debug:")
        if config.diff_opts then
          print("  keep_terminal_focus:", config.diff_opts.keep_terminal_focus)
          print("  hide_terminal_in_new_tab:", config.diff_opts.hide_terminal_in_new_tab)
          print("  open_in_new_tab:", config.diff_opts.open_in_new_tab)
        else
          print("  diff_opts is nil!")
        end
      else
        print("ClaudeCode not initialized")
      end
    end, desc = "Debug Claude config" },
  },
}
