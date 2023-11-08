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

mason.setup({})
mason_lspconfig.setup({
    ensure_installed = {
        'bashls',
        'bufls',
        'eslint',
        'jsonls',
        'lua_ls',
        'rust_analyzer',
        'svelte',
        'tailwindcss',
        'tsserver',
    },
    handlers = {
        lsp_zero.default_setup,

        lua_ls = function()
            local lua_opts = lsp_zero.nvim_lua_ls()
            lspconfig.lua_ls.setup(lua_opts)
        end,

        sqlls = function()
            lspconfig.sqlls.setup({
                single_file_support = true,
            })
        end,

        bashls = function()
            lspconfig.bashls.setup({
                single_file_support = true,
            })
        end,

        bufls = function()
            lspconfig.bufls.setup({
                single_file_support = true,
            })
        end,

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
})
