return {
    "dmtrKovalenko/fff.nvim",
    build = function()
        require("fff.download").download_or_build_binary()
    end,
    lazy = false,
    keys = {
        { "<leader>ff", function() require("fff").find_files() end, desc = "Find files (fff)" },
        { "<leader>fa", function() require("fff").find_files() end, desc = "Find all files (fff)" },
        { "<leader>fg", function() require("fff").live_grep() end, desc = "Live grep (fff)" },
        { "<leader>fw", function() require("fff").live_grep({ query = vim.fn.expand("<cword>") }) end, desc = "Grep word under cursor (fff)" },
    },
}
