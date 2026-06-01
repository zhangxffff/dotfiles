-- ~/.config/nvim/lua/plugins/copilot.lua
-- ============================================================================
-- GitHub Copilot (zbirenbaum/copilot.lua) — surfaced two ways:
--   * inline ghost text  — copilot.lua's own suggestion module (configured here)
--   * blink completion menu — via blink-cmp-copilot, wired into blink's sources
--     in dev.lua (provider "copilot")
--
-- Both share the same copilot.lua backend. The inline-accept keys are kept on
-- Alt (<M-l> etc.) so they don't collide with blink's menu keys (C-n/C-p select,
-- C-y confirm). Run `:Copilot auth` once to sign in (needs Node + a Copilot sub).
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
          accept = "<M-l>",
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
