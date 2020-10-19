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

-- http://spec.graphql.org/June2018/#sec-Language.Fields
local field = name + arguments^"?" + selection_set^"?"
field.post_match = function(self, result)
    local name = result:pop()
    local obj = GqlNodes.field:new{value=name}
    while true do
        local next = result:peek()
        if instanceOf(next, GqlNodes.arguments) or instanceOf(next, GqlNodes.selection_set) then
            next = result:pop()
            if instanceOf(next, GqlNodes.arguments) then
                -- there may be selection_set after arguments
                obj.arguments = next.value
            else
                obj.selection_set = next
                return result:prepend(obj)
            end
        else
            return result:prepend(obj)
        end
    end
end

-- TODO: update selection
selection:wrap(field)

-- http://spec.graphql.org/June2018/#Type
local value_type = Parser.wrapper()
local named_type = P("^[%w_][%w_%d]*$") -- don't write named_type=name, otherwise it will corrupt name
named_type.post_match = function(self, result)
    local name = result:pop()
    local obj = GqlNodes.named_type:new{value=name}
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
    local node_type = GqlNodes.default_value
    local dummy = result:pop()
    node_type.value = result:pop()
    return result:prepend(obj)
end
local variable = P("^[%$%w]") + ":" + value_type + default_value^"?"
variable.post_match = function(self, result)
    local node_type = GqlNodes.variable
    local obj = node_type:new()
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
local operation = op_type + op_definition^"?" + selection_set
operation.post_match = function(self, result)
    local obj = GqlNodes.operation
    obj.type = result:pop()
    local next = result:pop()
    -- note, op_definition returns NodeTypes.operation
    if not instanceOf(next, GqlNodes.selection_set) then
        -- next is op_definition
        obj.name = next
        next = result:pop()
        if instanceOf(next, GqlNodes.variables) then
            obj.variables = next
            next = result:pop()
        end
    end
    obj.selection_set = next.value
    return result:prepend(obj)
end

-- =========================================================================
-- Grammar type to NodeType (result node type) mapping
-- =========================================================================
Grammars = {name=name, non_pun=non_pun, operation=operation, op_type=op_type, op_definition=op_definition, variables=variables, variable=variable,
            value_type=value_type, named_type=named_type, list_type=list_type, default_value=default_value,
            value=value, name_value=name_value, object_value=object_value,
            selection_set=selection_set, selection=selection, field=field, arguments=arguments, argument=argument}

local GqlBaseNode = Clazz.class("GqlNode")
for k, v in pairs(Grammars) do
    local tmp = Clazz.class("GqlNode." .. k, GqlBaseNode)
    GqlNodes[k] = tmp
    Map[v] = tmp
end

local lex = Lexer:new([[
mutation SendSms($phone: String!) {
	sendSms(input: { phone: $phone }) {
		viewer {
			id
			phoneConfirmed
			phoneVerificationPending1
			__typename
		}
		errors {
			path
			message
			__typename
		}
		__typename
	}
}]])


local result = operation:match(lex, 1, false, nil)

--local lex = Lexer:new("($phone: [String!]!)")
--local result = variables:match(lex, 1, false, nil)

print(result)
print(result.consumed)
while true do
    local token = result:pop()
    if nil == token then break end
    print(inspect(token, {process=remove_all_metatables}))
end