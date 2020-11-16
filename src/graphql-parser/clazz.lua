local Clazz = {}
Clazz.__name = "Clazz"

local function createNewClass(name, Base)
    local clz = { }
    clz.__name = name
    Base.__index = Base
    -- Unfortunately, metamethods are not inherited
    -- https://stackoverflow.com/questions/36229151/doesnt-lua-inheritance-include-metamethods
    for k, v in pairs{"__add", "__sub", "__mul", "__div", "__pow", "__band", "__bor", "__mod", "__unm", "__concat", "__eq", "__lt", "__le"} do
        if nil ~= Base[v] then
            clz[v] = Base[v]
        end
    end
    setmetatable(clz, Base)
    return clz
end

function Clazz.class(name, Base)
    local c = Clazz[name]
    if nil == c then
        c = createNewClass(name, Base or Clazz)
    end
    return c
end

-- this is actually "newInstance"
function Clazz:new(obj)
    obj = obj or {}
    self.__index = self
    setmetatable(obj, self)
    -- obj.__name = self.__name
    return obj
end

return Clazz
