package.path = package.path .. ";../?.lua"

local GqlParser = require("gql-parser")
local GqlNode = require("gql-nodes")
--local inspect = require('inspect')

describe("Testing GraphQL Nodes", function()

    it("Test multi ops", function()
        local query = [[
        {
            human
        }

        fragment comparisonFields on Character {
            name
            appearsIn
            friends {
                name
            }
        }

        mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
          createReview(episode: $ep, review: $review) {
            stars
            commentary
          }
        }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local list = graph:listOps()
        assert.are.same(#list, 2)
        assert.are.same(#list[1].fields, 1)
        assert.are.same(list[1].fields[1].name, "human")
        assert.are.same(#list[2].fields, 1)
        assert.are.same(list[2].fields[1].name, "createReview")
    end)

    it("Test root fields", function()
        local query = [[
        mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
          createReview(episode: $ep, review: $review) {
            stars
            commentary
          }
        }

        fragment comparisonFields on Character {
            name
            appearsIn
            friends {
                name
            }
        }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local list = graph:listOps()
        assert.are.same(#list, 1)
        local rootFields = list[1]:getRootFields()
        assert.are.same(#rootFields, 1)
        assert.are.same(rootFields[1].name, "createReview")
    end)

    it("Test resolveArgument", function()
        local query = [[
        mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
          createReview(episode: $ep, review: $review, age: 10) {
            stars
            commentary
          }
        }

        fragment comparisonFields on Character {
            name
            appearsIn
            friends {
                name
            }
        }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local list = graph:listOps()
        assert.are.same(#list, 1)
        local rootFields = list[1]:getRootFields()
        assert.are.same(#rootFields, 1)
        local rootField = rootFields[1]
        local argument = rootField:resolveArgument({
            ep = "JEDI",
            review = {
                stars = 5,
                commentary = "This is a great movie!"
            }
        })
        local expected = {
            episode = { value = "JEDI", type = { name = "Episode", non_null = true } },
            review = { value = { stars = 5, commentary = "This is a great movie!" }, type = { name = "ReviewInput", non_null = true} },
            age = { value = "10" }
        }
        assert.are.same(argument, expected)
    end)

    it("Test resolveArgument with default value", function()
        local query = [[
        query HeroComparison($first: Int = 3) {
          hero(episode: EMPIRE, first: $first) {
            foobar
          }
        }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local list = graph:listOps()
        assert.are.same(#list, 1)
        local rootFields = list[1]:getRootFields()
        assert.are.same(#rootFields, 1)
        local rootField = rootFields[1]
        local argument = rootField:resolveArgument({})
        local expected = {
            episode = { value = "EMPIRE"},
            first = { value = '3', type = { name = "Int" } }
        }
        assert.are.same(argument, expected)
    end)

    it("Test hasFields easy case", function()
        local query = [[
        mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
          createReview(episode: $ep, review: $review, age: 10) {
            stars
            commentary
          }
        }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local xx = graph:hasFields({"sta"})
        assert.are.same(graph:hasFields({"sta"}), {"createReview.stars"})
        assert.are.same(graph:hasFields({"sta", "tar"}), {"createReview.stars", "createReview.commentary"})
    end)

    it("Test hasFields with fragment", function()
        local query = [[
        mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
          createReview(episode: $ep, review: $review, age: 10) {
            stars
            commentary
            ...comparisonFields
          }
        }

        fragment comparisonFields on Character {
            name
            appearsIn
            friends {
                name
            }
        }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        assert.are.same(graph:hasFields({"name"}), {"createReview.name", "createReview.friends.name"})
        assert.are.same(graph:hasFields({"end"}), {"createReview.friends"})
    end)

    it("Test hasFields with recursive fragment", function()
        local query = [[
        mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
          createReview(episode: $ep, review: $review, age: 10) {
            stars
            commentary
            ...comparisonFields
          }
        }

        fragment comparisonFields on Character {
            name
            appearsIn
            friends {
                name
            }
            ...comparisonFields
        }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local list = graph:listOps()
        assert.are.same(graph:hasFields({"name"}), {"createReview.name", "createReview.friends.name"})
        assert.are.same(graph:hasFields({"end"}), {"createReview.friends"})
    end)

    it("Test hasFields inline fragment", function()
        local query = [[
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
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        assert.are.same(graph:hasFields({"pri", "hei"}), {"hero.primaryFunction", "hero.height"})
    end)

    it("Test nest_depth easy case 1", function()
        local query = [[
        mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
          createReview(episode: $ep, review: $review, age: 10) {
            stars
            commentary
          }
        }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local n = graph:nestDepth()
        assert.are.same(n, 1)
    end)

    it("Test nest_depth easy case 2", function()
        local query = [[
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
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local n = graph:nestDepth()
        assert.are.same(n, 1)
    end)


    it("Test nest_depth easy case 3", function()
        local query = [[
            query Hero($episode: Episode, $withFriends: Boolean!) {
              hero(episode: $episode) {
                name
                friends @include(if: $withFriends) {
                  name
                }
              }
            }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local n = graph:nestDepth()
        assert.are.same(n, 2)
    end)

    it("Test nest_depth inline fragment", function()
        local query = [[
            query Hero($episode: Episode, $withFriends: Boolean!) {
              hero(episode: $episode) {
                name
                friends @include(if: $withFriends) {
                  name
                }
                ... on Droid {
                  primaryFunction {
                    hello
                    world {
                        foo
                        bar
                    }
                  }
                }
                ... on Human {
                  height
                }
              }
            }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local n = graph:nestDepth()
        assert.are.same(n, 3)
    end)

    it("Test nest_depth inline fragment", function()
        local query = [[
        mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
          createReview(episode: $ep, review: $review, age: 10) {
            stars
            commentary
            ...comparisonFields
          }
        }

        fragment comparisonFields on Character {
            name
            appearsIn
            friends {
                name
            }
        }
        ]]
        local p = GqlParser:new()
        local graph = p:parse(query)
        local n = graph:nestDepth()
        assert.are.same(n, 2)
    end)
end)
