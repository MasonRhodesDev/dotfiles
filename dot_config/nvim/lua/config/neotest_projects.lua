-- Centralized neotest configurations mapped by git repository
-- This eliminates the need for .neotest.lua files in each project

return {
  ["github.com/thecvlb/lifemd"] = {
    disable_base_adapters = true,
    adapters = {
      require("user.neotest.adapters.jest-monorepo")({
        name = "jest-lifemd",
        monorepo_patterns = { "/repos/lifemd/" },
        package_roots = { "patient%-portal", "physician%-portal" },
        jest_command = { "npm", "test", "--" },
        auto_detect_package_root = true,
      })
    },
    suppress_notifications = true,
    lsp_formatting = {
      filter = function(client) 
        return client.name == "vtsls" or client.name == "eslint"
      end
    }
  },

  ["github.com/thecvlb/stardust-front-end"] = {
    adapters = {
      require("neotest-vitest") {
        vitestConfigPath = "vitest.config.ts",
        filter_dir = function(name, rel_path, root)
          -- Only handle vitest for unit test directories, exclude e2e
          return name ~= "e2e" and name ~= "test-results"
        end,
      },
    },
    suppress_notifications = true
  },

  -- Add more git repositories here as needed
  -- Format: ["github.com/user/repo"] = { neotest config }
  -- Examples:
  --
  -- ["github.com/user/another-project"] = {
  --   adapters = {
  --     require("neotest-vitest")
  --   },
  --   suppress_notifications = false
  -- },
  --
  -- ["gitlab.com/company/backend"] = {
  --   adapters = {
  --     require("neotest-python")
  --   }
  -- }
}