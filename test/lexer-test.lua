package.path = package.path .. ";../src/?.lua"

local Lexer = require("graphql-parser.lexer")

describe("Testing Lexer", function()

    it("Test1", function()
        local lex = Lexer:new("hello world((1 -1.1.2 @hello} good)")
        assert.are.same(lex:getToken(1), "hello")
        assert.are.same(lex:getToken(2), "world")
        assert.are.same(lex:getToken(3), "(")
        assert.are.same(lex:getToken(4), "(")
        assert.are.same(lex:getToken(5), "1")
        assert.are.same(lex:getToken(6), "-1.1.2")
        assert.are.same(lex:getToken(7), "@hello")
        assert.are.same(lex:getToken(8), "}")
        assert.are.same(lex:getToken(9), "good")
        assert.are.same(lex:getToken(10), ")")
        assert.are.same(lex:getToken(11), nil)
        -- check back the first item
        assert.are.same(lex:getToken(1), "hello")
    end)

    it("Quoted String", function()
        local lex = Lexer:new('hello abc"world\\" is big"2')
        assert.are.same(lex:getToken(1), "hello")
        assert.are.same(lex:getToken(2), "abc")
        assert.are.same(lex:getToken(3), '"world\\" is big"')
        assert.are.same(lex:getToken(4), "2")
    end)

    it("Block String1", function()
        local lex = Lexer:new('hello """world\r\n123 Haha\t\r\n""" c')
        assert.are.same(lex:getToken(1), "hello")
        --assert.are.same(lex:getToken(2), '"""world\r\n123 Haha\t\r\n"""')
        assert.are.same(lex:getToken(3), 'c')
    end)

    it("Block String2", function()
        local lex = Lexer:new('hello """world \\"\\"world""" c')
        assert.are.same(lex:getToken(1), "hello")
        --assert.are.same(lex:getToken(2), '"""world\r\n123 Haha\t\r\n"""')
        assert.are.same(lex:getToken(3), 'c')
    end)

    it("Comment1", function()
        local lex = Lexer:new([[
        hello 1 #2
        world {
        #}
        @
        ]])
        assert.are.same(lex:getToken(1), "hello")
        assert.are.same(lex:getToken(2), '1')
        assert.are.same(lex:getToken(3), 'world')
        assert.are.same(lex:getToken(4), '{')
        assert.are.same(lex:getToken(5), '@')
    end)

    it("Comment2", function()
        local lex = Lexer:new([[
        hello 1 #2
        world#12]])
        assert.are.same(lex:getToken(1), "hello")
        assert.are.same(lex:getToken(2), '1')
        assert.are.same(lex:getToken(3), 'world')
        assert.are.same(lex:getToken(4), nil)
    end)

    it("Comment3", function()
        local lex = Lexer:new([[
        hello 1 #2
        world#12
        34]])
        assert.are.same(lex:getToken(1), "hello")
        assert.are.same(lex:getToken(2), '1')
        assert.are.same(lex:getToken(3), 'world')
        assert.are.same(lex:getToken(4), '34')
    end)

    it("Comment4", function()
        local lex = Lexer:new([[
        hello 1 #2
        world #12]])
        assert.are.same(lex:getToken(1), "hello")
        assert.are.same(lex:getToken(2), '1')
        assert.are.same(lex:getToken(3), 'world')
        assert.are.same(lex:getToken(4), nil)
    end)
end)
