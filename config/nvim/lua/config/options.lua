-- ~/.config/nvim/lua/config/options.lua
-- General editor options: line numbers + indentation. Per-language indent is
-- further refined by treesitter and the formatters in plugins/dev.lua on save.

local opt = vim.opt

-- line numbers
opt.number = true -- absolute number on the cursor line
opt.relativenumber = true -- relative numbers on the others (fast j/k motions)
opt.signcolumn = "yes" -- always show the sign column so text doesn't shift

-- indentation: 4-wide, spaces instead of tabs
opt.expandtab = true -- insert spaces when pressing <Tab>
opt.tabstop = 4 -- a literal tab renders as 4 columns
opt.softtabstop = 4 -- <Tab>/<BS> move by 4 in insert mode
opt.shiftwidth = 4 -- >> / << and autoindent step by 4
opt.autoindent = true -- carry the current line's indent to the next
opt.breakindent = true -- wrapped lines keep their indentation
