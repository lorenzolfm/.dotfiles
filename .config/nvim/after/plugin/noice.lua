local noice = require('noice')
local nvim_notify = require('notify')


noice.setup({
    bottom_search = true,         -- use a classic bottom cmdline for search
    command_palette = true,       -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    inc_rename = false,           -- enables an input dialog for inc-rename.nvim
    lsp_doc_border = false,       -- add a border to hover docs and signature help
})

nvim_notify.setup({
    top_down = false,
    background_colour = "#282828",
})
