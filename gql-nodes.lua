local Clazz = require("clazz")

local Document = Clazz.class("Gql.Document")
local Operation = Clazz.class("Gql.Operation")
local RootField = Clazz.class("Gql.RootField")

local function max(x, y)
    if x > y then
        return x
    else
        return y
    end
end

function Document:listOps()
    if not self._ops then
        local tmp = {}
        for _, v in ipairs(self) do
            if not v.fragment then
                local op = Operation:new(v)
                op.parent_doc = self
                table.insert(tmp, op)
            end
        end
        self._ops = tmp
    end
    return self._ops
end

function Document:findFragment(name)
    for _, v in ipairs(self) do
        if v.fragment and v.fragment == name then
            return v
        end
    end
    return nil
end

function Document:hasFields(pattern_list)
    local fragment_safety_lock = {}
    local output = {}
    local list = self:listOps()
    for _, operation in ipairs(list) do
        local roots = operation:getRootFields()
        for _, root in ipairs(roots) do
            RootField._hasFields(root, self, pattern_list, root.name, output, fragment_safety_lock)
        end
    end
    if #output > 0 then
        return output
    else
        return nil
    end
end

function Document:nestDepth()
    local max_depth = 0
    local fragment_safety_lock = {}
    local list = self:listOps()
    for _, operation in ipairs(list) do
        local roots = operation:getRootFields()
        for _, root in ipairs(roots) do
            local tmp = RootField._nestDepth(root, self, fragment_safety_lock) + 1
            max_depth = max(max_depth, tmp)
        end
    end
    return max_depth
end


function Operation:getRootFields()
    if not self._roots then
        local tmp = {}
        for _, v in ipairs(self.fields) do
            local f = RootField:new(v)
            v.parent_op = self
            table.insert(tmp, f)
        end
        self._roots = tmp
    end
    return self._roots
end

function Operation:findVariable(name)
    for _, item in pairs(self.variables) do
        if item.name == name then
            return item
        end
    end
    return nil
end

function RootField:resolveArgument(input)
    local result = {}
    local args = self.arguments
    for _, arg in ipairs(args) do
        local item = {}
        local value = arg.value
        if string.match(value, "^%$") then
            local variable = self.parent_op:findVariable(value)
            item["type"] = variable.type
            local tmp = string.sub(value, 2)
            local input_value = input[tmp]
            if input_value then
                item["value"] = input_value
            elseif variable.default_value then
                item["value"] = variable.default_value
            end
        else
            item["value"] = value
        end
        result[arg.name] = item
    end
    return result
end

function RootField._hasFields(this, parent_doc, pattern_list, prefix, output, fragment_safety_lock)
    if not this.fields then
        return
    end

    for _, field in ipairs(this.fields) do
        if field.fragment then
            -- we don't do recursive fragment in here
            if not fragment_safety_lock[field.fragment] then
                fragment_safety_lock[field.fragment] = 1
                local frag = parent_doc:findFragment(field.fragment)
                RootField._hasFields(frag, parent_doc, pattern_list, prefix, output, fragment_safety_lock)
            end
        elseif field.on then
            RootField._hasFields(field, parent_doc, pattern_list, prefix, output, fragment_safety_lock)
        else
            for _, pattern in ipairs(pattern_list) do
                if string.match(field.name, pattern) then
                    table.insert(output, prefix .. "." .. field.name)
                    break
                end
            end
            RootField._hasFields(field, parent_doc, pattern_list, prefix .. "." .. field.name, output, fragment_safety_lock)
        end
    end
end

function RootField._nestDepth(this, parent_doc, fragment_safety_lock)
    if not this.fields then
        return 0
    end

    local max_depth = 0
    for _, field in ipairs(this.fields) do
        if field.fragment then
            -- we don't do recursive fragment in here
            if not fragment_safety_lock[field.fragment] then
                fragment_safety_lock[field.fragment] = 1
                local frag = parent_doc:findFragment(field.fragment)
                local tmp = RootField._nestDepth(frag, parent_doc)
                max_depth = max(max_depth, tmp)
            end
        elseif field.on then
            local tmp = RootField._nestDepth(field, parent_doc)
            max_depth = max(max_depth, tmp)
        else
            if field.fields then
                local tmp = RootField._nestDepth(field, parent_doc) + 1
                max_depth = max(max_depth, tmp)
            end
        end
    end
    return max_depth
end

return {
    Document = Document,
    Operation = Operation,
    RootField = RootField
}
