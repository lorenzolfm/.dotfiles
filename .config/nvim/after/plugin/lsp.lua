local lsp_zero = require('lsp-zero')

lsp_zero.on_attach(function(_, bufnr)
    -- see :help lsp-zero-keybindings
    -- to learn the available actions
    lsp_zero.default_keymaps({ buffer = bufnr })

    lsp_zero.buffer_autoformat()
end)

lsp_zero.set_sign_icons({
    error = '❌',
    warn = '❗',
    hint = '💚',
    info = 'ℹ️',
})

require('mason').setup({})
require('mason-lspconfig').setup({
    ensure_installed = {
        'svelte',
        'tsserver',
        'eslint',
        'rust_analyzer',
        'jsonls',
        'bashls',
        'tailwindcss',
    },
    handlers = {
        lsp_zero.default_setup,

        lua_ls = function()
            local lua_opts = lsp_zero.nvim_lua_ls()
            require('lspconfig').lua_ls.setup(lua_opts)
        end,

        sqlls = function()
            require('lspconfig').sqlls.setup({
                single_file_support = true,
            })
        end,

        bashls = function()
            require('lspconfig').bashls.setup({
                single_file_support = true,
            })
        end,
    }
})

local cmp = require('cmp')
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
        -- scroll up and down the documentation window
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
        --['<Tab>'] = cmp.mapping.select_next_item(),
        --['<S-Tab>'] = cmp.mapping.select_prev_item(),
        ['<C-u>'] = cmp.mapping.scroll_docs(-4),
        ['<C-d>'] = cmp.mapping.scroll_docs(4),
    }),
})

local lspsaga = require('lspsaga')

lspsaga.setup({
    event = 'LspAttach',
    request_timeout = 10000,
})
