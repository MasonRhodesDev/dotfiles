-- Mason v2 path for Vue language server
local vue_language_server_path = vim.fn.expand '$MASON/packages/vue-language-server/node_modules/@vue/language-server'
local tsserver_filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" }
local vue_plugin = {
  name = '@vue/typescript-plugin',
  location = vue_language_server_path,
  languages = { 'vue' },
  configNamespace = 'typescript',
}

return {
  settings = {
    vtsls = {
      tsserver = {
        globalPlugins = {
          vue_plugin,
        },
      },
      enableMoveToFileCodeAction = true,
      autoUseWorkspaceTsdk = true,
      experimental = {
        completion = {
          enableServerSideFuzzyMatch = true,
          entriesLimit = 50,
        }
      }
    },
    typescript = {
      suggest = {
        autoImports = true,
        completeFunctionCalls = true,
        includeAutomaticOptionalChainCompletions = true,
        importStatementSuggestions = true,
      },
      updateImportsOnFileMove = {
        enabled = "always",
      },
      preferences = {
        includePackageJsonAutoImports = "on",
        includeCompletionsForModuleExports = true,
        includeCompletionsForImportStatements = true,
        importModuleSpecifier = "shortest",
        quoteStyle = "single",
        providePrefixAndSuffixTextForRename = true,
      },
      codeActionsOnSave = {
        source = {
          addMissingImports = { enabled = true },
        },
      },
      referencesCodeLens = {
        enabled = true,
        showOnAllFunctions = true,
      },
      implementationsCodeLens = {
        enabled = true,
      },
    },
    javascript = {
      suggest = {
        autoImports = true,
        completeFunctionCalls = true,
        includeAutomaticOptionalChainCompletions = true,
        importStatementSuggestions = true,
      },
      updateImportsOnFileMove = {
        enabled = "always",
      },
      codeActionsOnSave = {
        source = {
          addMissingImports = { enabled = true },
        },
      },
      referencesCodeLens = {
        enabled = true,
        showOnAllFunctions = true,
      },
      implementationsCodeLens = {
        enabled = true,
      },
    },
  },
  filetypes = tsserver_filetypes,
}
