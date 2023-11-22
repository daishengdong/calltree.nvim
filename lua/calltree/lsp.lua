local utils = require("calltree.utils")
local coroutine = require("coroutine")

local M = {}

M.__lsp_results = {}
M.__async_routine_done = false
M.__previous_window = nil
M.__previous_buffer = nil
M.__previous_cursor = nil

local function call_hierarchy(bufnr, method, title, direction, item)
    vim.lsp.buf_request(bufnr, method, { item = item }, function(err, result)
        if err then
            vim.api.nvim_err_writeln("Error handling " .. title .. ": " .. err.message)
            M.__async_routine_done = true
            return
        end

        if not result or vim.tbl_isempty(result) then
            M.__async_routine_done = true
            return
        end

        local locations = {}
        for _, ch_call in pairs(result) do
            local ch_item = ch_call[direction]
            table.insert(locations, {
                filename = vim.uri_to_fname(ch_item.uri),
                text = ch_item.name,
                lnum = ch_item.range.start.line + 1,
                col = ch_item.range.start.character + 1,
            })
        end

        M.__lsp_results = locations
        M.__async_routine_done = true
    end)
end

local function pick_call_hierarchy_item(call_hierarchy_items)
    if not call_hierarchy_items then
        return
    end
    if #call_hierarchy_items == 1 then
        return call_hierarchy_items[1]
    end
    local items = {}
    for i, item in pairs(call_hierarchy_items) do
        local entry = item.detail or item.name
        table.insert(items, string.format("%d. %s", i, entry))
    end
    local choice = vim.fn.inputlist(items)
    if choice < 1 or choice > #items then
        return
    end
    return choice
end

local function calls(symbol, direction)
    local bufnr, win

    -- the LSP must take 'bufnr' and 'win' as parameters.
    -- the root symbol should be nil, while it can be assumed to be located at
    -- window 0 (current window).
    -- the symbols of children (as well as grandchildren and subsequent levels)
    -- will not be nil. it is necessary to open the children symbols to obtain a
    -- valid 'bufnr' and window.
    -- This situation may seem a bit unusual.
    if symbol == nil then
        bufnr, win = vim.api.nvim_get_current_buf(), 0
    else
        M.__previous_window = utils.get_previous_window()
        M.__previous_buffer = vim.api.nvim_win_get_buf(M.__previous_window)
        M.__previous_cursor = vim.api.nvim_win_get_cursor(M.__previous_window)
        bufnr, win = utils.symbol_open(M.__previous_window, symbol)
    end

    local params = vim.lsp.util.make_position_params(win)
    vim.lsp.buf_request(bufnr, "textDocument/prepareCallHierarchy", params, function(err, result)
        if err then
            vim.api.nvim_err_writeln("Error when preparing call hierarchy: " .. err)
            M.__async_routine_done = true
            return
        end

        local call_hierarchy_item = pick_call_hierarchy_item(result)
        if not call_hierarchy_item then
            M.__async_routine_done = true
            return
        end

        if direction == "from" then
            call_hierarchy(bufnr, "callHierarchy/incomingCalls", "LSP Incoming Calls", direction, call_hierarchy_item)
        else
            call_hierarchy(bufnr, "callHierarchy/outgoingCalls", "LSP Outgoing Calls", direction, call_hierarchy_item)
        end
    end)
end

local function lsp_definations()
    local bufnr = vim.api.nvim_get_current_buf()
    local winnr = vim.api.nvim_get_current_win()

    local params = vim.lsp.util.make_position_params(winnr)
    vim.lsp.buf_request(bufnr, "textDocument/definition", params, function(err, result, ctx, _)
        if err then
            vim.api.nvim_err_writeln("Error when executing " .. "textDocument/definition" .. " : " .. err.message)
            M.__async_routine_done = true
            return
        end
        local flattened_results = {}
        if result then
            -- textDocument/definition can return Location or Location[]
            if not vim.tbl_islist(result) then
                flattened_results = { result }
            end

            vim.list_extend(flattened_results, result)
        end

        M.__lsp_results = flattened_results
        M.__async_routine_done = true
    end)
end

local function lsp_def_to_symbols(symbol_name, lsp_def)
    local symbols = {}

    for _, def in pairs(lsp_def) do
        local symbol = {}

        symbol["filename"] = vim.uri_to_fname(def.uri)
        symbol["ctx"] = symbol_name
        symbol["lnum"] = def.range.start.line + 1
        symbol["col"] = def.range.start.character
        symbol["text"] = ""

        table.insert(symbols, symbol)
    end

    return symbols
end

local function lsp_loc_to_symbols(symbol_name, lsp_loc)
    local symbols = {}

    for _, loc in pairs(lsp_loc) do
        local symbol = {}

        symbol["filename"] = loc.filename
        symbol["ctx"] = loc.text
        symbol["lnum"] = loc.lnum
        symbol["col"] = loc.col - 1
        symbol["text"] = symbol_name

        table.insert(symbols, symbol)
    end

    return symbols
end

-- this is an ugly solution for handling asynchronous calls,
-- and I hope there is a better way to resolve it.
local function sync_call(func)
    M.__lsp_results = {}
    M.__async_routine_done = false
    M.__previous_window = nil
    M.__previous_buffer = nil
    M.__previous_cursor = nil

    local co = coroutine.create(function()
        func()
    end)

    coroutine.resume(co)

    local retry = 0
    while not M.__async_routine_done do
        retry = retry + 1
        if retry >= 10 then
            break
        end
        vim.wait(100, function() return false end)
    end

    -- jumping to the previously edited window
    -- if the window before jumping to the calltree window is not an editing
    -- window (such as neo-tree), it will cause a display bug.
    -- so, it is best to close windows like neo-tree before invoking the calltree.
    if M.__previous_window ~= nil then
        vim.api.nvim_win_set_buf(M.__previous_window, M.__previous_buffer)
        vim.api.nvim_win_set_cursor(M.__previous_window, M.__previous_cursor)
    end
end

M.find_defination = function(symbol_name)
    sync_call(lsp_definations)
    return lsp_def_to_symbols(symbol_name, M.__lsp_results)
end

M.find_caller = function(symbol, symbol_name)
    sync_call(function() calls(symbol, "from") end)
    return lsp_loc_to_symbols(symbol_name, M.__lsp_results)
end

M.find_callee = function(symbol, symbol_name)
    sync_call(function() calls(symbol, "to") end)
    return lsp_loc_to_symbols(symbol_name, M.__lsp_results)
end

return M
