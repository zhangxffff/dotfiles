-- ~/.config/nvim/lua/plugins/copilot.lua
-- ============================================================================
-- GitHub Copilot (zbirenbaum/copilot.lua) — surfaced two ways:
--   * inline ghost text  — copilot.lua's own suggestion module (configured here)
--   * blink completion menu — via blink-cmp-copilot, wired into blink's sources
--     in dev.lua (provider "copilot")
--
-- Accept the inline ghost text with <Tab> (smart: if no suggestion is showing it
-- inserts a normal Tab, so indentation still works). blink's Tab is cleared in
-- dev.lua so the two don't fight; blink's own menu is driven by C-y/C-n/C-p.
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
          accept = false, -- handled by the smart <Tab> mapping in config below
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
    config = function(_, opts)
      require("copilot").setup(opts)

      -- <Tab>: accept the Copilot suggestion if one is visible, otherwise fall
      -- back to inserting a real Tab (so it still indents when there's nothing
      -- to accept).
      vim.keymap.set("i", "<Tab>", function()
        local suggestion = require("copilot.suggestion")
        if suggestion.is_visible() then
          suggestion.accept()
        else
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, true, true), "n", false)
        end
      end, { desc = "Copilot: accept suggestion or insert Tab" })
    end,
  },
}
