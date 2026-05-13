-- Пикапы на полу (глиальные клетки, фрагменты ДНК, фрагменты памяти, ключи).
local utils = require("utils")

local M = {}
M.__index = M

function M.new(item_def, x, y, assets)
    local self = setmetatable({}, M)
    self.def = item_def
    self.id = item_def.id
    self.x = x
    self.y = y
    self.w = 12
    self.h = 12
    self.bob_time = love.math.random() * math.pi * 2
    self.collected = false
    self.sprite = assets.sprites.items[item_def.id]
    return self
end

function M:update(dt, player)
    self.bob_time = self.bob_time + dt
    if not self.collected and player and utils.dist(self.x, self.y, player.x, player.y) < 10 then
        self.collected = true
        return self.def
    end
end

function M:draw()
    if self.collected then return end
    local img = self.sprite
    local w = img:getWidth()
    local h = img:getHeight()
    local bob = math.sin(self.bob_time * 3) * 1.5
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img,
        math.floor(self.x - w / 2),
        math.floor(self.y - h / 2 + bob))
end

return M
