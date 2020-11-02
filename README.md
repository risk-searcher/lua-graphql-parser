# lua-graphql-parser
A graphQL parser combinator implemented in Lua

# How to use

```
local p = require('graphql-parser')
local result = p:parse('query { me { name } }')
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
```

All language according to http://spec.graphql.org/June2018/ should be implemented.

# How to test

```shell script
$ busted -c test/*
$ luacov -c luacov.cfg
```
