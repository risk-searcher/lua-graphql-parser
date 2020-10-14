local Lexer = require("lexer")
local Clazz = require("clazz")
require("util")

local StringParser
local PatternParser
local AndParser
local OrParser
local RepetitionParser

---- parser base class
local Parser = Clazz.class("Parser")

function Parser.from(input)
    if #input == 1 then
        return StringParser:new{pattern=input}
    elseif input:find("%", 1, true) == nil then
        return StringParser:new{pattern=input}
    else
        return PatternParser:new{pattern=input}
    end
end

local P = Parser.from

--- check if the provided lexer matches the parser definition
--- @param lexer the token lexer
--- @param startIdx the start index of the lexer (in terms of token, not character)
--- @param result
--- @param next the next Parser to match if this one matches, next has to be a ParserLinkList
--- @return boolean, token_consumed
function Parser:match(lexer, startIdx, result, next)
    error("this shouldn't happen")
end

function Parser.__bor(lhs, rhs)
    if instanceOf(lhs, Parser) then
        if instanceOf(rhs, Parser) then
            return OrParser:new{left=lhs, right=rhs}
        else
            return OrParser:new{left=lhs, right=P(rhs)}
        end
    elseif instanceOf(rhs,Parser) then
        if instanceOf(lhs, Parser) then
            return OrParser:new{left=lhs, right=rhs}
        else
            return OrParser:new{left=P(lhs), right=rhs}
        end
    else
        error("this shouldn't happen")
    end
end

function Parser.__band(lhs, rhs)
    if instanceOf(lhs, Parser) then
        if instanceOf(rhs, Parser) then
            return AndParser:new{left=lhs, right=rhs}
        else
            return AndParser:new{left=lhs, right=P(rhs)}
        end
    elseif instanceOf(rhs,Parser) then
        if instanceOf(lhs, Parser) then
            return AndParser:new{left=lhs, right=rhs}
        else
            return AndParser:new{left=P(lhs), right=rhs}
        end
    else
        error("this shouldn't happen")
    end
end

function Parser.__pow(lhs, rhs)
    if instanceOf(lhs, Parser) then
        if type(rhs) == "number" then
            if rhs > 0 then
                return RepetitionParser:new{parser=lhs, min=rhs, max=-1}
            else
                return RepetitionParser:new{parser=lhs, min=0, max=rhs}
            end
        elseif type(rhs) == "string" then
            if "*" == rhs then
                return RepetitionParser:new{parser=lhs, min=0, max=-1}
            elseif "+" == rhs then
                return RepetitionParser:new{parser=lhs, min=1, max=-1}
            elseif "?" == rhs then
                return RepetitionParser:new{parser=lhs, min=0, max=1}
            end
        else
            local startX = rhs[1]
            local endX = rhs[2]
            return RepetitionParser:new{parser=lhs, min=startX, max=endX}
        end
    else
        error('Left hand side of a "^" operation is not a Parser object: ' .. tostring(lhs))
    end
end

-- ==============================================
-- ParserLinkList an immutable LinkList (i.e. con-list)
-- ==============================================
local ParserLinkList = Clazz.class("ParserLinkList", Parser)

function ParserLinkList:match(lexer, startIdx, result, next)
    return self.head:match(lexer, startIdx, result, next)
end

-- ==============================================
-- Constant String Parser
-- ==============================================
StringParser = Clazz.class("StringParser", Parser)

-- "next" is always a ParserLinkList
-- returns ast, token_consumed
function StringParser:match(lexer, startIdx, result, next)
    local token = lexer:getToken(startIdx)
    print("Checking string: " .. self.pattern .. " ? " .. tostring(token))
    if nil == token or token ~= self.pattern then
        print(tostring(token) .. " .. 1.1")
        return false, 1
    elseif nil ~= next then
        print(tostring(token) .. " .. 1.2")
        print("Matched: " .. tostring(token))
        local ok, token_consumed = next:match(lexer, startIdx + 1, result, next.tail)
        return ok, token_consumed+1
    else
        print(tostring(token) .. " .. 1.3")
        return true, 1
    end
