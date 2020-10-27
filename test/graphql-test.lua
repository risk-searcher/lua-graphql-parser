package.path = package.path .. ";../?.lua"

local Lexer = require("lexer")
local gql = require("graphql")
local inspect = require('inspect')

local remove_all_metatables = function(item, path)
    if path[#path] ~= inspect.METATABLE then return item end
end

local my_clone
my_clone = function(obj)
    local clone = {}
    for k, v in pairs(obj) do
        if type(k) == "string" and string.match(k, "^__") then
            -- do nothing
        else
            if type(v) == "table" then
                clone[k] = my_clone(v)
            else
                clone[k] = v
            end
        end
    end
    return clone
end

describe("Testing GraphQL Grammar", function()

    it("Test simple query", function()
        local lex = Lexer:new("query { me { name } }")
        local expected = {list={
            [1] = {
                type = "query",
                selection_set = {
                    [1] = {
                        name = "me",
                        selection_set = {
                            { name = "name" }
                        }
                    }
                }
            }
        }}
        local matcher = gql:match(lex, 1, false, nil)
        local result = my_clone(matcher:pop())
        assert.are.same(expected, result)
    end)

    it("Test arguments", function()
        local lex = Lexer:new("{human(id: 1000) { name, height(unit: FOOT)}}")
        local expected = {list={
            [1] = {
                type = "query",
                selection_set = {
                    [1] = {
                        name = "human",
                        arguments = {
                            { name = "id", value = "1000" }
                        },
                        selection_set = {
                            {
                                name = "name"
                            },
                            {
                                name = "height",
                                arguments = {
                                    { name = "unit", value = "FOOT"}
                                }
                            }
                        }
                    }
                }
            }
        }}
        local matcher = gql:match(lex, 1, false, nil)
        local result = my_clone(matcher:pop())
        assert.are.same(expected, result)
    end)

    it("Test aliases", function()
        local lex = Lexer:new("{ empireHero: hero(episode: EMPIRE) {name} jediHero: hero(episode: JEDI) { name } }")
        local expected = {list={
            [1] = {
                type = "query",
                selection_set = {
                    [1] = {
                        alias = "empireHero",
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "EMPIRE" }
                        },
                        selection_set = {
                            { name = "name" }
                        }
                    },
                    [2] = {
                        alias = "jediHero",
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "JEDI" }
                        },
                        selection_set = {
                            { name = "name" }
                        }
                    }
                }
            }
        }}
        local matcher = gql:match(lex, 1, false, nil)
        local result = my_clone(matcher:pop())
        assert.are.same(expected, result)
    end)

    it("Test fragments", function()
        local lex = Lexer:new([[
        {
            leftComparison: hero(episode: EMPIRE) {
                ...comparisonFields
            }
            rightComparison: hero(episode: JEDI) {
                ...comparisonFields
            }
        }

        fragment comparisonFields on Character {
            name
            appearsIn
            friends {
                name
            }
        }]])
        local expected = {list={
            [1] = {
                type = "query",
                selection_set = {
                    [1] = {
                        alias = "leftComparison",
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "EMPIRE" }
                        },
                        selection_set = {
                            { fragment = "...comparisonFields" }
                        }
                    },
                    [2] = {
                        alias = "rightComparison",
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "JEDI" }
                        },
                        selection_set = {
                            { fragment = "...comparisonFields" }
                        }
                    }
                }
            },
            [2] = {
                type = "fragment",
                name = "comparisonFields",
                on = "Character",
                selection_set = {
                    [1] = {
                        name = "name",
                    },
                    [2] = {
                        name = "appearsIn",
                    },
                    [3] = {
                        name = "friends",
                        selection_set = {
                            [1] = {
                                name = "name"
                            }
                        }
                    }
                }
            }
        }}
        local matcher = gql:match(lex, 1, false, nil)
        local result = my_clone(matcher:pop())
        --print(inspect(result, {process=remove_all_metatables}))
        assert.are.same(expected, result)
    end)

    it("Test operation", function()
        local lex = Lexer:new([[
            query HeroNameAndFriends($episode: Episode) {
              hero(episode: $episode) {
                name
                friends {
                  name
                }
              }
            }
        ]])
        local expected = {list={
            [1] = {
                type = "query",
                name = "HeroNameAndFriends",
                variables = {
                    [1] = {
                        name = "$episode",
                        type = { name = "Episode" }
                    }
                },
                selection_set = {
                    [1] = {
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "$episode" }
                        },
                        selection_set = {
                            [1] = { name = "name"},
                            [2] = {
                                name = "friends",
                                selection_set = {
                                    [1] = { name = "name"}
                                }
                            }
                        }
                    }
                }
            }
        }}
        local matcher = gql:match(lex, 1, false, nil)
        local result = my_clone(matcher:pop())
        --print(inspect(result.list[1].variables, {process=remove_all_metatables}))
        --print(inspect(expected.list[1].variables, {process=remove_all_metatables}))
        assert.are.same(expected, result)
    end)

    it("Test default variables", function()
        local lex = Lexer:new([[
            query HeroNameAndFriends($episode: Episode = JEDI) {
              hero(episode: $episode) {
                name
                friends {
                  name
                }
              }
            }
        ]])
        local expected = {list={
            [1] = {
                type = "query",
                name = "HeroNameAndFriends",
                variables = {
                    [1] = {
                        name = "$episode",
                        type = { name = "Episode" },
                        default_value = "JEDI"
                    }
                },
                selection_set = {
                    [1] = {
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "$episode" }
                        },
                        selection_set = {
                            [1] = { name = "name"},
                            [2] = {
                                name = "friends",
                                selection_set = {
                                    [1] = { name = "name"}
                                }
                            }
                        }
                    }
                }
            }
        }}
        local matcher = gql:match(lex, 1, false, nil)
        local result = my_clone(matcher:pop())
        --print(inspect(result.list[1].variables, {process=remove_all_metatables}))
        --print(inspect(expected.list[1].variables, {process=remove_all_metatables}))
        assert.are.same(expected, result)
    end)

    it("Test directives", function()
        local lex = Lexer:new([[
            query Hero($episode: Episode, $withFriends: Boolean!) {
              hero(episode: $episode) {
                name
                friends @include(if: $withFriends) {
                  name
                }
              }
            }
        ]])
        local expected = {list={
            [1] = {
                type = "query",
                name = "Hero",
                variables = {
                    [1] = {
                        name = "$episode",
                        type = { name = "Episode" }
                    },
                    [2] = {
                        name = "$withFriends",
                        type = { name = "Boolean", non_null = true }
                    }
                },
                selection_set = {
                    [1] = {
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "$episode" }
                        },
                        selection_set = {
                            [1] = { name = "name"},
                            [2] = {
                                name = "friends",
                                directives = {
                                    [1] = {
                                        name = "@include",
                                        arguments = {
                                            { name = "if", value = "$withFriends" }
                                        }
                                    }
                                },
                                selection_set = {
                                    [1] = { name = "name"}
                                }
                            }
                        }
                    }
                }
            }
        }}
        local matcher = gql:match(lex, 1, false, nil)
        local result = my_clone(matcher:pop())
        --print(inspect(result.list[1].selection_set, {process=remove_all_metatables}))
        --print(inspect(expected.list[1].selection_set, {process=remove_all_metatables}))
        assert.are.same(expected, result)
    end)

    it("Test mutations", function()
        local lex = Lexer:new([[
            mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
              createReview(episode: $ep, review: $review) {
                stars
                commentary
              }
            }
        ]])
        local expected = {list={
            [1] = {
                type = "mutation",
                name = "CreateReviewForEpisode",
                variables = {
                    [1] = {
                        name = "$ep",
                        type = { name = "Episode", non_null = true }
                    },
                    [2] = {
                        name = "$review",
                        type = { name = "ReviewInput", non_null = true }
                    }
                },
                selection_set = {
                    [1] = {
                        name = "createReview",
                        arguments = {
                            { name = "episode", value = "$ep" },
                            { name = "review", value = "$review"}
                        },
                        selection_set = {
                            [1] = { name = "stars"},
                            [2] = { name = "commentary" }
                        }
                    }
                }
            }
        }}
        local matcher = gql:match(lex, 1, false, nil)
        local result = my_clone(matcher:pop())
        --print(inspect(result.list[1].selection_set, {process=remove_all_metatables}))
        --print(inspect(expected.list[1].selection_set, {process=remove_all_metatables}))
        assert.are.same(expected, result)
    end)

    it("Test inline fragment", function()
        local lex = Lexer:new([[
            query HeroForEpisode($ep: Episode!) {
              hero(episode: $ep) {
                name
                ... on Droid {
                  primaryFunction
                }
                ... on Human {
                  height
                }
              }
            }
        ]])
        local expected = {list={
            [1] = {
                type = "query",
                name = "HeroForEpisode",
                variables = {
                    [1] = {
                        name = "$ep",
                        type = { name = "Episode", non_null = true }
                    }
                },
                selection_set = {
                    [1] = {
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "$ep" }
                        },
                        selection_set = {
                            [1] = { name = "name" },
                            [2] = {
                                on = "Droid",
                                selection_set = {
                                    [1] = { name = "primaryFunction" }
                                }
                            },
                            [3] = {
                                on = "Human",
                                selection_set = {
                                    [1] = { name = "height" }
                                }
                            }
                        }
                    }
                }
            }
        }}
        local matcher = gql:match(lex, 1, false, nil)
        local result = my_clone(matcher:pop())
        --print(inspect(result.list[1].selection_set, {process=remove_all_metatables}))
        --print(inspect(expected.list[1].selection_set, {process=remove_all_metatables}))
        assert.are.same(expected, result)
    end)
end)
