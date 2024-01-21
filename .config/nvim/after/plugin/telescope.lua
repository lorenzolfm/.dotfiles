local t = require('telescope')
local tb = require('telescope.builtin')

t.load_extension('git_worktree')

-- Finder
vim.keymap.set('n', '<leader>ff',
    function() tb.git_files({ find_command = { 'rg', '--files', '--iglob', '!.git', '--hidden' } }) end, {})
vim.keymap.set('n', '<leader>fa',
    function() tb.find_files({ find_command = { 'rg', '--files', '--iglob', '!.git', '--hidden' } }) end, {})
vim.keymap.set('n', '<leader>fb', tb.buffers, {})
vim.keymap.set('n', '<leader>fh', tb.help_tags, {})
vim.keymap.set('n', '<leader>fo', tb.oldfiles, {})
vim.keymap.set('n', '<leader>fi', tb.current_buffer_fuzzy_find, {})

-- Git
vim.keymap.set('n', '<leader>gc', tb.git_commits, {})
vim.keymap.set('n', '<leader>gx', tb.git_stash, {})
vim.keymap.set('n', '<leader>gs', tb.git_status, {})
vim.keymap.set('n', '<leader>gb', tb.git_branches, {})
vim.keymap.set('n', '<leader>gw', t.extensions.git_worktree.git_worktrees, {})
vim.keymap.set('n', '<leader>ga', t.extensions.git_worktree.create_git_worktree, {})
vim.keymap.set('n', '<leader>gf', t.load_extension('changed_files').changed_files, {})

-- Grep
vim.keymap.set('n', '<leader>fs', tb.grep_string, {})
vim.keymap.set('n', '<leader>fg', tb.live_grep, {})

-- Commands
vim.keymap.set('n', '<leader>tc', tb.commands, {})
vim.keymap.set('n', '<leader>th', tb.command_history, {})

-- Lsp
vim.keymap.set('n', '<leader>lr', tb.lsp_references, {})
vim.keymap.set('n', '<leader>ld', tb.diagnostics, {})
