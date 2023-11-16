local M = {}

M.type = {
    CALLER_TREE = 0,
    CALLEE_TREE = 1,
}

M.type_to_str = {
    [M.type.CALLER_TREE] = "CALLER",
    [M.type.CALLEE_TREE] = "CALLEE",
}

M.stringify = function(type)
    return M.type_to_str[type]
end

return M
