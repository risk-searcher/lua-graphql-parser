local Clazz = require("graphql-parser.clazz")
local Lexer = require("graphql-parser.lexer")

local NAME_PATTERN = "^[%w_][%w%d_]*$"
local VARIABLE_PATTERN = "^$?[%w_][%w%d_]*$"
local DIRECTIVE_PATTERN = "^@[%w_][%w%d_]*$"
local FRAGMENT_PATTERN = "^%.%.%."

local Parser = Clazz.class("GqlParser")
local Document = Clazz.class("GqlParser.Document")
local Operation = Clazz.class("GqlParser.Operation")
local RootField = Clazz.class("GqlParser.RootField")

local function max(x, y)
    if x > y then
        return x
    else
        return y
    end
end

-------------------------------------------------------------------------
--- Gql.Parser
-------------------------------------------------------------------------
function Parser:getToken()
    local token = self:peekToken()
    self:move()
    return token
end

function Parser:peekToken()
    return self.lex:getToken(self.idx)
end

function Parser:move()
    self.idx = self.idx+1
end

function Parser:parse(query)
    self.lex = Lexer:new(query)
    self.idx = 1
    return self:_parse()
end

function Parser:_parse()
    local list = {}
    while true do
        local token = self:getToken()
        if nil == token then
            return Document:new(list)
        elseif '{' == token then
            local op = {type="query"} -- default is query
            op.fields = self:read_fields()
            table.insert(list, op)
        elseif 'query' == token or 'mutation' == token or 'subscription' == token then
            local op = self:read_definition()
            op.type = token
            if '{' ~= self:getToken() then
                self:error("expecting '{'")
            end
            op.fields = self:read_fields()
            table.insert(list, op)
        elseif 'fragment' == token then
            token = self:getToken()
            if not (token and string.match(token, NAME_PATTERN)) or "on" == token then
                self:error("invalid fragment name")
            end
            local frag = { fragment = token }
            if "on" ~= self:getToken() then
                self:error('expecting "on"')
            end
            local type_name = self:getToken()
            if not (type_name and string.match(type_name, NAME_PATTERN)) then
                self:error("invalid fragment type")
            end
            frag.on = type_name
            local dirs = self:read_directives()
            if dirs then frag.directives = dirs end
            if '{' ~= self:getToken() then
                self:error("expecting '{'")
            end
            frag.fields = self:read_fields()
            table.insert(list, frag)
        else
            self:error("expecting an operation or a fragment")
        end
    end
end

function Parser:read_definition()
    local obj = {}
    local token = self:peekToken()
    if token and string.match(token, NAME_PATTERN) then
        self:move()
        obj.name = token
        token = self:peekToken()
        if '(' == token then
            self:move()
            obj.variables = self:read_variables()
        end
    end

    local dirs = self:read_directives()
    if dirs then obj.directives = dirs end
    return obj
end

function Parser:read_arguments()
    local list = {}
    while true do
        local token = self:getToken()
        if token and string.match(token, NAME_PATTERN) then
            local arg = {name = token}
            if ':' ~= self:getToken() then
                self:error("expecting ':'")
            end
            arg.value = self:read_value()
            table.insert(list, arg)
        elseif ')' == token then
            return list
        else
            self:error("expecting an argument or '}'")
        end
    end
end

function Parser:read_fields()
    local list = {}
    while true do
        local token = self:getToken()
        if token and string.match(token, NAME_PATTERN) then
            local field = { name = token }
            if ':' == self:peekToken() then
                self:move()
                local tmp = self:getToken()
                if not (tmp and string.match(tmp, NAME_PATTERN)) then
                    self:error("invalid field and alias")
                end
                field = { alias = token, name = tmp }
            end
            if '(' == self:peekToken() then
                self:move()
                field.arguments = self:read_arguments()
            end
            local dirs = self:read_directives()
            if dirs then field.directives = dirs end
            if '{' == self:peekToken() then
                self:move()
                field.fields = self:read_fields()
            end
            table.insert(list, field)
        elseif token and string.match(token, FRAGMENT_PATTERN) then
            if "..." == token then
                token = self:getToken()
            else
                token = token:sub(4)
            end
            local is_inline = false
            if "on" == token then
                token = self:getToken()
                is_inline = true
            end
            if not (token and string.match(token, NAME_PATTERN)) then
                self:error("invalid fragment name")
            end
            local frag
            if is_inline then
                frag = { on = token }
            else
                frag = { fragment = token }
            end
            local dirs = self:read_directives()
            if dirs then frag.directives = dirs end
            if is_inline then
                if not ('{' == self:getToken()) then
                    self:error("expecting '{' for inline fragment")
                end
                frag.fields = self:read_fields()
            end
            table.insert(list, frag)
        elseif '}' == token then
            return list
        else
            self:error("expecting a field or '}'")
        end
    end
