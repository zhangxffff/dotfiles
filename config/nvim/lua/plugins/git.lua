-- ~/.config/nvim/lua/plugins/git.lua
-- ============================================================================
-- Git:gitsigns(行内实时)+ diffview(diff 浏览 / 跟 main 比 / 文件历史)
-- 复杂操作(rebase/cherry-pick/stash)仍交给你已有的 lazygit
-- ============================================================================

return {
  -- ==========================================================================
  -- gitsigns:行号旁标 hunk、stage/reset/preview、行内 blame、hunk 间跳转
  -- ==========================================================================
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      -- 行内 blame 默认关(觉得有用再开 true,或用下面的 <leader>hb 按需看)
      current_line_blame = false,
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(k, fn, desc)
          vim.keymap.set("n", k, fn, { buffer = buf, desc = "Git: " .. desc })
        end

        -- hunk 间跳转
        map("]c", function() gs.nav_hunk("next") end, "下一个 hunk")
        map("[c", function() gs.nav_hunk("prev") end, "上一个 hunk")

        -- hunk 操作
        map("<leader>hs", gs.stage_hunk, "stage hunk")
        map("<leader>hr", gs.reset_hunk, "reset hunk")
        map("<leader>hu", gs.undo_stage_hunk, "撤销 stage hunk")
        map("<leader>hp", gs.preview_hunk, "预览 hunk")

        -- 整文件
        map("<leader>hS", gs.stage_buffer, "stage 整个文件")
        map("<leader>hR", gs.reset_buffer, "reset 整个文件")

        -- blame
        map("<leader>hb", function() gs.blame_line({ full = true }) end, "blame 本行")
        map("<leader>hB", gs.toggle_current_line_blame, "切换行内 blame")
      end,
    },
  },

  -- ==========================================================================
  -- diffview:工作区 diff、跟任意 rev(如 main)比、当前文件 git 历史
  -- ==========================================================================
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "工作区 diff" },
      { "<leader>gm", "<cmd>DiffviewOpen main<cr>", desc = "跟 main 比" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "当前文件 git 历史" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "整仓 git 历史" },
      { "<leader>gx", "<cmd>DiffviewClose<cr>", desc = "关闭 diffview" },
    },
    opts = {
      enhanced_diff_hl = true, -- 更清晰的 diff 高亮
    },
  },
}