end

-- ==============================================
-- Regex Pattern Parser
-- ==============================================
PatternParser = Clazz.class("PatternParser", Parser)

-- returns ast, token_consumed
function PatternParser:match(lexer, startIdx, result, next)
    local token = lexer:getToken(startIdx)
    print("Checking pattern: " .. self.pattern .. " ? " .. token)
    if nil == token or nil == string.match(token, self.pattern) then
        print(token .. " .. 2.1")
        return false, 1
    elseif nil ~= next then
        print(token .. " .. 2.2")
        print("Matched: " .. token)
        local ok, token_consumed = next:match(lexer, startIdx + 1, result, next.tail)
        return ok, token_consumed+1
    else
        print(token .. " .. 2.3")
        return true, 1
    end
end

-- ==============================================
-- And Parser
-- ==============================================
AndParser = Clazz.class("AndParser", Parser)

-- returns ast, token_consumed
function AndParser:match(lexer, startIdx, result, next)
    local list = ParserLinkList:new{head=self.right, tail=next}
    return self.left:match(lexer, startIdx, result, list)
end

-- ==============================================
-- Or Parser
-- ==============================================
OrParser = Clazz.class("OrParser", Parser)

-- returns ast, token_consumed
function OrParser:match(lexer, startIdx, result, next)
    local ok, token_consumed = self.left:match(lexer, startIdx, result, next)
    if ok then
        return ok, token_consumed
    else
        return self.right:match(lexer, startIdx, result, next)
    end
end

-- ==============================================
-- Repetition Parser
-- ==============================================
RepetitionParser = Clazz.class("RepetitionParser", Parser)

-- returns ok, token_consumed
function RepetitionParser:match(lexer, startIdx, result, next)
    -- first, let's peek and get the max number of possible match
    local count = 0
    local ok
    local token_consumed = 0
    local tmp = ParserLinkList:new{head=self.parser, tail=nil}
    while true do
        -- passing nil as result in here, to indicate we are not using it
        ok, token_consumed = tmp:match(lexer, startIdx, nil, tmp.tail)
        if ok then
            count = count+1
            if self.max ~= -1 and count >= self.max then break end
            tmp = ParserLinkList:new{head=self.parser, tail=tmp}
        else
            break
        end
    end

    if count == 0 then
        if self.min == 0 then
            if nil == next then return true, 0 end
            return next:match(lexer, startIdx, result, next.tail)
        else
            return false, 0
        end
    else
        -- count > 0
        while true do
            -- prepare the "next" object
            tmp = next
            for i=1, count do
                tmp = ParserLinkList:new{head=self.parser, tail=tmp}
            end
            ok, token_consumed = tmp:match(lexer, startIdx, result, tmp.tail)
            if ok then
                return ok, token_consumed
            else
                count = count-1
                if count == 0 or count < self.min then
                    return false, 0
                end
            end
        end
    end
end

--local lex = Lexer:new([[
--mutation SendSms($phone: String!) {
--	sendSms(input: { phone: $phone }) {
--		viewer {
--			id
--			phoneConfirmed
--			phoneVerificationPending
--			__typename
--		}
--		errors {
--			path
--			message
--			__typename
--		}
--		__typename
--	}
--}]])
local lex = Lexer:new("SendSms($phone: String!, $count: Number)")

--local name = P("name") & "=" & "%w+"
--local age = P("age") & "=" & "%d+"
--local mutation = P("mutation") & "world" & "(" & (name | age) & ")"
local op_parameters = P("[%$%d]+") & ":" & "%w" & P("!")^-1
local operation = P("%w+") & "(" & op_parameters^"*"  & ")"
local ok, token_consumed = operation:match(lex, 1, nil, nil)
print(ok)
print(token_consumed)

--return Parser
