return {
    "nvimdev/lspsaga.nvim",
    config = function()
        local lspsaga = require('lspsaga');

        lspsaga.setup({
            event = 'LspAttach',
            request_timeout = 10000,
            ui = {
                code_action = '🔹',
            },
            lightbulb = {
                virtual_text = true,
            },
        })

        local keymap = vim.keymap.set;

        keymap("n", "<leader>aa", "<cmd>Lspsaga code_action<CR>");
        keymap("n", "gp", "<cmd>Lspsaga peek_definition<CR>")
        keymap("n", "<leader>o", "<cmd>Lspsaga outline<CR>")
    end
}
