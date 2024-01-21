local t = require('telescope')
local cf = t.load_extension('changed_files')

t.load_extension('git_worktree')

local builtin = require('telescope.builtin')
-- Finder
vim.keymap.set('n', '<leader>ff',
    function() builtin.git_files({ find_command = { 'rg', '--files', '--iglob', '!.git', '--hidden' } }) end, {})
vim.keymap.set('n', '<leader>fa',
    function() builtin.find_files({ find_command = { 'rg', '--files', '--iglob', '!.git', '--hidden' } }) end, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
vim.keymap.set('n', '<leader>fo', builtin.oldfiles, {})
vim.keymap.set('n', '<leader>fi', builtin.current_buffer_fuzzy_find, {})

-- Git
vim.keymap.set('n', '<leader>gc', builtin.git_commits, {})
vim.keymap.set('n', '<leader>gx', builtin.git_stash, {})
vim.keymap.set('n', '<leader>gs', builtin.git_status, {})
vim.keymap.set('n', '<leader>gb', builtin.git_branches, {})
vim.keymap.set('n', '<leader>gf', cf.changed_files, {})
vim.keymap.set('n', '<leader>gw', t.extensions.git_worktree.git_worktrees, {})
vim.keymap.set('n', '<leader>ga', t.extensions.git_worktree.create_git_worktree, {})

-- Grep
vim.keymap.set('n', '<leader>fs', builtin.grep_string, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})

-- Commands
vim.keymap.set('n', '<leader>tc', builtin.commands, {})
vim.keymap.set('n', '<leader>th', builtin.command_history, {})

-- Lsp
vim.keymap.set('n', '<leader>lr', builtin.lsp_references, {})
vim.keymap.set('n', '<leader>ld', builtin.diagnostics, {})
