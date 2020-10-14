local Lexer = require("lexer")
local Clazz = require("clazz")
require("util")

function P(input)
    if #input == 1 then
        return StringParser:new{pattern=input}
    elseif input:find("%", 1, true) == nil then
        return StringParser:new{pattern=input}
    else
        return PatternParser:new{pattern=input}
    end

end

---- parser base class
Parser = Clazz.class("Parser")

-- "next" is always a ParserLinkList
-- returns boolean, token_consumed
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

end

---- Parser Immutable LinkList
ParserLinkList = Clazz.class("ParserLinkList", Parser)

function ParserLinkList:match(lexer, startIdx, result, next)
    return self.head:match(lexer, startIdx, result, next)
end

---- constant string parser
StringParser = Clazz.class("StringParser", Parser)

-- "next" is always a ParserLinkList
-- returns ast, token_consumed
function StringParser:match(lexer, startIdx, result, next)
    local token = lexer:getToken(startIdx)
    print("Checking string: " .. self.pattern .. " ? " .. token)
    if nil == token or token ~= self.pattern then
        print(token .. " .. 1.1")
        return false, 1
    elseif nil ~= next then
        print(token .. " .. 1.2")
        print("Matched: " .. token)
        local ok, token_consumed = next:match(lexer, startIdx + 1, result, next.tail)
        return ok, token_consumed+1
    else
        print(token .. " .. 1.3")
        return true, 1
    end
end

---- regex based string parser
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

---- and parser
AndParser = Clazz.class("AndParser", Parser)

-- returns ast, token_consumed
function AndParser:match(lexer, startIdx, result, next)
    local list = ParserLinkList:new{head=self.right, tail=next}
    return self.left:match(lexer, startIdx, result, list)
end

---- or parser
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

local lex = Lexer:new("hello world(age = 10)")


local name = P("name") & "=" & "%w+"
local age = P("age") & "=" & "%d+"
local parser = P("hello") & "world" & "(" & (name | age) & ")"
local ok, token_consumed = parser:match(lex, 1, nil, nil)
print(ok)
print(token_consumed)
