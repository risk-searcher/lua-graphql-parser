function instanceOf(object, clazz)
    local mt = getmetatable(object)
    while true do
        if mt == nil then return false end
        if mt == clazz then return true end
        mt = getmetatable(mt)
    end
end