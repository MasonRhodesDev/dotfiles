return {
  "milanglacier/minuet-ai.nvim",
  dependencies = { 
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("minuet").setup({
      provider = "openai_fim_compatible",
      n_completions = 1,
      context_window = 1024,
      throttle = 500,
      debounce = 400,
      request_timeout = 5,
      provider_options = {
        openai_fim_compatible = {
          api_key = "TERM",
          name = "Ollama",
          end_point = "http://localhost:11434/v1/completions",
          model = "qwen2.5-coder:1.5b",
          stream = false,
          optional = {
            max_tokens = 48,
            top_p = 0.95,
            temperature = 0,
            num_predict = 48,
          },
        },
      },
      virtualtext = {
        auto_trigger_ft = { '*' },
        keymap = {
          accept = '<Tab>',
          accept_line = '<C-l>',
          accept_n_lines = '<C-k>',
          prev = '<C-p>',
          next = '<C-n>',
          dismiss = '<C-e>',
        },
      },
    })
    
    vim.notify("Minuet optimized for speed", vim.log.levels.INFO)
  end,
}
