local function lastchar(input)
    return input:sub(#input, #input)
end

Lexer = {}
Lexer.__index = Lexer

function Lexer:new(text)
    local lex = {}
    setmetatable(lex, Lexer)
    self.text = text
    return lex
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
            if lastIsSlash then
                -- do nothing
            else
                if c == "\\" then
                    lastIsSlash = true
                elseif c == "\"" then
                    return text:sub(captureStart, i), i+1, nil
                end
            end
        elseif insideString == 2 then
        else
            if nil ~= string.find("!():=[]{|}", c, 1, true) then
                if captureStart > 0 then
                    return text:sub(captureStart, i), i, nil
                else
                    return c, i+1, nil
                end
            elseif nil ~= string.find("\r\n\t\f ,", c, 1, true) then
                if captureStart > 0 then
                    return text:sub(captureStart, i), i, nil
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
                    insideString = 2
                else
                    insideString = 1
                end
            else
                captureStart = i
            end
        end
        i = i+1
    end
end


local lex = Lexer:new("hello world")
local token, idx, err = lex:nextToken(1)
print(token)