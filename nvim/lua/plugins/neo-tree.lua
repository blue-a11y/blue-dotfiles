return {
  "nvim-neo-tree/neo-tree.nvim",
  lazy = false,
  opts = {
    window = {
      position = "left",
      width = 35, -- 固定宽度，你可以改成喜欢的数值
      mappings = {
        ["<space>"] = "none",
      },
    },
  },
  keys = {
    { "<leader>e", "<Cmd>Neotree toggle<CR>", desc = "Toggle NeoTree" },
  },
}
