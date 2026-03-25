return {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local tb = require('telescope.builtin')

        -- Finder (file/grep moved to fff.nvim)
        vim.keymap.set('n', '<leader>fb', tb.buffers, {})
        vim.keymap.set('n', '<leader>fh', tb.help_tags, {})
        vim.keymap.set('n', '<leader>fo', tb.oldfiles, {})
        vim.keymap.set('n', '<leader>fi', tb.current_buffer_fuzzy_find, {})
        vim.keymap.set('n', '<leader>fs', tb.lsp_document_symbols, {})
        vim.keymap.set('n', '<leader>fS', tb.lsp_workspace_symbols, {})

        -- Git
        vim.keymap.set('n', '<leader>gc', tb.git_commits, {})
        vim.keymap.set('n', '<leader>gx', tb.git_stash, {})
        vim.keymap.set('n', '<leader>gs', tb.git_status, {})
        vim.keymap.set('n', '<leader>gb', tb.git_branches, {})

        -- Commands
        vim.keymap.set('n', '<leader>tc', tb.commands, {})
        vim.keymap.set('n', '<leader>th', tb.command_history, {})

        -- Lsp
        vim.keymap.set('n', '<leader>lr', tb.lsp_references, {})
        vim.keymap.set('n', '<leader>le', function() tb.diagnostics({ severity = vim.diagnostic.severity.ERROR }) end,
            { desc = 'Find error diagnostics' })

        vim.keymap.set('n', '<leader>tr', tb.resume, {})
    end
}
