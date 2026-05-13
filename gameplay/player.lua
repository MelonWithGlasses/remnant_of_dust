-- Игрок: класс Нити, движение, прицел, стрельба, перегрев, синапсы (HP).
local utils = require("utils")
local projectile = require("gameplay.projectile")

local M = {}
M.__index = M

function M.new(class_def, x, y, assets)
    local self = setmetatable({}, M)
    self.class = class_def
    self.x = x
    self.y = y
    self.w = 10
    self.h = 12

    self.speed = class_def.speed
    self.fire_rate = class_def.fire_rate
    self.damage = class_def.damage
    self.heat_per_shot = class_def.heat_per_shot
    self.cool_rate = class_def.cool_rate

    self.max_synapses = class_def.max_synapses
    self.hp = self.max_synapses * 2
    self.max_hp = self.max_synapses * 2

    self.heat = 0
    self.overheated = false
    self.overheat_timer = 0

    self.shoot_cooldown = 0
    self.invuln = 0

    self.facing = 1   -- 1 = вправо, -1 = влево
    self.anim_time = 0
    self.anim_state = "idle"

    -- Прогресс по специальным пикапам
    self.glial_count = 0
    self.dna_count = 0
    self.codex_count = 0

    -- Статистика забега
    self.stats = {kills = 0, time = 0, items = 0, integrations = 0}

    self.assets = assets
    self.sprites = assets.sprites.player[class_def.id]
    return self
end

function M:get_aim_angle(target_x, target_y)
    return math.atan2(target_y - self.y, target_x - self.x)
end

function M:shoot(target_x, target_y, projectile_pool)
    if self.shoot_cooldown > 0 or self.overheated then return end
    local ang = self:get_aim_angle(target_x, target_y)
    local speed = 160
    local vx = math.cos(ang) * speed
    local vy = math.sin(ang) * speed
    projectile.spawn(projectile_pool, {
        x = self.x, y = self.y,
        vx = vx, vy = vy,
        damage = self.damage, team = "player",
        life = 1.0, image = self.assets.sprites.particles.bullet,
        color = self.class.color_secondary,
    })
    self.shoot_cooldown = 1 / self.fire_rate
    self.heat = self.heat + self.heat_per_shot
    if self.heat >= 100 then
        self.heat = 100
        self.overheated = true
        self.overheat_timer = 2.0
    end
end

function M:take_damage(amount)
    if self.invuln > 0 then return false end
    self.hp = self.hp - amount
    self.invuln = 0.8
    return true
end

function M:heal_synapse()
    self.max_synapses = self.max_synapses + 1
    self.max_hp = self.max_synapses * 2
    self.hp = self.hp + 2
end

-- ai: input — таблица с методами is_mouse_down, get_mouse_logical, get_move_axis
function M:update(dt, input, projectile_pool, room)
    self.stats.time = self.stats.time + dt
    if self.invuln > 0 then self.invuln = self.invuln - dt end
    if self.shoot_cooldown > 0 then self.shoot_cooldown = self.shoot_cooldown - dt end

    -- Охлаждение
    if not self.overheated then
        self.heat = math.max(0, self.heat - self.cool_rate * dt)
    end
    if self.overheated then
        self.overheat_timer = self.overheat_timer - dt
        if self.overheat_timer <= 0 then
            self.overheated = false
            self.heat = 0
        end
    end

    -- Движение
    local dx, dy = input:get_move_axis()
    local prev_x, prev_y = self.x, self.y
    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt

    if room then
        -- Ограничение по комнате (учитываем отступ под стены)
        self.x = utils.clamp(self.x, room.x + 12, room.x + room.w - 12)
        self.y = utils.clamp(self.y, room.y + 12, room.y + room.h - 12)
    end

    if dx ~= 0 then self.facing = (dx > 0) and 1 or -1 end

    if dx ~= 0 or dy ~= 0 then
        self.anim_state = "run"
    else
        self.anim_state = "idle"
    end
    self.anim_time = self.anim_time + dt

    -- Прицеливание и стрельба
    local mx, my = input:get_mouse_logical()
    local cam = room and room.camera or nil
    if cam then
        mx = mx + cam.x
        my = my + cam.y
    end
    if input:is_mouse_down(1) then
        self:shoot(mx, my, projectile_pool)
    end
end

function M:get_current_sprite()
    local set = self.sprites[self.anim_state] or self.sprites.idle
    local fps = 6
    local frame = (math.floor(self.anim_time * fps) % #set) + 1
    return set[frame]
end

function M:draw()
    if self.invuln > 0 and math.floor(self.invuln * 20) % 2 == 0 then
        love.graphics.setColor(1, 0.5, 0.5, 0.7)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    local img = self:get_current_sprite()
    local w = img:getWidth()
    local h = img:getHeight()
    local sx = self.facing < 0 and -1 or 1
    local ox = self.facing < 0 and w or 0
    love.graphics.draw(img,
        math.floor(self.x - w / 2),
        math.floor(self.y - h / 2),
        0, sx, 1, ox, 0)
    love.graphics.setColor(1, 1, 1, 1)
end

function M:is_dead()
    return self.hp <= 0
end

return M
