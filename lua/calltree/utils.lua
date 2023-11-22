local M = {}

local function file_open(window, filename, lnum, col)
    vim.api.nvim_set_current_win(window)
    vim.cmd("e " .. filename)
    vim.api.nvim_win_set_cursor(0, { tonumber(lnum), tonumber(col) })
    return vim.api.nvim_win_get_buf(window), window
end

M.symbol_open = function(window, symbol)
    local filename = symbol.filename
    local lnum = symbol.lnum
    local col = symbol.col

    return file_open(window, filename, lnum, col)
end

M.get_previous_window = function()
    vim.cmd(":wincmd p")
    local previous_window = vim.api.nvim_get_current_win()
    vim.cmd(":wincmd p")
    return previous_window
end

return M
