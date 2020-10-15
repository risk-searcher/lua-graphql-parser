local Lexer = require("lexer")
local Parser = require("parser")
local inspect = require('inspect')

local P = Parser.from

local lex2 = Lexer:new([[
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

local op_variable = P("^[%$%w]") + ":" + "^%w*$" + P("!")^-1
op_variable.post_match = function(self, ast, this_ast, result)
    local name = result:pop()
    local dummy = result:pop()
    local type = result:pop()
    local canBeNil = false
    if "!" == result:peek() then
        result:pop()
        canBeNil = true
    end
    table.insert(safeGet(ast, "operation.params"), 1, {name=name, type=type, nilable=canBeNil})
    return result
end

local name = P("^[%w_][%w_%d]*$")
local non_pun = P("^[^%!%(%)%:%=%[%]%{%|%}]")

local op_variables = P("(") + op_variable^"*" + ")"

local operation = P("^%w+$") + op_variables^"?"

local selection = Parser.wrapper()
local selection_set = "{" + selection^"+" + "}"

local value = Parser.wrapper()
local name_value_pair = name + ":" + value
local object = "{" + name_value_pair^"*" + "}"
value:wrap( non_pun | object )

local argument = name + ":" + value
local arguments = "(" + argument^"*" + ")"
local field = name + arguments^"?" + selection_set^"?"

selection:wrap(field)

local lex = Lexer:new([[
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
]])

local data = {}
local result = field:match(lex, 1, data, nil)
print(result)
print(result.consumed)
print(inspect(data))
while true do
    local token = result:pop()
    if nil == token then break end
    print(token)
end