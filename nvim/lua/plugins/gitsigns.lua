return {
  "lewis6991/gitsigns.nvim",
  opts = {
    current_line_blame = true,
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol",
      delay = 300,
      ignore_whitespace = false,
    },
    -- 用函数 formatter：完全控制格式 + 显示真实作者名
    current_line_blame_formatter = function(name, blame_info)
      local author = blame_info.author
      -- 未提交的行
      if author == "Not Committed Yet" then
        return { { "    ✎未提交", "Comment" } }
      end
      local time = os.date("%Y-%m-%d", blame_info["author_time"])
      return {
        { "    @", "Comment" },
        { author, "Comment" },
        { ": ", "Comment" },
        { blame_info.summary, "Comment" },
        { " (" .. time .. ")", "Comment" },
      }
    end,
  },
}
