-- Универсальный рендер партиклов и вспышек.
-- Использует пул объектов (никаких table.insert/remove на горячем пути).
local M = {}
M.__index = M

local POOL_SIZE = 512

function M.new()
    local self = setmetatable({}, M)
    self.pool = {}
    for i = 1, POOL_SIZE do
        self.pool[i] = {alive = false}
    end
    self.flashes = {}
    return self
end

-- Спавн партикла. image — love.Image, params — таблица параметров.
function M:spawn(image, x, y, vx, vy, life, color, scale, fade)
    for i = 1, POOL_SIZE do
        local p = self.pool[i]
        if not p.alive then
            p.alive = true
            p.image = image
            p.x = x; p.y = y
            p.vx = vx or 0; p.vy = vy or 0
            p.life = life
            p.life_max = life
            p.color = color or {1, 1, 1}
            p.scale = scale or 1
            p.fade = fade ~= false
            return p
        end
    end
end

-- Простая радиальная россыпь
function M:burst(image, x, y, count, speed, life, color)
    for i = 1, count do
        local ang = love.math.random() * math.pi * 2
        local sp = speed * (0.5 + love.math.random())
        self:spawn(image, x, y,
            math.cos(ang) * sp, math.sin(ang) * sp,
            life * (0.7 + love.math.random() * 0.6),
            color, 1, true)
    end
end

function M:flash(color, duration)
    table.insert(self.flashes, {color = color or {1, 1, 1, 0.5}, t = duration or 0.1, t_max = duration or 0.1})
end

function M:update(dt)
    for i = 1, POOL_SIZE do
        local p = self.pool[i]
        if p.alive then
            p.life = p.life - dt
            if p.life <= 0 then
                p.alive = false
            else
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                -- лёгкое замедление
                p.vx = p.vx * (1 - 1.5 * dt)
                p.vy = p.vy * (1 - 1.5 * dt)
            end
        end
    end
    for i = #self.flashes, 1, -1 do
        local f = self.flashes[i]
        f.t = f.t - dt
        if f.t <= 0 then table.remove(self.flashes, i) end
    end
end

function M:draw_particles()
    for i = 1, POOL_SIZE do
        local p = self.pool[i]
        if p.alive then
            local a = 1
            if p.fade then a = p.life / p.life_max end
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
            local w = p.image:getWidth()
            local h = p.image:getHeight()
            love.graphics.draw(p.image, math.floor(p.x - w / 2 * p.scale),
                math.floor(p.y - h / 2 * p.scale), 0, p.scale, p.scale)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function M:draw_flashes(w, h)
    for _, f in ipairs(self.flashes) do
        local a = (f.t / f.t_max) * (f.color[4] or 1)
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], a)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return M
