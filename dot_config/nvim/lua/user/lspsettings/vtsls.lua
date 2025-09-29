-- Dynamic path resolution for Vue language server (Mason 2025 compatible)
local function get_vue_plugin_path()
  -- Try Mason registry first (preferred method)
  local ok, mason_registry = pcall(require, 'mason-registry')
  if ok and mason_registry.is_installed('vue-language-server') then
    local vue_pkg = mason_registry.get_package('vue-language-server')
    local install_path = vue_pkg:get_install_path()
    return install_path .. '/node_modules/@vue/language-server'
  end

  -- Fallback to environment variable expansion
  local fallback_paths = {
    vim.fn.expand('$MASON/packages/vue-language-server/node_modules/@vue/language-server'),
    vim.fn.expand('$MASON/packages/vue-language-server/node_modules/@vue/typescript-plugin'),
  }

  for _, path in ipairs(fallback_paths) do
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
  end

  return nil
end

local vue_plugin_path = get_vue_plugin_path()
local vue_plugin = vue_plugin_path and {
  name = '@vue/typescript-plugin',
  location = vue_plugin_path,
  languages = { 'vue' },
  configNamespace = 'typescript',
  enableForWorkspaceTypeScriptVersions = true,
} or nil

return {
  cmd = { 'vtsls', '--stdio' },
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
  settings = {
    vtsls = {
      tsserver = {
        globalPlugins = vue_plugin and {
          vue_plugin,
        } or {},
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
