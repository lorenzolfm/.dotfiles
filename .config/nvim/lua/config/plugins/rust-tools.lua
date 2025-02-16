return {
    "simrat39/rust-tools.nvim",
    config = function()
        local rust_tools = require("rust-tools")

        rust_tools.setup({
            tools = {
                autoSetHints = true,
                inlay_hints = {
                    show_parameter_hints = true,
                    parameter_hints_prefix = "<= ",
                    other_hints_prefix = "=> "
                },
            },
        })
    end
}
