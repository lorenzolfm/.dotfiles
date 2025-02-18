return {
    "tpope/vim-fugitive",
    config = function()
        vim.keymap.set('n', '<leader>gl', ':Git log --oneline<CR>')
        vim.keymap.set('n', '<leader>gC', ':Git commit<CR>')
        vim.keymap.set('n', '<leader>gr', ':Git rebase -i ')
        vim.keymap.set('n', '<leader>gS', ':Git<CR>')
    end
}
