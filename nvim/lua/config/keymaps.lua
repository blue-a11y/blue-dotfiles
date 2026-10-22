-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- ============================================================
-- Buffer 管理
-- ============================================================

-- 回到 Dashboard（关闭所有 buffer 后重新打开 dashboard）
vim.keymap.set("n", "<leader>;", function()
  vim.cmd("%bdelete")
  Snacks.dashboard.open()
end, { desc = "Open Dashboard" })

-- 关闭所有 buffer
vim.keymap.set("n", "<leader>ba", function()
  vim.cmd("%bdelete")
end, { desc = "Delete All Buffers" })

-- ============================================================
-- 终端
-- ============================================================

-- 一键 toggle 所有浮动终端的显隐（有任意一个可见就全部隐藏，否则全部显示）
vim.keymap.set({ "n", "t" }, "<leader>tg", function()
  local terms = Snacks.terminal.list()
  if #terms == 0 then
    vim.notify("没有打开的终端")
    return
  end
  -- 判断是否有可见的终端窗口
  local any_visible = false
  for _, t in ipairs(terms) do
    if t.win and vim.api.nvim_win_is_valid(t.win) then
      any_visible = true
      break
    end
  end
  -- 统一切换
  for _, t in ipairs(terms) do
    if any_visible then
      t:hide()
    else
      t:show()
    end
  end
  vim.notify(any_visible and "隐藏所有终端" or "显示所有终端")
end, { desc = "Toggle All Terminals" })

-- ============================================================
-- 窗口切换
-- ============================================================

-- 分屏窗口切换：Ctrl + h/j/k/l（Normal + Terminal 都能用）
vim.keymap.set({ "n", "t" }, "<C-h>", "<Cmd>wincmd h<CR>", { desc = "Window Left" })
vim.keymap.set({ "n", "t" }, "<C-j>", "<Cmd>wincmd j<CR>", { desc = "Window Down" })
vim.keymap.set({ "n", "t" }, "<C-k>", "<Cmd>wincmd k<CR>", { desc = "Window Up" })
vim.keymap.set({ "n", "t" }, "<C-l>", "<Cmd>wincmd l<CR>", { desc = "Window Right" })

-- ============================================================
-- Neovide 窗口管理
-- ============================================================

-- 在同一 Neovide 实例开新窗口（共享 nvim 进程，像多标签页）
vim.keymap.set("n", "<leader>wn", function()
  vim.fn.jobstart({ "neovide", "--reuse-instance", "--new-window" }, { detach = true })
end, { desc = "New Neovide Window" })

-- 重启 Neovide
vim.keymap.set("n", "<leader>qr", function()
  vim.cmd("wa")
  local cwd = vim.fn.getcwd()
  vim.fn.jobstart({ "neovide", "--reuse-instance", "--new-window", cwd }, { detach = true })
  local pid = vim.fn.getpid()
  vim.defer_fn(function()
    os.execute("kill -9 " .. pid .. " 2>/dev/null")
  end, 500)
end, { desc = "Restart Neovide" })
