require("mobdebug").start()

require("lexer")
require("ast")
require("util")

function P(input)
    if #input == 1 then
        return StringParser:new(input)
    elseif input:find("%", 1, true) == nil then
        return StringParser:new(input)
    else
        return PatternParser:new(input)
    end

end

---- parser base class
Parser = {}
Parser.__index = Parser

function Parser:new()
    local o = {}
    setmetatable(o, self)
    o.name = "sam"
    return o
end

-- "next" is always a ParserLinkList
-- returns boolean, token_consumed
function Parser:match(lexer, startIdx, result, next)
    error("this shouldn't happen")
end

function Parser.__bor(a, b)
    if instanceOf(a, Parser) then
        if instanceOf(b, Parser) then
            return OrParser:new(a, b)
        else
            return OrParser:new(a, P(b))
        end
    elseif instanceOf(b,Parser) then
        if instanceOf(a, Parser) then
            return OrParser:new(a, b)
        else
            return OrParser:new(P(a), b)
        end
    else
        error("this shouldn't happen")
    end
end

function Parser.__band(a, b)
    if instanceOf(a, Parser) then
        if instanceOf(b, Parser) then
            return AndParser:new(a, b)
        else
            return AndParser:new(a, P(b))
        end
    elseif instanceOf(b,Parser) then
        if instanceOf(a, Parser) then
            return AndParser:new(a, b)
        else
            return AndParser:new(P(a), b)
        end
    else
        error("this shouldn't happen")
    end
end

function Parser.__pow(a, b)

end

---- Parser Immutable LinkList
ParserLinkList = Parser:new()
ParserLinkList.__index = ParserLinkList

-- "head" is a Parser
-- "tail" is a ParserLinkList, but it can be nil
function ParserLinkList:new(head, tail)
    local o = {}
    setmetatable(o, ParserLinkList)
    o.head = head
    -- tail is also a ParserListList
    o.tail = tail
    return o
end

function ParserLinkList:match(lexer, startIdx, result, next)
    return self.head:match(lexer, startIdx, result, next)
end

---- constant string parser
StringParser = Parser:new()
StringParser.__index = StringParser
StringParser.__band = Parser.__band
StringParser.__bor = Parser.__bor

function StringParser:new(pattern)
    local o = {}
    setmetatable(o, self)
    o.pattern = pattern
    return o
end

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
PatternParser = Parser:new()
PatternParser.__index = PatternParser
PatternParser.__band = Parser.__band
PatternParser.__bor = Parser.__bor

function PatternParser:new(pattern)
    local o = {}
    setmetatable(o, self)
    o.pattern = pattern
    return o
end

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
AndParser = Parser:new()
AndParser.__index = AndParser
AndParser.__band = Parser.__band
AndParser.__bor = Parser.__bor

function AndParser:new(a, b)
    local o = {}
    setmetatable(o, AndParser)
    o.left = a
    o.right = b
    return o
end

-- returns ast, token_consumed
function AndParser:match(lexer, startIdx, result, next)
    local list = ParserLinkList:new(self.right, next)
    return self.left:match(lexer, startIdx, result, list)
end

---- or parser
OrParser = Parser:new()
OrParser.__index = OrParser
OrParser.__band = Parser.__band
OrParser.__bor = Parser.__bor

function OrParser:new(a, b)
    local o = {}
    setmetatable(o, OrParser)
    o.left = a
    o.right = b
    return o
end

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

--local x1 = Parser:new()
--print("x1: " .. tostring(x1))
--print("x1.mt: " .. tostring(getmetatable(x1)))
--print("Parser: " .. tostring(Parser))
--print("hello: " .. tostring(x1.__bor))
--x1:hello()
--local name = StringParser:new("aa")
--print("name: " .. tostring(name))
--print("name.mt: " .. tostring(getmetatable(name)))
--print("StringParser: " .. tostring(StringParser))
--print("StringParser.mt: " .. tostring(getmetatable(StringParser)))
--print("mul: " .. tostring(name.__bor))
--print("mul: " .. tostring(StringParser.__bor))

local name = P("name") & "=" & "%w+"
local age = P("age") & "=" & "%d+"
local parser = P("hello") & "world" & "(" & (name | age) & ")"
local ok, token_consumed = parser:match(lex, 1, nil)
print(ok)
print(token_consumed)
