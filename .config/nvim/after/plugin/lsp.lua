local lspconfig = require('lspconfig')
local lsp_zero = require('lsp-zero')
local lspsaga = require('lspsaga')

lsp_zero.on_attach(function(_, bufnr)
    lsp_zero.default_keymaps({ buffer = bufnr })
    lsp_zero.buffer_autoformat()
end)

lsp_zero.set_sign_icons({
    error = '🔺',
    warn = '🔸',
    hint = 'ℹ️',
    info = '🔹',
})


local lsp_servers_with_single_file_support = {
    'bashls',
    'jq',
    'protols',
    'sqls',
    'yamlls',
}

local function setup_lsp_servers(servers)
    for _, server in ipairs(servers) do
        lspconfig[server].setup({
            single_file_support = true,
        })
    end
end

lspconfig.lua_ls.setup {}
lspconfig.rust_analyzer.setup {}
lspconfig.svelte.setup {}

setup_lsp_servers(lsp_servers_with_single_file_support)

lspsaga.setup({
    event = 'LspAttach',
    request_timeout = 10000,
    lightbulb = {
        virtual_text = false,
    },
})
