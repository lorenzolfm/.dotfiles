return {
    "ThePrimeagen/harpoon",
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
        local hm = require('harpoon.mark')
        local hui = require('harpoon.ui')

        -- Mark
        vim.keymap.set('n', '<leader>hm', hm.add_file, {})

        -- UI
        vim.keymap.set('n', '<leader>hui', hui.toggle_quick_menu, {})
        vim.keymap.set('n', '<leader>nn', hui.nav_next, {})
        vim.keymap.set('n', '<leader>pp', hui.nav_prev, {})
        vim.keymap.set('n', '<leader>h1', function() hui.nav_file(1) end, {})
        vim.keymap.set('n', '<leader>h2', function() hui.nav_file(2) end, {})
        vim.keymap.set('n', '<leader>h3', function() hui.nav_file(3) end, {})
        vim.keymap.set('n', '<leader>h4', function() hui.nav_file(4) end, {})

        local th = require('telescope').load_extension('harpoon')

        vim.keymap.set('n', '<leader>fm', th.marks, {})
    end
}
