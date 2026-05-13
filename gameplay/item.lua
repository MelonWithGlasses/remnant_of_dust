-- Предмет на полу (мутаген / протокол / глитч / расходник, кроме мелких пикапов).
-- В отличие от pickup.lua, эти подбираются по клавише E (или контактом, если price = 0),
-- имеют рамку редкости и всплывающую подсказку рядом.
local utils = require("utils")

local M = {}
M.__index = M

local RARITY_COLOR = {
    common    = {0.7, 0.9, 0.7, 1},
    rare      = {0.4, 0.6, 1.0, 1},
    epic      = {0.7, 0.4, 1.0, 1},
    legendary = {1.0, 0.8, 0.3, 1},
}

function M.new(def, x, y, assets, price)
    local self = setmetatable({}, M)
    self.def = def
    self.x = x
    self.y = y
    self.w = 14
    self.h = 14
    self.bob_time = love.math.random() * math.pi * 2
    self.sprite = assets.sprites.items[def.id]
    self.price = price or 0          -- > 0 = в магазине; берётся только за DNA
    self.collected = false
    self.hover = false
    return self
end

-- Возвращает def, если успешно подобран. Иначе nil.
function M:try_pickup(player)
    if self.collected then return nil end
    if self.price > 0 then
        if (player.dna_count or 0) < self.price then return nil end
        player.dna_count = player.dna_count - self.price
    end
    self.collected = true
    return self.def
end

function M:update(dt, player)
    self.bob_time = self.bob_time + dt
    self.hover = player ~= nil and utils.dist(self.x, self.y, player.x, player.y) < 18
end

function M:draw()
    if self.collected then return end
    local img = self.sprite
    if not img then return end
    local iw, ih = img:getWidth(), img:getHeight()
    local bob = math.sin(self.bob_time * 2.4) * 1.5
    local dx = math.floor(self.x - iw / 2)
    local dy = math.floor(self.y - ih / 2 + bob)

    -- Подложка-индикатор редкости (мерцание)
    local rc = RARITY_COLOR[self.def.rarity] or RARITY_COLOR.common
    local pulse = 0.5 + 0.5 * math.sin(self.bob_time * 4)
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.25 + 0.25 * pulse)
    love.graphics.rectangle("fill", dx - 1, dy - 1, iw + 2, ih + 2)
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.9)
    love.graphics.rectangle("line", dx - 1, dy - 1, iw + 2, ih + 2)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, dx, dy)
end

-- Возвращает текст для всплывающей подсказки, если игрок рядом.
function M:get_tooltip()
    if not self.hover or self.collected then return nil end
    local d = self.def
    local lines = { d.name }
    if self.price > 0 then
        table.insert(lines, "Цена: " .. self.price .. " ДНК")
    end
    if d.description then
        table.insert(lines, d.description)
    end
    table.insert(lines, "E — взять")
    return lines, RARITY_COLOR[d.rarity] or RARITY_COLOR.common
end

return M
