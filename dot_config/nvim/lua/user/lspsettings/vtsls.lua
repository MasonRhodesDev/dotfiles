-- Dynamic path resolution for Vue language server (Mason 2.0 compatible)
local vue_language_server_path = vim.fn.expand('$MASON/packages/vue-language-server/node_modules/@vue/language-server')
local tsserver_filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" }
local vue_plugin = {
  name = '@vue/typescript-plugin',
  location = vue_language_server_path,
  languages = { 'vue' },
  configNamespace = 'typescript',
  enableForWorkspaceTypeScriptVersions = true,
}

return {
  cmd = { 'vtsls', '--stdio' },
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
  root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
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
          entriesLimit = 100,
        },
        maxInlayHintLength = 30,
      },
      typescript = {
        tsserver = {
          maxTsServerMemory = 8192,
          logVerbosity = "off",
          useSyntaxServer = "auto",
        },
      },
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
          removeUnusedImports = { enabled = true },
          organizeImports = { enabled = true },
        },
      },
      referencesCodeLens = {
        enabled = true,
        showOnAllFunctions = true,
      },
      implementationsCodeLens = {
        enabled = true,
      },
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
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
}
