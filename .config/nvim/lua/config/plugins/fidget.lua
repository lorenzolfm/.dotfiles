return {
    "j-hui/fidget.nvim",
    config = function()
        local fidget = require("fidget");

        fidget.setup({
            spinner = "dots"
        })
    end
}
