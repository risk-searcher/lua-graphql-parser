package.path = package.path .. ";../?.lua"

local GqlParser = require("gql-parser")
--local inspect = require('inspect')

local assert = require("luassert")
local say    = require("say") --our i18n lib, installed through luarocks, included as a luassert dependency

local function has_perror(state, arguments)
    local fn = arguments[2]
    local expected_err = arguments[1]
    local status, real_err = pcall(fn)
    local result = false
    if not status then
        local startIdx, endIdx = string.find(real_err, expected_err, 1, true)
        if startIdx then
            result = true
        end
    else
        real_err = "completed with no error"
    end
    arguments[2] = real_err
    return result
end

say:set_namespace("en")
say:set("assertion.has_perror.positive", "Expect an error with %s, %s")
say:set("assertion.has_perror.negative", "Failed with expected %s")
assert:register("assertion", "has_perror", has_perror, "assertion.has_perror.positive", "assertion.has_perror.negative")


describe("Testing GraphQL Grammar", function()

    it("Test unbalanced brace", function()
        local query = "query { me { name } "
        local p = GqlParser:new()
        assert.has_perror("after token[6]", function () p:parse(query) end)
    end)

    it("Test invalid (", function()
        local query = "query { me { ( name } }"
        local p = GqlParser:new()
        assert.has_perror("after token[4]", function () p:parse(query) end)
    end)

    it("Test invalid )", function()
        local query = "query { me { )name } }"
        local p = GqlParser:new()
        assert.has_perror("after token[4]", function () p:parse(query) end)
    end)

    it("Test type", function()
        local query = "queries { me { name } }"
        local p = GqlParser:new()
        assert.has_perror("at token[1]", function () p:parse(query) end)
    end)

    it("Test missing ':'", function()
        local query = [[
            query foobar($name1 String!, $name2: String!) {
              station(input: [$name1, $name2]) {
                name
                height
              }
            }
        ]]
        local p = GqlParser:new()
        assert.has_perror("after token[4]", function () p:parse(query) end)
    end)

    it("Test missing ':'", function()
        local query = [[
            query foobar [
              station(input: [$name1, $name2]) {
                name
                height
              }
            }
        ]]
        local p = GqlParser:new()
        assert.has_perror("after token[2]", function () p:parse(query) end)
    end)

    it("Test invalid field name", function()
        local query = [[
            query foobar($name1: String!, $name2: String!) {
              station(input: [$name1, $name2]) {
                $name
                height
              }
            }
        ]]
        local p = GqlParser:new()
        assert.has_perror("after token[23]", function () p:parse(query) end)
    end)

    it("Test invalid field name", function()
        local query = [[
            query foobar($name1: String!, $name2: String!) {
              station(input: [$name1, $name2]) {
                name.2
                height
              }
            }
        ]]
        local p = GqlParser:new()
        assert.has_perror("after token[23]", function () p:parse(query) end)
    end)

    it("Test invalid object key name", function()
        local query = [[
            query foobar($name1: String!, $name2: String!) {
              station(input: {$name1, $name2}) {
                name
                height
              }
            }
        ]]
        local p = GqlParser:new()
        assert.has_perror("after token[18]", function () p:parse(query) end)
    end)

    it("Test invalid fragment", function()
        local query = [[
            {
                leftComparison: hero(episode: EMPIRE) {
                    ...comparisonFields
                }
            }

            fragment comparisonFields in Character {
                name
            }
        ]]
        local p = GqlParser:new()
        assert.has_perror("after token[15]", function () p:parse(query) end)
    end)

    it("Test invalid fragment", function()
        local query = [[
            {
                leftComparison: hero(episode: EMPIRE) {
                    ...comparisonFields
                }
            }

            fragment on on Character {
                name
            }
        ]]
        local p = GqlParser:new()
        assert.has_perror("after token[14]", function () p:parse(query) end)
    end)
end)
