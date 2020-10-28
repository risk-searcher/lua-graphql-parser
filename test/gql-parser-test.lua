package.path = package.path .. ";../?.lua"

local Lexer = require("lexer")
local GqlParser = require("gql-parser")
--local inspect = require('inspect')

describe("Testing GraphQL Grammar", function()

    it("Test simple query", function()
        local lex = Lexer:new("query { me { name } }")
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
        local p = GqlParser:new()
        local result = p:parse(lex)
        assert.are.same(expected, result)
    end)

    it("Test arguments", function()
        local lex = Lexer:new("{human(id: 1000) { name, height(unit: FOOT)}}")
        local expected = {
            [1] = {
                type = "query",
                fields = {
                    [1] = {
                        name = "human",
                        arguments = {
                            { name = "id", value = "1000" }
                        },
                        fields = {
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
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
        assert.are.same(expected, result)
    end)

    it("Test aliases", function()
        local lex = Lexer:new("{ empireHero: hero(episode: EMPIRE) {name} jediHero: hero(episode: JEDI) { name } }")
        local expected = {
            [1] = {
                type = "query",
                fields = {
                    [1] = {
                        alias = "empireHero",
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "EMPIRE" }
                        },
                        fields = {
                            { name = "name" }
                        }
                    },
                    [2] = {
                        alias = "jediHero",
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "JEDI" }
                        },
                        fields = {
                            { name = "name" }
                        }
                    }
                }
            }
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
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
        local expected = {
            [1] = {
                type = "query",
                fields = {
                    [1] = {
                        alias = "leftComparison",
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "EMPIRE" }
                        },
                        fields = {
                            { fragment = "comparisonFields" }
                        }
                    },
                    [2] = {
                        alias = "rightComparison",
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "JEDI" }
                        },
                        fields = {
                            { fragment = "comparisonFields" }
                        }
                    }
                }
            },
            [2] = {
                fragment = "comparisonFields",
                on = "Character",
                fields = {
                    [1] = {
                        name = "name",
                    },
                    [2] = {
                        name = "appearsIn",
                    },
                    [3] = {
                        name = "friends",
                        fields = {
                            [1] = {
                                name = "name"
                            }
                        }
                    }
                }
            }
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
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
        local expected = {
            [1] = {
                type = "query",
                name = "HeroNameAndFriends",
                variables = {
                    [1] = {
                        name = "$episode",
                        type = { name = "Episode" }
                    }
                },
                fields = {
                    [1] = {
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "$episode" }
                        },
                        fields = {
                            [1] = { name = "name"},
                            [2] = {
                                name = "friends",
                                fields = {
                                    [1] = { name = "name"}
                                }
                            }
                        }
                    }
                }
            }
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
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
        local expected = {
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
                fields = {
                    [1] = {
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "$episode" }
                        },
                        fields = {
                            [1] = { name = "name"},
                            [2] = {
                                name = "friends",
                                fields = {
                                    [1] = { name = "name"}
                                }
                            }
                        }
                    }
                }
            }
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
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
        local expected = {
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
                fields = {
                    [1] = {
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "$episode" }
                        },
                        fields = {
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
                                fields = {
                                    [1] = { name = "name"}
                                }
                            }
                        }
                    }
                }
            }
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
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
        local expected = {
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
                fields = {
                    [1] = {
                        name = "createReview",
                        arguments = {
                            { name = "episode", value = "$ep" },
                            { name = "review", value = "$review"}
                        },
                        fields = {
                            [1] = { name = "stars"},
                            [2] = { name = "commentary" }
                        }
                    }
                }
            }
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
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
        local expected = {
            [1] = {
                type = "query",
                name = "HeroForEpisode",
                variables = {
                    [1] = {
                        name = "$ep",
                        type = { name = "Episode", non_null = true }
                    }
                },
                fields = {
                    [1] = {
                        name = "hero",
                        arguments = {
                            { name = "episode", value = "$ep" }
                        },
                        fields = {
                            [1] = { name = "name" },
                            [2] = {
                                on = "Droid",
                                fields = {
                                    [1] = { name = "primaryFunction" }
                                }
                            },
                            [3] = {
                                on = "Human",
                                fields = {
                                    [1] = { name = "height" }
                                }
                            }
                        }
                    }
                }
            }
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
        assert.are.same(expected, result)
    end)

    it("Test object value", function()
        local lex = Lexer:new([[
            query foobar($name: String!) {
              station(input: {name: $name, age: 10}) {
                name
                height
              }
            }
        ]])
        local expected = {
            [1] = {
                type = "query",
                name = "foobar",
                variables = {
                    [1] = {
                        name = "$name",
                        type = { name = "String", non_null = true }
                    }
                },
                fields = {
                    [1] = {
                        name = "station",
                        arguments = {
                            [1] = {
                                name = "input",
                                value = {
                                    { name = "name", value ="$name" },
                                    { name = "age", value = "10" }
                                }
                            }
                        },
                        fields = {
                            [1] = { name = "name" },
                            [2] = { name = "height" }
                        }
                    }
                }
            }
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
        assert.are.same(expected, result)
    end)

    it("Test array value", function()
        local lex = Lexer:new([[
            query foobar($name1: String!, $name2: String!) {
              station(input: [$name1, $name2]) {
                name
                height
              }
            }
        ]])
        local expected = {
            [1] = {
                type = "query",
                name = "foobar",
                variables = {
                    [1] = {
                        name = "$name1",
                        type = { name = "String", non_null = true }
                    },
                    [2] = {
                        name = "$name2",
                        type = { name = "String", non_null = true }
                    }
                },
                fields = {
                    [1] = {
                        name = "station",
                        arguments = {
                            [1] = {
                                name = "input",
                                value = { "$name1", "$name2" }
                            }
                        },
                        fields = {
                            [1] = { name = "name" },
                            [2] = { name = "height" }
                        }
                    }
                }
            }
        }
        local p = GqlParser:new()
        local result = p:parse(lex)
        assert.are.same(expected, result)
    end)
end)
