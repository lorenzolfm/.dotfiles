return {
    "j-hui/fidget.nvim",
    config = function()
        local fidget = require("fidget");

        fidget.setup({
            progress = {
                display = {
                    progress_icon = "dots"
                }
            }
        })
    end
}
