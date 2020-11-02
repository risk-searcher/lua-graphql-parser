# lua-graphql-parser
A graphQL parser combinator implemented in Lua

[![Build Status](https://travis-ci.com/samngms/lua-graphql-parser.svg?branch=main)](https://travis-ci.com/samngms/lua-graphql-parser)
[![Test coverage](https://codecov.io/gh/samngms/lua-graphql-parser/branch/main/graph/badge.svg?token=VA524SPWKR)](https://codecov.io/gh/samngms/lua-graphql-parser)

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
