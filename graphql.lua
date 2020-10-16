local Lexer = require("lexer")
local Parser = require("parser")
local inspect = require('inspect')

local P = Parser.from

-- =========================================================================
-- helper functions
-- =========================================================================

--- handle things like name + ":" + value
function name_value_matcher(self, result)
    local name = result:pop()
    local separator = result:pop()
    local value = result:pop()
    return result:prepend{__node_type=self.__node_type, name=name, value=value}
end

--- handle things like "(" + parser* + ")"
--- supports both parser* and parser+
--- automatically resolve expected end token by matching the open parenthesis
function sandwich_matcher(self, result)
    local openParenthesis = result:pop()
    local map = {['(']=')', ['{']='}', ['[']=']'}
    local endParenthesis = map[openParenthesis]
    local array = {}
    while true do
        local item = result:pop()
        if endParenthesis ~= item then
            table.insert(array, item)
        else
            break
        end
    end
    return result:prepend{__node_type=self.__node_type, value=array}
end


-- =========================================================================
-- grammar definition
-- =========================================================================
local name = P("^[%w_][%w_%d]*$")
name.__node_type = "name"
local variable_name = P("^$[%w_][%w_%d]*$")
variable_name.__node_type = "variable_name"
local non_pun = P("^[^%!%(%)%:%=%[%]%{%|%}]")
non_pun.__node_type = "non_pun"

-- http://spec.graphql.org/June2018/#sec-Selection-Sets
local selection = Parser.wrapper()
selection.__node_type = "selection"
local selection_set = "{" + selection^"+" + "}"
selection_set.__node_type = "selection_set"
selection_set.post_match = sandwich_matcher

-- http://spec.graphql.org/June2018/#sec-Input-Values
local value = Parser.wrapper()
value.__node_type = "value"
local name_value = name + ":" + value
name_value.__node_type = "name_value"
name_value.post_match = name_value_matcher

-- http://spec.graphql.org/June2018/#sec-Input-Object-Values
local object_value = "{" + name_value^"*" + "}"
object_value.__node_type = "object_value"
object_value.post_match = sandwich_matcher
value:wrap( non_pun | object_value )

-- http://spec.graphql.org/June2018/#sec-Language.Arguments
local argument = name + ":" + value
argument.__node_type = "argument"
argument.post_match = name_value_matcher
local arguments = "(" + argument^"*" + ")"
arguments.__node_type = "arguments"
arguments.post_match = sandwich_matcher

-- http://spec.graphql.org/June2018/#sec-Language.Fields
field = name + arguments^"?" + selection_set^"?"
field.__node_type = "field"
field.post_match = function(self, result)
    local name = result:pop()
    local obj = {__node_type="field", value=name}
    while true do
        local next = result:peek()
        if nil ~= next and "table" == type(next) and ("arguments" == next.__node_type or "selection_set" == next.__node_type) then
            next = result:pop()
            if "arguments" == next.__node_type then
                obj.arguments = next.value
            else
                obj.selection_set = next.value
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
value_type.__node_type = "value_type"
local named_type = P("^[%w_][%w_%d]*$") -- don't write named_type=name, otherwise it will corrupt name
named_type.__node_type = "named_type"
named_type.post_match = function(self, result)
    local name = result:pop()
    return result:prepend{value=name}
end
local list_type = '[' + value_type + ']'
list_type.__node_type = "list_type"
list_type.post_match = function(self, result)
    result:pop()
    local value = result:pop()
    result:pop()
    return result:prepend{list_type=value}
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
default_value.__node_type = "default_value"
default_value.post_match = function(self, result)
    local dummy = result:pop()
    local value = result:pop()
    return result:prepend{__node_type="default_value", value=value}
end
local variable = P("^[%$%w]") + ":" + value_type + default_value^"?"
variable.__node_type = "variable"
variable.post_match = function(self, result)
    local obj = {}
    obj.name = result:pop()
    result:pop()
    obj.type = result:pop()
    local next = result:peek()
    if nil ~= next and "table" == type(next) and "default_value" == next.__node_type then
        result:pop()
        obj.default_value = next.value
    end
    return result:prepend(obj)
end

local variables = "(" + variable^"*" + ")"
variables.__node_type = "variables"
variables.post_match = sandwich_matcher

-- http://spec.graphql.org/June2018/#sec-Language.Operations
local op_type = P("query") | "mutation" | "subscription"
op_type.__node_type = "opt_type"
local op_definition = name + variables^"?"
op_definition.__node_type = "op_definition"
op_definition.post_match = function(self, result)
    local obj = {__node_type="op_definition"}
    obj.name = result:pop()
    local next = result:peek()
    if nil ~= next and "table" == type(next) and "variables" == next.__node_type then
        result:pop()
        obj.variables = next.value
    end
    return result:prepend(obj)
end
local operation = op_type + op_definition^"?" + selection_set
operation.__node_type = "operation"
operation.post_match = function(self, result)
    local obj = {__node_type="operation"}
    obj.type = result:pop()
    local next = result:pop()
    if nil ~= next and "table" == type(next) and "op_definition" == next.__node_type then
        obj.name = next.name
        obj.variables = next.variables
        next = result:pop()
    end
    obj.selection_set = next.value
    return result:prepend(obj)
end

local lex = Lexer:new([[
mutation SendSms($phone: String!) {
	sendSms(input: { phone: $phone }) {
		viewer {
			id
			phoneConfirmed
			phoneVerificationPending
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
print(inspect(data))
while true do
    local token = result:pop()
    if nil == token then break end
    print(inspect(token))
end