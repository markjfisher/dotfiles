-- ===================================================
-- Custom nvim setup
-- ===================================================

-- theme/transparency
-- vim.cmd.colorscheme("lunaperche")
vim.cmd.colorscheme("habamax")
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })

-- personal config setup
require("nvim_mjf")
