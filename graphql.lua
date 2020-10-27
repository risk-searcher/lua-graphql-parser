local Lexer = require("lexer")
local Parser = require("parser")
local inspect = require('inspect')
local Clazz = require("clazz")
--local GqlNodeType = require("graphql-nodes")

local P = Parser.from
local Grammars = {} -- key:string, value:Parser
local GqlNodes = {} -- key:string, value:Clazz type
local Map = {} -- key:Parser, value:GqlNode

local remove_all_metatables = function(item, path)
    if path[#path] ~= inspect.METATABLE then return item end
end

local function get_name(obj)
    for k, v in pairs(Grammars) do
        if v == obj then
            return k
        end
    end
    return nil
end

-- =========================================================================
-- helper functions
-- =========================================================================

--- handle things like name + ":" + value
local function name_value_matcher(self, result)
    local name = result:pop()
    local separator = result:pop()
    local value = result:pop()
    local node_type = Map[self]
    if nil == node_type then
        local x = get_name(self)
        print("Hello world111: " .. tostring(x))
    end
    local obj = node_type:new{name=name, value=value}
    return result:prepend(obj)
end

--- handle things like "(" + parser* + ")"
--- supports both parser* and parser+
--- automatically resolve expected end token by matching the open parenthesis
local function sandwich_matcher(self, result)
    local open_parenthesis = result:pop()
    local map = {['(']=')', ['{']='}', ['[']=']'}
    local end_parenthesis = map[open_parenthesis]
    local array = {}
    local node_type = Map[self]
    local obj = node_type:new{value=array}
    while true do
        local item = result:pop()
        if end_parenthesis ~= item then
            table.insert(array, item)
        else
            break
        end
    end
    return result:prepend(obj)
end

-- =========================================================================
-- Grammar (i.e. Parser) definition
-- =========================================================================
local name = P("^[%w_][%w_%d]*$")
local variable_name = P("^$[%w_][%w_%d]*$")
local non_pun = P("^[^%!%(%)%:%=%[%]%{%|%}]")

-- http://spec.graphql.org/June2018/#sec-Selection-Sets
local selection = Parser.wrapper()
local selection_set = "{" + selection^"+" + "}"
selection_set.post_match = sandwich_matcher

-- http://spec.graphql.org/June2018/#sec-Input-Values
local value = Parser.wrapper()
local name_value = name + ":" + value
name_value.post_match = name_value_matcher

-- http://spec.graphql.org/June2018/#sec-Input-Object-Values
local object_value = "{" + name_value^"*" + "}"
object_value.post_match = sandwich_matcher
value:wrap( non_pun | object_value )

-- http://spec.graphql.org/June2018/#sec-Language.Arguments
local argument = name + ":" + value
argument.post_match = name_value_matcher
local arguments = "(" + argument^"*" + ")"
arguments.post_match = sandwich_matcher

-- http://spec.graphql.org/June2018/#Directives
local directive = P("^%@[%w_][%w_%d]*$") + arguments^"?"
directive.post_match = function(self, result)
    local name = result:pop()
    local obj = GqlNodes.directive:new{name=name}
    local next = result:peek()
    if instanceOf(next, GqlNodes.arguments) then
        result:pop()
        obj.arguments = next.value
    end
    return result:prepend(obj)
end

-- http://spec.graphql.org/June2018/#sec-Language.Fields
local field = (name + ":")^"?" + name + arguments^"?" + directive^"*" + selection_set^"?"
field.post_match = function(self, result)
    local name = result:pop() -- the first one can be an alias, or can be a name
    local obj = GqlNodes.field:new()
    local next = result:peek()
    if ":" == next then
        -- there is a chance field is just "name", then next is point to something not part of a field, but I can't see how the next block can be a ":"
        result:pop()
        obj.alias = name
        obj.name = result:pop()
        next = result:peek()
    else
        obj.name = name
    end
    if instanceOf(next, GqlNodes.arguments) then
        result:pop()
        obj.arguments = next.value
        next = result:peek()
    end
    while true do
        if instanceOf(next, GqlNodes.directive) then
            result:pop()
            if nil == obj.directives then obj.directives = {} end
            table.insert(obj.directives, next)
            next = result:peek()
        else
            break
        end
    end
    if instanceOf(next, GqlNodes.selection_set) then
        result:pop()
        obj.selection_set = next.value
    end
    return result:prepend(obj)
end

-- http://spec.graphql.org/June2018/#FragmentSpread
local fragment_name = P("^%.%.%.[%w_][%w_%d]*$")
fragment_name.match_internal = function(self, lexer, startIdx, skip_post_match, next)
    local token = lexer:getToken(startIdx)
    if nil == token or nil == string.match(token, self.pattern) or "...on" == token then
        return nil
    elseif nil ~= next then
        local result = next:match(lexer, startIdx + 1, skip_post_match, next.next)
        if nil == result then return nil end
        return result:prepend(token)
    else
        return MatchResult.single(token)
    end
end
local fragment_spread = fragment_name + directive^"*"
fragment_spread.post_match = function(self, result)
    local name = result:pop()
    local obj = GqlNodes.fragment_spread:new{fragment=name}
    local next = result:peek()
    while true do
        if instanceOf(next, GqlNodes.directive) then
            if nil == obj.directives then obj.directives = {} end
            table.insert(obj.directives, next)
        else
            break
        end
    end
    return result:prepend(obj)
end

-- http://spec.graphql.org/June2018/#InlineFragment
local inline_fragment = P("...") + "on" + name + directive^"*" + selection_set
inline_fragment.post_match = function(self, result)
    result:pop()
    result:pop()
    local name = result:pop()
    local obj = GqlNodes.inline_fragment:new{on=name}
    local next = result:pop()
    while true do
        if instanceOf(next, GqlNodes.directive) then
            if nil == obj.directives then obj.directives = {} end
            table.insert(obj.directives, next)
            next = result:pop()
        else
            break
        end
    end
    obj.selection_set = next.value
    return result:prepend(obj)
end

-- TODO: update selection
selection:wrap(field | fragment_spread | inline_fragment)

-- http://spec.graphql.org/June2018/#Type
local value_type = Parser.wrapper()
local named_type = P("^[%w_][%w_%d]*$") -- don't write named_type=name, otherwise it will corrupt name
named_type.post_match = function(self, result)
    local name = result:pop()
    local obj = GqlNodes.named_type:new{name=name}
    return result:prepend(obj)
end
local list_type = '[' + value_type + ']'
list_type.post_match = function(self, result)
    result:pop()
    local value = result:pop()
    result:pop()
    local obj = GqlNodes.list_type:new{value=value}
    return result:prepend(obj)
end
value_type:wrap((named_type | list_type) + P("!")^"?")
value_type.post_match = function(self, result)
    local value = result:pop()
    local next = result:peek()
    if "!" == next then
        result:pop()
        value.non_null = true
    end
    return result:prepend(value)
end

-- http://spec.graphql.org/June2018/#sec-Language.Variables
local default_value = '=' + value
default_value.post_match = function(self, result)
    local obj = GqlNodes.default_value:new()
    local dummy = result:pop()
    obj.value = result:pop()
    return result:prepend(obj)
end
local variable = P("^[%$%w]") + ":" + value_type + default_value^"?"
variable.post_match = function(self, result)
    local obj = GqlNodes.variable:new()
    obj.name = result:pop()
    result:pop()
    obj.type = result:pop()
    local next = result:peek()
    if instanceOf(next, GqlNodes.default_value) then
        result:pop()
        obj.default_value = next.value
    end
    return result:prepend(obj)
end

local variables = "(" + variable^"*" + ")"
variables.post_match = sandwich_matcher

-- http://spec.graphql.org/June2018/#sec-Language.Operations
local op_type = P("query") | "mutation" | "subscription"
local op_definition = name + variables^"?"
local operation = (op_type + op_definition^"?" + directive^"*")^"?" + selection_set
operation.post_match = function(self, result)
    local obj = GqlNodes.operation:new()
    local next = result:pop()
    if instanceOf(next, GqlNodes.selection_set) then
        -- default query
        obj.type = "query"
    else
        obj.type = next -- if it is not selection_set, then it must be the op_type
        next = result:pop() -- next can be op_definition, directive, or selection_set
        -- note, op_definition is a plain string token
        if "string" == type(next) then
            -- next is op_definition
            obj.name = next
            next = result:pop()
            if instanceOf(next, GqlNodes.variables) then
                obj.variables = next.value
                next = result:pop()
            end
        end
        while true do
            if instanceOf(next, GqlNodes.directive) then
                if nil == obj.directives then obj.directives = {} end
                table.insert(obj.directives, next)
                next = result:pop()
            else
                break
            end
        end
    end
    obj.selection_set = next.value
    return result:prepend(obj)
end

-- http://spec.graphql.org/June2018/#FragmentDefinition
local fragment = P("fragment") + name + "on" + name + directive^"*" + selection_set
fragment.post_match = function(self, result)
    result:pop() -- fragment
    local name = result:pop()
    result:pop() -- "on"
    local on_name = result:pop()
    local obj = GqlNodes.fragment:new{type="fragment", name=name, on=on_name}
    local next = result:pop()
    while true do
        if instanceOf(next, GqlNodes.directive) then
            if nil == obj.directives then obj.directives = {} end
            table.insert(obj.directives, next)
            next = result:pop()
        else
            break
        end
    end
    obj.selection_set = next.value
    return result:prepend(obj)
end

local gql = (operation | fragment)^"+"
gql.post_match = function(self, result)
    local obj = GqlNodes.gql:new()
    while true do
        local next = result:pop()
        if instanceOf(next, GqlNodes.operation) or instanceOf(next, GqlNodes.fragment) then
            if nil == obj.list then obj.list = {} end
            table.insert(obj.list, next)
        else
            break
        end
    end
    return result:prepend(obj)
end

-- =========================================================================
-- Grammar type to NodeType (result node type) mapping
-- =========================================================================
Grammars = {name=name, non_pun=non_pun, operation=operation, op_type=op_type, op_definition=op_definition, variables=variables, variable=variable,
            value_type=value_type, named_type=named_type, list_type=list_type, default_value=default_value,
            value=value, name_value=name_value, object_value=object_value,
            selection_set=selection_set, selection=selection, field=field, arguments=arguments, argument=argument, directive=directive,
            fragment_spread=fragment_spread, inline_fragment=inline_fragment, fragment=fragment, gql=gql}

local GqlBaseNode = Clazz.class("GqlNode")
for k, v in pairs(Grammars) do
    local tmp = Clazz.class("GqlNode." .. k, GqlBaseNode)
    GqlNodes[k] = tmp
    Map[v] = tmp
end

--local lex = Lexer:new([[
--mutation SendSms($phone: String!) {
--	sendSms(input: { phone: $phone }) {
--		viewer @skip(if: true) {
--			id
--			phoneConfirmed
--			phoneVerificationPending1
--			__typename
--		}
--		... on User {
--            hello
--            world
--        }
--		errors {
--			path
--			message
--			__typename
--		}
--		__typename
--	}
--}]])
--
--
--local result = gql:match(lex, 1, false, nil)
--
----local lex = Lexer:new("($phone: [String!]!)")
----local result = variables:match(lex, 1, false, nil)
--
--print(result)
--print(result.consumed)
--while true do
--    local token = result:pop()
--    if nil == token then break end
--    print(inspect(token, {process=remove_all_metatables}))
--end

return gql
