function instanceOf(object, clazz)
    if nil == object then return nil == clazz end
    local mt = getmetatable(object)
    while true do
        if mt == nil then return false end
        if mt == clazz then return true end
        mt = getmetatable(mt)
    end
end

function safeGet(table, key)
    local idx = key:find(".", 1, true)
    local firstKey = key
    if nil ~= idx then
        firstKey = key:sub(1, idx-1)
    end
    if table[firstKey] == nil then
        table[firstKey] = {}
    end
    if nil == idx then
        return table[firstKey]
    else
        return safeGet(table[firstKey], key:sub(idx+1))
    end
end