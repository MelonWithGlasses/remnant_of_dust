-- Снаряды (пули). Простой пул объектов, AABB-коллизии.
local utils = require("utils")

local M = {}
M.__index = M

local POOL_SIZE = 256

function M.new_pool()
    local pool = {}
    for i = 1, POOL_SIZE do
        pool[i] = {alive = false}
    end
    return pool
end

-- Создать снаряд из пула.
function M.spawn(pool, params)
    for i = 1, POOL_SIZE do
        local p = pool[i]
        if not p.alive then
            p.alive = true
            p.x = params.x; p.y = params.y
            p.vx = params.vx; p.vy = params.vy
            p.damage = params.damage or 1
            p.team = params.team or "player"   -- "player" | "enemy"
            p.life = params.life or 1.2
            p.radius = params.radius or 2
            p.w = 4; p.h = 4
            p.image = params.image
            p.color = params.color or {1, 1, 0.6}
            p.pierce = params.pierce or false
            return p
        end
    end
end

function M.update(pool, dt, room)
    for i = 1, POOL_SIZE do
        local p = pool[i]
        if p.alive then
            p.life = p.life - dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            -- Стены комнаты
            if room and (p.x < room.x or p.x > room.x + room.w
                      or p.y < room.y or p.y > room.y + room.h) then
                p.alive = false
            end
            if p.life <= 0 then p.alive = false end
        end
    end
end

function M.draw(pool)
    for i = 1, POOL_SIZE do
        local p = pool[i]
        if p.alive and p.image then
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], 1)
            local w = p.image:getWidth()
            local h = p.image:getHeight()
            love.graphics.draw(p.image, math.floor(p.x - w / 2),
                math.floor(p.y - h / 2))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Итератор живых снарядов
function M.iter(pool)
    local i = 0
    return function()
        while i < POOL_SIZE do
            i = i + 1
            if pool[i].alive then return pool[i] end
        end
    end
end

return M
