-- Базовый класс врага. Простая state-machine по полю ai_type.
local utils = require("utils")
local projectile = require("gameplay.projectile")

local M = {}
M.__index = M

function M.new(def, x, y, assets)
    local self = setmetatable({}, M)
    self.def = def
    self.x = x
    self.y = y
    self.w = def.size
    self.h = def.size
    self.hp = def.hp
    self.max_hp = def.hp
    self.speed = def.speed
    self.damage = def.damage
    self.ai_type = def.ai_type

    self.shoot_cd = def.shoot_cooldown and (love.math.random() * def.shoot_cooldown) or 0
    self.spawn_cd = def.spawn_cooldown and (love.math.random() * def.spawn_cooldown) or 0
    self.dash_telegraph = 0
    self.dash_time = 0
    self.dash_dx, self.dash_dy = 0, 0
    self.spawned = {}
    self.flash = 0
    self.dead = false

    self.assets = assets
    self.sprite = assets.sprites.enemies[def.id]
    return self
end

local function move_towards(self, target_x, target_y, dt)
    local dx, dy = utils.normalize(target_x - self.x, target_y - self.y)
    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt
end

local function maintain_distance(self, target_x, target_y, dt, min_d, max_d)
    local dx = target_x - self.x
    local dy = target_y - self.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then return end
    local nx, ny = dx / d, dy / d
    if d < min_d then
        self.x = self.x - nx * self.speed * dt
        self.y = self.y - ny * self.speed * dt
    elseif d > max_d then
        self.x = self.x + nx * self.speed * dt
        self.y = self.y + ny * self.speed * dt
    end
end

function M:update(dt, ctx)
    if self.dead then return end
    if self.flash > 0 then self.flash = self.flash - dt end
    local player = ctx.player
    if not player then return end
    local px, py = player.x, player.y

    if self.ai_type == "chaser" then
        move_towards(self, px, py, dt)
    elseif self.ai_type == "shooter" then
        maintain_distance(self, px, py, dt, 80, 120)
        self.shoot_cd = self.shoot_cd - dt
        if self.shoot_cd <= 0 then
            self.shoot_cd = self.def.shoot_cooldown or 2
            local ang = math.atan2(py - self.y, px - self.x)
            local sp = self.def.bullet_speed or 100
            projectile.spawn(ctx.projectile_pool, {
                x = self.x, y = self.y,
                vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
                damage = self.def.bullet_damage or 1,
                team = "enemy", life = 2.5,
                image = ctx.assets.sprites.particles.acid,
                color = self.def.color_secondary,
            })
        end
    elseif self.ai_type == "tank" then
        move_towards(self, px, py, dt)
    elseif self.ai_type == "dasher" then
        if self.dash_time > 0 then
            self.x = self.x + self.dash_dx * (self.def.dash_speed or 220) * dt
            self.y = self.y + self.dash_dy * (self.def.dash_speed or 220) * dt
            self.dash_time = self.dash_time - dt
        elseif self.dash_telegraph > 0 then
            self.dash_telegraph = self.dash_telegraph - dt
            if self.dash_telegraph <= 0 then
                local nx, ny = utils.normalize(px - self.x, py - self.y)
                self.dash_dx, self.dash_dy = nx, ny
                self.dash_time = 0.35
            end
        else
            local d = utils.dist(self.x, self.y, px, py)
            if d < 80 then
                self.dash_telegraph = self.def.telegraph_time or 1.0
            else
                move_towards(self, px, py, dt)
            end
        end
    elseif self.ai_type == "spawner" then
        -- неподвижен; периодически спавнит мини-врагов
        self.spawn_cd = self.spawn_cd - dt
        -- очистка списка мёртвых
        for i = #self.spawned, 1, -1 do
            if self.spawned[i].dead then table.remove(self.spawned, i) end
        end
        if self.spawn_cd <= 0 and #self.spawned < (self.def.spawn_max or 3) then
            self.spawn_cd = self.def.spawn_cooldown or 3
            if ctx.spawn_enemy then
                local spawn_id = self.def.spawn_id or "slug"
                local ang = love.math.random() * math.pi * 2
                local r = 16
                local nx = self.x + math.cos(ang) * r
                local ny = self.y + math.sin(ang) * r
                local e = ctx.spawn_enemy(spawn_id, nx, ny)
                if e then table.insert(self.spawned, e) end
            end
        end
    end

    -- Удержание в пределах комнаты
    if ctx.room then
        self.x = utils.clamp(self.x, ctx.room.x + 8, ctx.room.x + ctx.room.w - 8)
        self.y = utils.clamp(self.y, ctx.room.y + 8, ctx.room.y + ctx.room.h - 8)
    end
end

function M:take_damage(amount)
    if self.dead then return end
    self.hp = self.hp - amount
    self.flash = 0.08
    if self.hp <= 0 then self.dead = true end
end

function M:draw()
    if self.dead then return end
    if self.dash_telegraph > 0 then
        love.graphics.setColor(1, 0.4, 0.4, 1)
    elseif self.flash > 0 then
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    local img = self.sprite
    local w = img:getWidth()
    local h = img:getHeight()
    love.graphics.draw(img,
        math.floor(self.x - w / 2),
        math.floor(self.y - h / 2))
    love.graphics.setColor(1, 1, 1, 1)

    -- HP-полоска над врагом (если есть урон)
    if self.hp < self.max_hp then
        local bw = math.max(8, w - 2)
        local bh = 1
        local bx = math.floor(self.x - bw / 2)
        local by = math.floor(self.y - h / 2 - 3)
        love.graphics.setColor(0.2, 0.05, 0.05, 1)
        love.graphics.rectangle("fill", bx, by, bw, bh)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", bx, by, bw * self.hp / self.max_hp, bh)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return M
