return {
  "NickvanDyke/opencode.nvim",
  commit = "abde303aa43517d32a84dbeeb14037ef146a106a",
  dependencies = {
    { "folke/snacks.nvim", commit = "68da653d206069007f71d4373049193248bf913b", opts = { input = {}, picker = {} } },
  },
  config = function()
    vim.g.opencode_opts = {
      auto_reload = true,
    }
    
    vim.opt.autoread = true
  end,
  keys = {
    { "<leader>a", nil, desc = "AI/Claude Code" },
    { "<leader>ac", function() require("opencode").toggle() end, desc = "Toggle Claude" },
    { "<leader>af", function() require("opencode").toggle() end, desc = "Focus Claude" },
    { "<leader>ar", function() require("opencode").command("session_new") end, desc = "Resume Claude" },
    { "<leader>aC", function() require("opencode").ask() end, desc = "Continue Claude" },
    { "<leader>am", function() require("opencode").command("agent_cycle") end, desc = "Select Claude model" },
    { "<leader>ab", function() require("opencode").prompt("@buffer") end, desc = "Add current buffer" },
    { "<leader>as", function() require("opencode").prompt("@selection") end, mode = "v", desc = "Send to Claude" },
    {
      "<leader>as",
      function() require("opencode").prompt("@buffer") end,
      desc = "Add file",
      ft = { "NvimTree", "neo-tree", "oil", "minifiles" },
    },
    { "<leader>aj", function() require("opencode").prompt("@diagnostics") end, desc = "Send diagnostics to Claude" },
    { "<leader>aq", function() require("opencode").prompt("@quickfix") end, desc = "Send quickfix to Claude" },
    { "<leader>ao", function() require("opencode").select() end, desc = "Select prompt" },
    { "<leader>an", function() require("opencode").command("session_new") end, desc = "New session" },
    { "<leader>ai", function() require("opencode").command("session_interrupt") end, desc = "Interrupt session" },
  },
}
