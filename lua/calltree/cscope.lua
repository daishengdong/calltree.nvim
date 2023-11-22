local M = {}

local cscope_push_tagstack = function()
    local from = { vim.fn.bufnr("%"), vim.fn.line("."), vim.fn.col("."), 0 }
    local items = { { tagname = vim.fn.expand("<cword>"), from = from } }
    local ts = vim.fn.gettagstack()
    local ts_last_item = ts.items[ts.length]

    if
        ts_last_item
        and ts_last_item.tagname == items[1].tagname
        and ts_last_item.from[1] == items[1].from[1]
        and ts_last_item.from[2] == items[1].from[2]
    then
        -- Don't push duplicates on tagstack
        return
    end

    vim.fn.settagstack(vim.fn.win_getid(), { items = items }, "t")
end

local cscope_parse_line = function(line)
    local t = {}

    -- Populate t with filename, context and linenumber
    local sp = vim.split(line, "%s+")
    t["filename"] = sp[1]
    t["ctx"] = sp[2]
    t["lnum"] = sp[3]
    t["col"] = 0
    local sz = #sp[1] + #sp[2] + #sp[3] + 3

    -- Populate t["text"] with search result
    t["text"] = string.sub(line, sz, -1)

    return t
end

local cscope_parse_output = function(cs_out)
    -- Parse cscope output to be populated in QuickFix List
    -- setqflist() takes list of dicts to be shown in QF List. See :h setqflist()

    local res = {}

    for line in string.gmatch(cs_out, "([^\n]+)") do
        if line ~= "File does not have expected format" then
            local parsed_line = cscope_parse_line(line)
            table.insert(res, parsed_line)
        end
    end

    return res
end

local cscope_find_helper = function(op_n, op_s, symbol_name)
    -- Executes cscope search and shows result in QuickFix List or Telescope

    local db_file = vim.g.cscope_maps_db_file or require("cscope").opts.db_file
    local cmd = "cscope " .. "-f " .. db_file

    if vim.loop.fs_stat(db_file) == nil then
        vim.notify("db file not found [" .. db_file .. "]. Create using :Cs build")
        return {}
    end

    cmd = cmd .. " -dL" .. " -" .. op_n .. " " .. symbol_name

    local file = assert(io.popen(cmd, "r"))
    file:flush()
    local output = file:read("*all")
    file:close()

    if output == "" then
        vim.notify("no results for 'cscope find " .. op_s .. " " .. symbol_name .. "'")
        return {}
    end

    local parsed_output = cscope_parse_output(output)

    -- Push current symbol on tagstack
    cscope_push_tagstack()

    return parsed_output
end

M.find_defination = function(symbol_name)
    local op_s = "g"
    local op_n = "1"

    return cscope_find_helper(op_n, op_s, symbol_name)
end

M.find_caller = function(symbol, symbol_name)
    local op_s = "c"
    local op_n = "3"

    symbol = symbol -- make lsp happy
    return cscope_find_helper(op_n, op_s, symbol_name)
end

M.find_callee = function(symbol, symbol_name)
    local op_s = "d"
    local op_n = "2"

    symbol = symbol -- make lsp happy
    return cscope_find_helper(op_n, op_s, symbol_name)
end

return M
