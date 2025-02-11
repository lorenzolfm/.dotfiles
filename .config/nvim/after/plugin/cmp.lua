local lsp_zero = require('lsp-zero')
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
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
        ['<C-u>'] = cmp.mapping.scroll_docs(-4),
        ['<C-d>'] = cmp.mapping.scroll_docs(4),
    }),
})
