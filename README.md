# lua-graphql-parser
A graphQL parser combinator implemented in Lua

# How to test

```shell script
$ busted -c test/*
$ luacov -c luacov.cfg
```


# Design Philosophy

The Lexer handles token boundary directly, the Parser (grammar) doesn't need to handle whitespace at all.

The parser object should be immutable.

```text
Parser number = Parser("%d+")

Parser statement1 = ParserA + number + ParserB
Parser statement2 = ParserX + number + ParserY
``` 

In the above snippet, if we change the content of `number` in `statement2`, it will affect `statement1` as well.

In our implementation, `AndParser|OrParser` are used to group two (only two because it is immutable) into one single item.

When matching the content, especially for `OrParser` or `RepetitionParser`, there can be more than 1 possible match. There are two solutions to this problem

1. when we call `match()`, it returns an `iterator`, and we loop thru the iterator. This solution requires the *caller* to handle the dirty work
2. when we call `match(, next_parsers[])`, we provide the *next* items to match in order to declare it as a match, note the second parameter is an array which makes it works like a recursion, so it can handle OR inside a OR, etc..

I use method *2* as I think it is easier to implement.

