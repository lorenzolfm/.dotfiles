local lsp_zero = require('lsp-zero')
local lspconfig = require('lspconfig')
local mason = require('mason');
local mason_lspconfig = require('mason-lspconfig');
local cmp = require('cmp')
local lspsaga = require('lspsaga')

lsp_zero.on_attach(function(_, bufnr)
    lsp_zero.default_keymaps({ buffer = bufnr })

    lsp_zero.buffer_autoformat()
end)

lsp_zero.set_sign_icons({
    error = '❌',
    warn = '❗',
    hint = '💚',
    info = 'ℹ️',
})

local ensure_installed = {
    'bashls',
    'bufls',
    'eslint',
    'jsonls',
    'lua_ls',
    'rust_analyzer',
    'svelte',
    'tailwindcss',
    'tsserver',
    'mesonlsp',
    'bufls',
    'html',
    'sqlls',
    'tsserver',
}

local lsp_servers_with_single_file_support = {
    'bashls',
    'bufls',
    'bufls',
    'jsonls',
}

local function setup_lsp_servers(servers)
    for _, server in ipairs(servers) do
        lspconfig[server].setup({
            single_file_support = true,
        })
    end
end

lspconfig.sumneko_lua.setup({
    settings = {
        Lua = {
            diagnostics = {
                globals = { 'vim' },
            },
        }
    }
})

setup_lsp_servers(lsp_servers_with_single_file_support)

mason.setup({})
mason_lspconfig.setup({
    ensure_installed,
    handlers = {
        lsp_zero.default_setup,
    }
})

local cmp_format = lsp_zero.cmp_format()

cmp.setup({
    formatting = cmp_format,
    sources = {
        { name = 'nvim_lsp' },
        { name = 'buffer' },
        { name = 'path' },
        { name = 'vim-dadbod-completion' },
    },
    mapping = cmp.mapping.preset.insert({
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
        ['<C-u>'] = cmp.mapping.scroll_docs(-4),
        ['<C-d>'] = cmp.mapping.scroll_docs(4),
    }),
})

lspsaga.setup({
    event = 'LspAttach',
    request_timeout = 10000,
    lightbulb = {
        virtual_text = false,
    },
})
