local M = {
  "mfussenegger/nvim-dap",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "rcarriga/nvim-dap-ui",
  },
}

function M.config()
  local dap = require("dap")
  local dapui = require("dapui")
  
  -- Setup breakpoint icons
  vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" })
  vim.fn.sign_define("DapBreakpointCondition", { text = "◐", texthl = "DapBreakpointCondition", linehl = "", numhl = "" })
  vim.fn.sign_define("DapBreakpointRejected", { text = "◯", texthl = "DapBreakpointRejected", linehl = "", numhl = "" })
  vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DapLogPoint", linehl = "", numhl = "" })
  vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DapStopped", linehl = "DapStoppedLine", numhl = "" })
  
  -- Setup breakpoint colors
  vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#e51400" })
  vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#f79000" })
  vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#888888" })
  vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#61afef" })
  vim.api.nvim_set_hl(0, "DapStopped", { fg = "#98c379" })
  vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#31353f" })
  
  -- Setup dapui
  dapui.setup()

  -- Define JavaScript/TypeScript based languages
  local js_based_languages = {
    "typescript",
    "javascript", 
    "typescriptreact",
    "javascriptreact",
    "vue"
  }

  -- Configure js-debug-adapter (installed via Mason)
  dap.adapters["pwa-node"] = {
    type = "server",
    host = "localhost",
    port = "${port}",
    executable = {
      command = "js-debug-adapter",
      args = { "${port}" },
    },
  }
  
  dap.adapters["pwa-chrome"] = {
    type = "server", 
    host = "localhost",
    port = "${port}",
    executable = {
      command = "js-debug-adapter",
      args = { "${port}" },
    },
  }

  dap.adapters["pwa-msedge"] = {
    type = "server",
    host = "localhost", 
    port = "${port}",
    executable = {
      command = "js-debug-adapter",
      args = { "${port}" },
    },
  }

  dap.adapters["node-terminal"] = {
    type = "server",
    host = "localhost",
    port = "${port}", 
    executable = {
      command = "js-debug-adapter",
      args = { "${port}" },
    },
  }

  -- Configure debug adapters for JavaScript/TypeScript
  for _, language in ipairs(js_based_languages) do
    dap.configurations[language] = {
      -- Launch single Node.js file
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch current file (pwa-node)",
        cwd = vim.fn.getcwd(),
        program = "${file}",
        sourceMaps = true,
        protocol = "inspector",
      },
      -- Launch Node.js file with arguments
      {
        type = "pwa-node",
        request = "launch", 
        name = "Launch current file (pwa-node with args)",
        cwd = vim.fn.getcwd(),
        program = "${file}",
        args = function()
          local args_string = vim.fn.input("Arguments: ")
          return vim.split(args_string, " +")
        end,
        sourceMaps = true,
        protocol = "inspector",
      },
      -- Debug Jest Tests
      {
        type = "pwa-node",
        request = "launch",
        name = "Debug Jest Tests",
        runtimeExecutable = "node",
        runtimeArgs = {
          "./node_modules/jest/bin/jest.js",
          "--runInBand",
        },
        rootPath = "${workspaceFolder}",
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        internalConsoleOptions = "neverOpen",
        sourceMaps = true,
      },
      -- Debug Vitest Tests
      {
        type = "pwa-node",
        request = "launch",
        name = "Debug Vitest Tests", 
        runtimeExecutable = "node",
        runtimeArgs = {
          "./node_modules/vitest/vitest.mjs",
          "run",
          "--reporter=verbose",
        },
        rootPath = "${workspaceFolder}",
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        internalConsoleOptions = "neverOpen",
        sourceMaps = true,
      },
      -- Attach to Node.js process
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach (pwa-node)",
        processId = require("dap.utils").pick_process,
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
      },
      -- Debug Chrome/browser
      {
        type = "pwa-chrome",
        request = "launch",
        name = "Launch Chrome with localhost",
        url = function()
          local co = coroutine.running()
          return coroutine.create(function()
            vim.ui.input({ prompt = "Enter URL: ", default = "http://localhost:3000" }, function(url)
              if url == nil or url == "" then
                return
              else
                coroutine.resume(co, url)
              end
            end)
          end)
        end,
        webRoot = vim.fn.getcwd(),
        protocol = "inspector",
        sourceMaps = true,
        userDataDir = false,
      },
    }
  end

  -- Load launch.json configurations
  if vim.fn.filereadable(".vscode/launch.json") then
    local vscode_type_to_dap_type = {
      node = "pwa-node",
      chrome = "pwa-chrome",
    }

    local file = io.open(".vscode/launch.json", "r")
    if file then
      local launch_js_content = file:read("*a")
      file:close()
      
      -- Strip JSON comments (lines starting with //)
      local cleaned_content = ""
      for line in launch_js_content:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if not trimmed:match("^//") then
          cleaned_content = cleaned_content .. line .. "\n"
        end
      end
      
      local success, launch_json = pcall(vim.fn.json_decode, cleaned_content)
      if not success then
        -- Silently skip if JSON parsing fails
        return
      end

    for _, config in ipairs(launch_json.configurations or {}) do
      local dap_config = vim.deepcopy(config)
      dap_config.type = vscode_type_to_dap_type[config.type] or config.type

      for _, language in ipairs(js_based_languages) do
        if not dap.configurations[language] then
          dap.configurations[language] = {}
        end
        table.insert(dap.configurations[language], dap_config)
      end
    end
    end
  end

  -- Set up keymaps
  vim.keymap.set("n", "<leader>dO", function() dap.step_out() end, { desc = "Debug: Step Out" })
  vim.keymap.set("n", "<leader>do", function() dap.step_over() end, { desc = "Debug: Step Over" })
  vim.keymap.set("n", "<leader>da", function()
    if vim.fn.filereadable(".vscode/launch.json") then
      local dap = require("dap")
      dap.continue({ before = function() dap.clear_breakpoints() end })
    end
  end, { desc = "Debug: Run with Args" })

  -- Additional keymaps
  vim.keymap.set("n", "<leader>db", function() dap.toggle_breakpoint() end, { desc = "Debug: Toggle Breakpoint" })
  vim.keymap.set("n", "<leader>dc", function() dap.continue() end, { desc = "Debug: Continue" })
  vim.keymap.set("n", "<leader>di", function() dap.step_into() end, { desc = "Debug: Step Into" })
  vim.keymap.set("n", "<leader>dr", function() dap.repl.open() end, { desc = "Debug: Open REPL" })
  vim.keymap.set("n", "<leader>dt", function() dap.terminate() end, { desc = "Debug: Terminate" })
  vim.keymap.set("n", "<leader>du", function() dapui.toggle() end, { desc = "Debug: Toggle UI" })
end

return M