local opts = {
    tools = {
        autoSetHints = true,
        inlay_hints = {
            show_parameter_hints = true,
            parameter_hints_prefix = "<= ",
            other_hints_prefix = "=> "
        },
    },
}

require("rust-tools").setup(opts)
