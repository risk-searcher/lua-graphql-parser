package.path = package.path .. ";../?.lua"

local Clazz = require("clazz")

describe("Testing Clazz", function()

    it("Basic stuff", function()
        local Dog = Clazz.class("Dog")
        Dog.bark = function(name)
            return "barking " .. name
        end
        Dog.eat = function()
            return "yummy"
        end
        local Chihuahua = Clazz.class("Chihuahua", Dog)
        Chihuahua.run = function(self, miles)
            if self.can_run >= miles then
                return "happy :)"
            else
                return "tired..."
            end
        end
        Chihuahua.eat = function()
            return "gooooood"
        end
        local some_dog = Dog:new()
        local tira = Chihuahua:new{can_run=10}

        -- bark is from base class
        assert.are.same(tira.bark("sam"), "barking sam")
        -- run is called with ":"
        assert.are.same(tira:run(15), "tired...")

        -- eat is overriden
        assert.are.same(some_dog.eat(), "yummy")
        assert.are.same(tira.eat(), "gooooood")
    end)

    it("MetaMethods", function()
        local Number = Clazz.class("Number")
        Number.__add = function(lhs, rhs)
            return lhs.value + rhs.value
        end

        local RealNumber = Clazz.class("RealNumber", Number)
        local x1 = RealNumber:new{value=10}
        local x2 = RealNumber:new{value=1.1}
        assert.are.same(x1+x2, 11.1)

        local ComplexNumber = Clazz.class("ComplexNumber", RealNumber)
        ComplexNumber.__add = function(lhs, rhs)
            local r = lhs.r + rhs.r
            local i = lhs.i + rhs.i
            return ComplexNumber:new{r=r, i=i}
        end
        ComplexNumber.__mul = function(lhs, rhs)
            local r = lhs.r * rhs.r - lhs.i * rhs.i
            local i = lhs.r * rhs.i + lhs.i * rhs.r
            return ComplexNumber:new{r=r, i=i}
        end

        local c1 = ComplexNumber:new{r=1, i=1}
        local c2 = ComplexNumber:new{r=2, i=3}
        local c3 = c1 + c2
        assert.are.same(c3.r, 3)
        assert.are.same(c3.i, 4)

        local c4 = c1 * c2
        assert.are.same(c4.r, -1)
        assert.are.same(c4.i, 5)
    end)

end)
