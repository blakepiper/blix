-- LazyVim loads these after its defaults.
-- Show each line's absolute file number in both editor layouts.
vim.opt.number = true
vim.opt.relativenumber = false

-- Only the IDE layout needs wrapping
-- by default, since its explorer and terminals leave less room for code.
if vim.env.NVIM_IDE == "1" then
  vim.opt.wrap = true
  vim.opt.linebreak = true
  vim.opt.breakindent = true
end
