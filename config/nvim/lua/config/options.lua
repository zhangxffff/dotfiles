-- ~/.config/nvim/lua/config/options.lua
-- General editor options: line numbers + indentation. Per-language indent is
-- further refined by treesitter and the formatters in plugins/dev.lua on save.

-- Leader must be set before any <leader> mapping is created. This file is
-- required before config.lazy, so set it here (lazy.lua sets the same values
-- again, which is harmless).
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

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

-- mouse on so dragging makes a visual selection
opt.mouse = "a"

-- System clipboard over SSH: route the +/* registers through the terminal via
-- OSC 52, which reaches your LOCAL machine's clipboard across zellij/Ghostty.
-- (xclip/wl-copy are no use here: there's no X/Wayland display, and they'd only
-- touch this remote box's clipboard.) Needs Neovim >= 0.10.
local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
if ok then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
  }
end

-- Copy on mouse select: when a drag-selection ends, yank it to the system
-- clipboard (sent out via OSC 52 above). Keyboard y/p are untouched (we don't
-- set clipboard=unnamedplus), so use "+y / "+p for explicit clipboard access.
vim.keymap.set("x", "<LeftRelease>", '"+y<LeftRelease>', {
  desc = "Copy mouse selection to system clipboard",
})

-- Jump back in the jumplist (same as <C-o>) on <leader>o; e.g. after gd.
vim.keymap.set("n", "<leader>o", "<C-o>", { desc = "Jump back (jumplist)" })
