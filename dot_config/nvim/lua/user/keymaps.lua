local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

keymap("n", "<Space>", "", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

keymap("n", "<C-i>", "<C-i>", opts)

keymap("n", "<m-tab>", "<c-6>", opts)

keymap("n", "n", "nzz", opts)
keymap("n", "N", "Nzz", opts)
keymap("n", "*", "*zz", opts)
keymap("n", "#", "#zz", opts)
keymap("n", "g*", "g*zz", opts)
keymap("n", "g#", "g#zz", opts)

keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

keymap("x", "p", [["_dP]])

keymap({ "n", "o", "x" }, "<s-h>", "^", opts)
keymap({ "n", "o", "x" }, "<s-l>", "g_", opts)

keymap({ "n", "x" }, "j", "gj", opts)
keymap({ "n", "x" }, "k", "gk", opts)
keymap("n", "<leader>w", ":lua vim.wo.wrap = not vim.wo.wrap<CR>", opts)

keymap("n", "<PageDown>", ":m .+1<CR>==", opts)
keymap("n", "<PageUp>", ":m .-2<CR>==", opts)
keymap("v", "<PageDown>", ":m '>+1<CR>gv=gv", opts)
keymap("v", "<PageUp>", ":m '<-2<CR>gv=gv", opts)

vim.api.nvim_set_keymap("t", "<C-;>", "<C-\\><C-n>", opts)

keymap("n", "<C-h>", "zc", opts)
keymap("n", "<C-l>", "zo", opts)

keymap("n", "<leader><tab>c", ":tabclose<CR>", opts)
keymap("n", "<leader><tab>n", ":tabnew<CR>", opts)
keymap("n", "<leader><tab>o", ":tabonly<CR>", opts)
keymap("n", "<leader><tab>h", ":tabprevious<CR>", opts)
keymap("n", "<leader><tab>l", ":tabnext<CR>", opts)
