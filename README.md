# lua-graphql-parser
A graphQL parser implemented in Lua

[![Build Status](https://travis-ci.com/samngms/lua-graphql-parser.svg?branch=main)](https://travis-ci.com/samngms/lua-graphql-parser)
[![Test coverage](https://codecov.io/gh/samngms/lua-graphql-parser/branch/main/graph/badge.svg?token=VA524SPWKR)](https://codecov.io/gh/samngms/lua-graphql-parser)
[![LuaRocks](https://img.shields.io/badge/-LuaRocks-blue)](https://luarocks.org/modules/samngms/graphql-parser)

# How to use

```
local GqlParser = require('graphql-parser')
local parser = GqlParser:new()
local graph = parser:parse('query { me { name } }')
local expected = {
    [1] = {
        type = "query",
        fields = {
            [1] = {
                name = "me",
                fields = {
                    { name = "name" }
                }
            }
        }
    }
}
assert.are.same(graph, expected)
```

All language according to http://spec.graphql.org/June2018/ should have been implemented.

# API


### `GqlParser:parse(graphQL_string)`

Parse an input GraphQL string, returns a `Gql.Document` 

Example:
```
local parser = GqlParser:new()
local graph = parser:parse(query)
```

### `GqlParser.Document:listOps()`

Return list of operations (excluding Fragments), each element of the list is a `Gql.Operation`

Example:
```
local parser = GqlParser:new()
local graph = parser:parse(query)
for _, op in graph:listOps() do
    -- op is a GraphQL operation, maybe a query/mutation/subscribe
end
```

### `GqlParser.Document:findFragment(name)`

Return the fragment definition, nil if not found

Example:
```
-- refer to https://graphql.org/learn/queries/#fragments
local parser = GqlParser:new()
local graph = parser:parse(query)
local fragment = graph:findFragment("comparisonFields")
```

### `GqlParser.Document:hasFields(pattern_list)`

Check if the document contains any fields matching `pattern_list` (which is a list of regex patterns). Return the list of matching field names.

Example:
```
local parser = GqlParser:new()
local graph = parser:parse(query)
local output = graph:hashFields({"__"})
```

### `GqlParser.Document:nestDepth()`

Return the max nest depth of the whole document. The value is the depth under root element.

Example:
```
local parser = GqlParser:new()
local graph = parser:parse(query)
local n = graph:nestDepth()
```

### `GqlParser.Operation:getRootFields()`

Within the operation (i.e. a query or a mutation), return the list of root fields. Note, it usually should only have ONE root field but it does not necessary need to be. The return value is a list of `Gql.RootField`

Example:
```
-- refer to https://graphql.org/learn/queries/#using-variables-inside-fragments
local parser = GqlParser:new()
local graph = parser:parse(query)
for _, op in graph:listOps() do
    local roots = op:getRootFields()
    -- the first root is hero, the second is also hero
end
```

### `GqlParser.RootField:resolveArgument(input)`

Resolve the field argument using `input` as the query input. Note `input` should be a JSON, and you probably will need to use `cjson` to parse it. The return value is the resolved argument as a JSON object.

Example:
```
-- refer to https://graphql.org/learn/queries/#using-variables-inside-fragments
local parser = GqlParser:new()
local graph = parser:parse(query)
local argument = graph:listOps()[1]:getRootFields()[1]:resolveArgument({})
local expected = {episode = "EMPIRE"}
assert.are.same(argument, expected)
```
 
# How to test

```shell script
$ busted -c test/*
$ luacov -c luacov.cfg
```
