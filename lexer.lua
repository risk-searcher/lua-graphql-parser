local function lastchar(input)
    return input:sub(#input, #input)
end

Lexer = {}
Lexer.__index = Lexer

function Lexer:new(text)
    local o = {}
    setmetatable(o, Lexer)
    o.text = text
    o.tokens = {}
    o.curPos = 1
    return o
end

-- single thread only, need to update Lexer content
function Lexer:getToken(index)
    while index > #self.tokens or self.curPos < #self.text do
        local token, pos, err = self:nextToken(self.curPos)
        if err ~= nil then
            return nil, err
        end
        self.curPos = pos
        if token == nil then
            break
        else
            table.insert(self.tokens, token)
        end
    end
    if index <= #self.tokens then
        return self.tokens[index], nil
    else
        return nil, nil
    end
end

function Lexer:nextToken(startIdx)
    local text = self.text
    local i = startIdx
    local captureStart = 0
    -- insideString: 0=not inside quoted string, 1=inside quoted string, 2=inside block string
    local insideString = 0
    local lastIsSlash = false
    while i <= #text do
        local c = text:sub(i, i)
        if insideString == 1 then
            -- regular quoted string
            if lastIsSlash then
                lastIsSlash = false
            else
                if c == "\\" then
                    lastIsSlash = true
                elseif c == "\"" then
                    return text:sub(captureStart, i), i+1, nil
                end
            end
        elseif insideString == 2 then
            -- block string
        else
            if nil ~= string.find("!():=[]{|}", c, 1, true) then
                if captureStart > 0 then
                    return text:sub(captureStart, i-1), i, nil
                else
                    return c, i+1, nil
                end
            elseif nil ~= string.find("\r\n\t\f ,", c, 1, true) then
                if captureStart > 0 then
                    return text:sub(captureStart, i-1), i, nil
                end
            elseif "#" == c then
                --- line comment
                local xstart, xend = string.find(text, "[\r\n]", i, false)
                if captureStart > 0 then
                    if nil == xstart then
                        return text:sub(captureStart, i), #text+1, nil
                    else
                        return text:sub(captureStart, i), xstart+1, nil
                    end
                else
                    if nil == xstart then
                        return nil, #text+1, nil
                    end
                    i = xstart
                end
            elseif "\"" == c then
                captureStart = i
                lastIsSlash = false
                if text:match("^\"\"\"", i) then
                    -- block string
                    insideString = 2
                else
                    -- regular quoted string
                    insideString = 1
                end
            else
                if captureStart == 0 then
                    captureStart = i
                end
            end
        end
        i = i+1
    end
    if captureStart > 0 then
        return text:sub(captureStart, #text), #text+1, nil
    end
end


--local lex = Lexer:new("hello world($x -1.2e1cc{@adsf (a: \"adsdf   \\\" asss\" xx")
--print(lex:getToken(4))
--local lex = Lexer:new("\"adsdf   \\\" asss\" 12 hello")
--local token, idx, err
--idx = 1
--while true do
--    token, idx, err = lex:nextToken(idx)
--    if nil == token then
--        break
--    else
--        print(token)
--    end
--end