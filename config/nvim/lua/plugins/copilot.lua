-- ~/.config/nvim/lua/plugins/copilot.lua
-- ============================================================================
-- GitHub Copilot (zbirenbaum/copilot.lua) — surfaced two ways:
--   * inline ghost text  — copilot.lua's own suggestion module (configured here)
--   * blink completion menu — via blink-cmp-copilot, wired into blink's sources
--     in dev.lua (provider "copilot")
--
-- Accept the inline ghost text with <Tab>. The smart <Tab> itself lives in
-- dev.lua's blink keymap (so it can see whether the blink menu has a selection
-- and pick LSP-vs-Copilot correctly); here we just disable Copilot's own accept
-- key so the two don't fight. blink's menu is driven by C-y/C-n/C-p.
-- The cycle/dismiss keys stay on Alt. Run `:Copilot auth` once to sign in.
-- ============================================================================

return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true, -- show inline ghost text as you type
        keymap = {
          accept = false, -- accepted via the smart <Tab> in dev.lua's blink keymap
          accept_word = "<M-Right>",
          accept_line = false,
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      -- Panel UI not used; completions come through inline ghost text + blink.
      panel = { enabled = false },
    },
  },
}