end

function Parser:read_directives()
    local list = {}
    while true do
        local token = self:peekToken()
        if token and string.match(token, DIRECTIVE_PATTERN) then
            self:move()
            local directive = {name=token}
            token = self:peekToken()
            if '(' == token then
                self:move()
                directive.arguments = self:read_arguments()
            end
            table.insert(list, directive)
        else
            break
        end
    end
    if #list >= 1 then
        return list
    else
        return nil
    end
end

function Parser:read_variables()
    local list = {}
    while true do
        local token = self:getToken()
        if token and string.match(token, VARIABLE_PATTERN) then
            local var = {name = token}
            if ':' ~= self:getToken() then
                self:error("expecting ':'")
            end
            var.type = {}
            self:read_var_type(var.type, true)
            if '=' == self:peekToken() then
                self:move()
                var.default_value = self:read_value()
            end
            table.insert(list, var)
        elseif ')' == token then
            return list
        else
            self:error("expecting a variable or ')'")
        end
    end
end

function Parser:read_var_type(type, allow_array)
    local token = self:getToken()
    if '[' == token then
        if not allow_array then
            self:error("nested array in type definition is not allowed")
        end
        type.is_array = true
        self:read_var_type(type, false)
        if ']' ~= self:getToken() then
            self:error("expecting ']'")
        end
    elseif token and string.match(token, NAME_PATTERN) then
        type.name = token
    else
        self:error("invalid type")
    end

    if '!' == self:peekToken() then
        self:move()
        type.non_null = true
    end
end

function Parser:read_value()
    local token = self:getToken()
    if '{' == token then
        return self:read_object()
    elseif '[' == token then
        return self:read_array()
    else
        if token and string.match(token, "^[%w%$]") then
            return token
        else
            self:error("invalid value")
        end
    end
end

function Parser:read_object()
    local list = {}
    while true do
        local token = self:getToken()
        if token and string.match(token, NAME_PATTERN) then
            local field = { name = token }
            if ':' ~= self:getToken() then
                self:error("expecting ':'")
            end
            field.value = self:read_value()
            table.insert(list, field)
        elseif '}' == token then
            return list
        else
            self:error("expecting a object key name or '}'")
        end
    end
end

function Parser:read_array()
    local list = {}
    while true do
        if ']' == self:peekToken() then
            self:move()
            return list
        else
            local value = self:read_value()
            table.insert(list, value)
        end
    end
end

function Parser:error(msg)
    local s = nil
    local i = self.idx-1
    if i == 0 then
        s = 'looks like an empty input: ' .. msg
    elseif i == 1 then
        s = "at token[1] '" .. tostring(self.lex:getToken(i)) .. "'" .. msg
    else -- i > 1
        local thisToken = self.lex:getToken(i)
        local lastToken = self.lex:getToken(i-1)
        if thisToken then
            s = "after token[" .. tostring(i-1) .. "] '" .. tostring(lastToken) .. "' is '" .. tostring(thisToken) .. "': " .. msg
        else -- thisToken is nil
            s = "after token[" .. tostring(i-1) .. "] '" .. tostring(lastToken) .. "' is EOF: " .. msg
        end
    end
    error(s)
end

-------------------------------------------------------------------------
--- Gql.Document
-------------------------------------------------------------------------
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

-------------------------------------------------------------------------
--- Gql.Operation
-------------------------------------------------------------------------
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

-------------------------------------------------------------------------
--- Gql.RootField
-------------------------------------------------------------------------
function RootField:resolveArgument(input)
    local result = {}
    args = self.arguments
		  for _, arg in ipairs(args) do
		      local value = arg.value
		      if type(value) == "table" then
		      	self.arguments = value
	          tmp_result = self:resolveArgument(input)
	          for k,v in pairs(tmp_result) do
	          	result[k] = v
	          end
		      elseif type(value) == "string" then
				   	local item = {}
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


return Parser