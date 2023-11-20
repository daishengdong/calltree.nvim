local M = {}

M.opts = {
    presenter = "notify", -- alternatives: notify, win
}

local win_presenter = function(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    vim.api.nvim_open_win(bufnr, true, {
        relative = 'cursor',
        width = 50,
        height = #lines,
        row = 1,
        col = 1,
        style = 'minimal',
        border = 'single'
    })
end

local notify_presenter = function(lines)
    vim.notify(lines)
end

local function getlines(name, tbl, _indent)
    local indent = _indent or ""
    if next(tbl) == nil then
        return {}
    end

    local lines = {}
    table.insert(lines, indent .. name)
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            local sublines = getlines(tostring(key), value, indent .. '\t')
            for _, svalue in pairs(sublines) do
                table.insert(lines, svalue)
            end
        else
            table.insert(lines, indent .. "\t".. tostring(key) .. ": " .. tostring(value))
        end
    end

    return lines
end

M.dump_list = function(lines)
    if next(lines) == nil then
        local cmd = 'echo "list empty"'
        vim.api.nvim_command(cmd)
        return
    end

    M.present_fn(lines)
end

M.dump_table = function(name, tbl)
    if type(tbl) ~= "table" then
        local cmd = 'echo "' .. name .. ' not a table"'
        vim.api.nvim_command(cmd)
        return
    end

    local lines = getlines(name, tbl)

    M.dump_list(lines)
end

M.setup = function(opts)
    opts = opts or {}
    M.opts = vim.tbl_deep_extend("force", M.opts, opts)

    if M.opts.presenter == "win" then
        M.present_fn = win_presenter
    elseif M.opts.presenter == "notify" then
        M.present_fn = notify_presenter
    end
end

return M
