local Lexer = require("lexer")
local Clazz = require("clazz")
require("util")
local inspect = require('inspect')

local StringParser
local PatternParser
local AndParser
local OrParser
local RepetitionParser
local ParserWrapper

-- ==============================================
-- Parser matched token stack
-- ==============================================
local TokenStack = Clazz.class("TokenStack")

-- ==============================================
-- Parser match result
-- ==============================================
local MatchResult = Clazz.class("MatchResult")

function MatchResult.single(token)
    local stack = TokenStack:new{head=token, next=nil}
    return MatchResult:new{stack=stack, consumed=1}
end

function MatchResult.empty()
    return MatchResult:new{stack=nil, consumed=0}
end

function MatchResult:prepend(token)
    local new_stack = TokenStack:new{head=token, next=self.stack}
    return MatchResult:new{stack=new_stack, consumed=self.consumed+1}
end

function MatchResult:pop()
    if nil ~= self.stack then
        local token = self.stack.head
        self.stack = self.stack.next
        return token
    else
        return nil
    end
end

function MatchResult:peek()
    if nil ~= self.stack then
        return self.stack.head
    else
        return nil
    end
end

-- ==============================================
-- Parser base class
-- ==============================================
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

function Parser.wrapper()
    return ParserWrapper:new()
end

local P = Parser.from

--- check if the provided lexer matches the parser definition
--- @param lexer the token lexer
--- @param startIdx the start index of the lexer (in terms of token, not character)
--- @param data
--- @param next the next Parser to match if this one matches, next has to be a ParserLinkList
--- @return MatchResult
function Parser:match(lexer, startIdx, data, next)
    if nil ~= data then
        data = self:pre_process(data)
    end
    local result = self:match_internal(lexer, startIdx, data, next)
    if nil ~= result and nil ~= data then
        result = self:post_match(data, result)
    end
    return result
end

function Parser:pre_process(data)
    return data
end

function Parser:match_internal(lexer, startIdx, data, next)
    error("this shouldn't happen")
end

function Parser:post_match(data, result)
    return result
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

function ParserLinkList:match_internal(lexer, startIdx, data, next)
    return self.head:match(lexer, startIdx, data, next)
end

-- ==============================================
-- Constant String Parser
-- ==============================================
StringParser = Clazz.class("StringParser", Parser)

-- "next" is always a ParserLinkList
-- returns ast, token_consumed
function StringParser:match_internal(lexer, startIdx, data, next)
    local token = lexer:getToken(startIdx)
    if nil == token or token ~= self.pattern then
        return nil
    elseif nil ~= next then
        local result = next:match(lexer, startIdx + 1, data, next.next)
        if nil == result then return nil end
        return result:prepend(token)
    else
        return MatchResult.single(token)
    end
end

-- ==============================================
-- Regex Pattern Parser
-- ==============================================
PatternParser = Clazz.class("PatternParser", Parser)

-- returns ast, token_consumed
function PatternParser:match_internal(lexer, startIdx, data, next)
    local token = lexer:getToken(startIdx)
    if nil == token or nil == string.match(token, self.pattern) then
        return nil
    elseif nil ~= next then
        local result = next:match(lexer, startIdx + 1, data, next.next)
        if nil == result then return nil end
        return result:prepend(token)
    else
        return MatchResult.single(token)
    end
end

-- ==============================================
-- And Parser
-- ==============================================
AndParser = Clazz.class("AndParser", Parser)

-- returns ast, token_consumed
function AndParser:match_internal(lexer, startIdx, data, next)
    local list = ParserLinkList:new{head=self.right, next=next}
    return self.left:match(lexer, startIdx, data, list)
end

-- ==============================================
-- Or Parser
-- ==============================================
OrParser = Clazz.class("OrParser", Parser)

-- returns ast, token_consumed
function OrParser:match_internal(lexer, startIdx, data, next)
    local result = self.left:match(lexer, startIdx, data, next)
    if nil ~= result then
        return result
    else
        return self.right:match(lexer, startIdx, data, next)
    end
end

-- ==============================================
-- Repetition Parser
-- ==============================================
RepetitionParser = Clazz.class("RepetitionParser", Parser)

-- returns ok, token_consumed
function RepetitionParser:match_internal(lexer, startIdx, data, next)
    -- first, let's peek and get the max number of possible match
    local count = 0
    local tmp = ParserLinkList:new{head=self.parser, next=nil}
    while true do
        -- passing nil as result in here, to indicate we are not using it
        local result = tmp:match(lexer, startIdx, nil, tmp.next)
        if nil ~= result then
            count = count+1
            if self.max ~= -1 and count >= self.max then break end
            tmp = ParserLinkList:new{head=self.parser, next=tmp}
        else
            break
        end
    end

    if count == 0 then
        if self.min == 0 then
            if nil == next then return MatchResult.empty() end
            return next:match(lexer, startIdx, data, next.next)
        else
            return nil
        end
    else
        -- count > 0
        while true do
            -- prepare the "next" object
            tmp = next
            for i=1, count do
                tmp = ParserLinkList:new{head=self.parser, next=tmp}
            end
            local result = tmp:match(lexer, startIdx, data, tmp.next)
            if nil ~= result then
                return result
            else
                count = count-1
                if count == 0 or count < self.min then
                    return nil
                end
            end
        end
    end
end


-- ==============================================
-- Parser Wrapper
-- ==============================================
ParserWrapper = Clazz.class("ParserWrapper", Parser)

function ParserWrapper:wrap(parser)
    self.parser = parser
end

-- returns ast, token_consumed
function ParserWrapper:match_internal(lexer, startIdx, data, next)
    return self.parser:match(lexer, startIdx, data, next)
end

return Parser
