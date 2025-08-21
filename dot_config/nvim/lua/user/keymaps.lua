local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Disable space key in normal mode and set leader keys
keymap("n", "<Space>", "", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Preserve Ctrl+i functionality
keymap("n", "<C-i>", "<C-i>", opts)

-- Better window navigation
keymap("n", "<m-h>", "<C-w>h", opts) -- Alt+h: Move to left window
keymap("n", "<m-j>", "<C-w>j", opts) -- Alt+j: Move to window below
keymap("n", "<m-k>", "<C-w>k", opts) -- Alt+k: Move to window above
keymap("n", "<m-l>", "<C-w>l", opts) -- Alt+l: Move to right window
keymap("n", "<m-tab>", "<c-6>", opts) -- Alt+Tab: Switch to alternate buffer

-- Center screen after search navigation
keymap("n", "n", "nzz", opts) -- Next search match + center screen
keymap("n", "N", "Nzz", opts) -- Previous search match + center screen
keymap("n", "*", "*zz", opts) -- Search word under cursor forward + center screen
keymap("n", "#", "#zz", opts) -- Search word under cursor backward + center screen
keymap("n", "g*", "g*zz", opts) -- Search partial word under cursor forward + center screen
keymap("n", "g#", "g#zz", opts) -- Search partial word under cursor backward + center screen

-- Stay in indent mode
keymap("v", "<", "<gv", opts) -- Indent left and stay in visual mode
keymap("v", ">", ">gv", opts) -- Indent right and stay in visual mode

-- Paste without losing clipboard content
keymap("x", "p", [["_dP]]) -- Paste over selection without yanking replaced text

-- Right-click context menu for LSP
vim.cmd [[:amenu 10.100 mousemenu.Goto\ Definition <cmd>lua vim.lsp.buf.definition()<CR>]]
vim.cmd [[:amenu 10.110 mousemenu.References <cmd>lua vim.lsp.buf.references()<CR>]]
-- vim.cmd [[:amenu 10.120 mousemenu.-sep- *]]

vim.keymap.set("n", "<RightMouse>", "<cmd>:popup mousemenu<CR>") -- Right-click shows context menu
vim.keymap.set("n", "<Tab>", "<cmd>:popup mousemenu<CR>") -- Tab shows context menu

-- more good
keymap({ "n", "o", "x" }, "<s-h>", "^", opts) -- Shift+h: Go to first non-blank character
keymap({ "n", "o", "x" }, "<s-l>", "g_", opts) -- Shift+l: Go to last non-blank character

-- tailwind bearable to work with
keymap({ "n", "x" }, "j", "gj", opts) -- j: Move down by display line (not actual line)
keymap({ "n", "x" }, "k", "gk", opts) -- k: Move up by display line (not actual line)
keymap("n", "<leader>w", ":lua vim.wo.wrap = not vim.wo.wrap<CR>", opts) -- Leader+w: Toggle line wrapping

-- Move lines up/down
keymap("n", "<PageDown>", ":m .+1<CR>==", opts) -- PageDown: Move line down
keymap("n", "<PageUp>", ":m .-2<CR>==", opts) -- PageUp: Move line up
keymap("v", "<PageDown>", ":m '>+1<CR>gv=gv", opts) -- PageDown: Move selected lines down
keymap("v", "<PageUp>", ":m '<-2<CR>gv=gv", opts) -- PageUp: Move selected lines up

-- Terminal mode escape
vim.api.nvim_set_keymap("t", "<C-;>", "<C-\\><C-n>", opts) -- Ctrl+; in terminal: Exit to normal mode
