local keymap = vim.keymap.set
keymap("n", "gh", "<cmd>Lspsaga finder<CR>")
keymap({ "n", "v" }, "<leader>aa", "<cmd>Lspsaga code_action<CR>")
keymap("n", "gp", "<cmd>Lspsaga peek_definition<CR>")
keymap("n", "<leader>d", "<cmd>Lspsaga show_line_diagnostics<CR>")
keymap("n", "<leader>dc", "<cmd>Lspsaga show_cursor_diagnostics<CR>")
keymap("n", "<leader>db", "<cmd>Lspsaga show_buf_diagnostics<CR>")
keymap("n", "[d", "<cmd>Lspsaga diagnostic_jump_prev<CR>")
keymap("n", "]d", "<cmd>Lspsaga diagnostic_jump_next<CR>")
keymap("n", "[e", function()
    require("lspsaga.diagnostic"):goto_prev({ severity = vim.diagnostic.severity.ERROR })
end)
keymap("n", "]e", function()
    require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.ERROR })
end)
keymap("n", "<leader>o", "<cmd>Lspsaga outline<CR>")
keymap("n", "<Leader>ci", "<cmd>Lspsaga incoming_calls<CR>")
keymap("n", "<Leader>co", "<cmd>Lspsaga outgoing_calls<CR>")
keymap({ "n", "t" }, "<A-t>", "<cmd>Lspsaga term_toggle<CR>")
