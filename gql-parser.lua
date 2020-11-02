local Clazz = require("clazz")
local Lexer = require("lexer")

local NAME_PATTERN = "^[%w_][%w%d_]*$"
local VARIABLE_PATTERN = "^$?[%w_][%w%d_]*$"
local DIRECTIVE_PATTERN = "^@[%w_][%w%d_]*$"
local FRAGMENT_PATTERN = "^%.%.%."

local GqlParser = Clazz.class("GqlParser")

function GqlParser:getToken()
    local token = self:peekToken()
    self:move()
    return token
end

function GqlParser:peekToken()
    return self.lex:getToken(self.idx)
end

function GqlParser:move()
    self.idx = self.idx+1
end

function GqlParser:parse(input)
    self.lex = Lexer:new(input)
    self.idx = 1
    return self:_parse()
end

function GqlParser:_parse()
    local list = {}
    while true do
        local token = self:getToken()
        if nil == token then
            return list
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

function GqlParser:read_definition()
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

function GqlParser:read_arguments()
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

function GqlParser:read_fields()
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

function GqlParser:read_directives()
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

function GqlParser:read_variables()
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

function GqlParser:read_var_type(type, allow_array)
    local token = self:getToken()
    if '[' == token then
        if ~allow_array then
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

function GqlParser:read_value()
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

function GqlParser:read_object()
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

function GqlParser:read_array()
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

function GqlParser:error(msg)
    -- TODO
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

return GqlParser
