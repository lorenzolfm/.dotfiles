require('lualine').setup({
    options = { theme = 'onedark' },
    sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { 'filename' },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress', 'selectioncount' },
        lualine_z = { 'location' }
    },
})
