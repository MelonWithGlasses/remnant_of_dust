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

    -- Базовые статы (берутся из класса; модификаторы итемов их множат)
    self.base_speed = class_def.speed
    self.base_fire_rate = class_def.fire_rate
    self.base_damage = class_def.damage
    self.base_heat_per_shot = class_def.heat_per_shot
    self.cool_rate = class_def.cool_rate

    self.max_synapses = class_def.max_synapses

    -- Инвентарь и модификаторы
    self.items = {}        -- линейный список всех собранных предметов (для UI 4x4)
    self.mutations = {}    -- пассивные мутагены (для слотов мутаций 1x6)
    self.active_item = nil -- текущий активный протокол / способность
    self.active_cooldown = 0
    self.modifiers = {
        speed_mult = 1, fire_rate_mult = 1, damage_mult = 1,
        heat_mult = 1, crit_chance = 0, crit_mult = 1,
        lifesteal = 0, shield_cooldown = 0, shield_timer = 0,
        explode_chance = 0, explode_damage = 0, elite_heal = 0,
    }
    self:apply_modifiers()

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

    -- Уведомление о подобранном предмете
    self.pickup_notice = nil   -- {def, timer}

    -- Статистика забега
    self.stats = {kills = 0, time = 0, items = 0, integrations = 0}

    self.assets = assets
    self.sprites = assets.sprites.player[class_def.id]
    return self
end

function M:apply_modifiers()
    local m = self.modifiers
    -- Сброс к базе, затем перемножение всех пассивных модов
    m.speed_mult = 1; m.fire_rate_mult = 1; m.damage_mult = 1
    m.heat_mult = 1; m.crit_chance = 0; m.crit_mult = 1
    m.lifesteal = 0; m.shield_cooldown = 0
    m.explode_chance = 0; m.explode_damage = 0; m.elite_heal = 0
    local function apply(def)
        local s = def.stat_modifiers or {}
        if s.speed_mult       then m.speed_mult = m.speed_mult * s.speed_mult end
        if s.fire_rate_mult   then m.fire_rate_mult = m.fire_rate_mult * s.fire_rate_mult end
        if s.damage_mult      then m.damage_mult = m.damage_mult * s.damage_mult end
        if s.heat_mult        then m.heat_mult = m.heat_mult * s.heat_mult end
        if s.crit_chance      then m.crit_chance = m.crit_chance + s.crit_chance end
        if s.crit_mult        then m.crit_mult = math.max(m.crit_mult, s.crit_mult) end
        if s.lifesteal        then m.lifesteal = m.lifesteal + s.lifesteal end
        if s.shield_cooldown  then m.shield_cooldown = s.shield_cooldown end
        if s.explode_chance   then m.explode_chance = math.max(m.explode_chance, s.explode_chance) end
        if s.explode_damage   then m.explode_damage = math.max(m.explode_damage, s.explode_damage) end
        if s.elite_heal       then m.elite_heal = m.elite_heal + s.elite_heal end
    end
    for _, def in ipairs(self.mutations) do apply(def) end
    -- Активный протокол тоже даёт пассивные эффекты (heat_mult и т.п.)
    if self.active_item then apply(self.active_item) end

    self.speed         = self.base_speed * m.speed_mult
    self.fire_rate     = self.base_fire_rate * m.fire_rate_mult
    self.damage        = self.base_damage * m.damage_mult
    self.heat_per_shot = self.base_heat_per_shot * m.heat_mult
end

-- Категоризовать предмет и применить эффект
function M:add_item(def)
    table.insert(self.items, def)
    self.stats.items = self.stats.items + 1
    self.pickup_notice = {def = def, timer = 3.0}
    local t = def.type
    if t == "passive" or t == "glitch" then
        table.insert(self.mutations, def)
        -- Сразу применить «мгновенные» эффекты:
        local s = def.stat_modifiers or {}
        if s.synapses then
            for _ = 1, s.synapses do self:heal_synapse() end
        end
    elseif t == "active" then
        self.active_item = def
        self.active_cooldown = 0
    end
    self:apply_modifiers()
end

-- Сбросить предмет (только не-мутагены)
function M:drop_item(idx)
    local def = self.items[idx]
    if not def then return nil end
    if def.type == "passive" or def.type == "glitch" then return nil end
    table.remove(self.items, idx)
    if self.active_item == def then
        self.active_item = nil
        self.active_cooldown = 0
    end
    self:apply_modifiers()
    return def
end

function M:get_aim_angle(target_x, target_y)
    return math.atan2(target_y - self.y, target_x - self.x)
end

function M:shoot(target_x, target_y, projectile_pool)
    if self.shoot_cooldown > 0 or self.overheated then return end
    local ang = self:get_aim_angle(target_x, target_y)
    local speed = 160
    -- Крит
    local dmg = self.damage
    if self.modifiers.crit_chance > 0 and love.math.random() < self.modifiers.crit_chance then
        dmg = dmg * self.modifiers.crit_mult
    end
    -- Активный протокол с разбросом
    local s = self.active_item and self.active_item.stat_modifiers or {}
    local shots = s.spread_shots or 1
    for i = 1, shots do
        local a = ang
        if shots > 1 then
            a = ang + (i - (shots + 1) / 2) * 0.18
        end
        projectile.spawn(projectile_pool, {
            x = self.x, y = self.y,
            vx = math.cos(a) * speed, vy = math.sin(a) * speed,
            damage = dmg, team = "player",
            life = 1.0, image = self.assets.sprites.particles.bullet,
            color = self.class.color_secondary,
        })
    end
    self.shoot_cooldown = 1 / self.fire_rate
    self.heat = self.heat + self.heat_per_shot
    if self.heat >= 100 then
        self.heat = 100
        self.overheated = true
        self.overheat_timer = 2.0
    end
    -- Lifesteal
    if self.modifiers.lifesteal > 0 and self.hp < self.max_hp then
        self.hp = math.min(self.max_hp, self.hp + self.modifiers.lifesteal * 0.05)
    end
end

function M:take_damage(amount)
    if self.invuln > 0 then return false end
    -- Рибосомный щит: блокирует 1 удар раз в N секунд
    if self.modifiers.shield_cooldown > 0 and self.modifiers.shield_timer <= 0 then
        self.modifiers.shield_timer = self.modifiers.shield_cooldown
        self.invuln = 0.6
        return false
    end
    self.hp = self.hp - amount
    self.invuln = 0.8
    return true
end

-- Использование активного предмета (ПКМ или Space)
function M:use_active(ctx)
    local def = self.active_item
    if not def then return false end
    if self.active_cooldown > 0 then return false end
    local s = def.stat_modifiers or {}
    local cd = s.active_cooldown or 6.0
    self.active_cooldown = cd
    if def.id == "acid_burst" then
        -- AOE: визуальный круг, наносит урон врагам в радиусе
        local r = s.aoe or 30
        if ctx and ctx.room then
            for _, e in ipairs(ctx.room.enemies) do
                if not e.dead and utils.dist(e.x, e.y, self.x, self.y) <= r then
                    e:take_damage(s.damage or 8)
                end
            end
        end
        if ctx and ctx.renderer then
            ctx.renderer:flash({0.4, 1, 0.3, 0.5}, 0.3)
        end
        if ctx and ctx.audio then ctx.audio:play_sfx("explosion") end
    else
        -- Базовый эффект: «выстрел» одним мощным снарядом
        if ctx and ctx.projectile_pool then
            local mx, my = self.x + 50 * self.facing, self.y
            if ctx.input then
                local rmx, rmy = ctx.input:get_mouse_logical()
                if ctx.camera then rmx = rmx + ctx.camera.x; rmy = rmy + ctx.camera.y end
                mx, my = rmx, rmy
            end
            local ang = self:get_aim_angle(mx, my)
            projectile.spawn(ctx.projectile_pool, {
                x = self.x, y = self.y,
                vx = math.cos(ang) * 200, vy = math.sin(ang) * 200,
                damage = (s.damage or 12) * 2, team = "player",
                life = 1.2, image = self.assets.sprites.particles.bullet,
                color = def.color or self.class.color_secondary,
                radius = 4, pierce = true,
            })
        end
        if ctx and ctx.audio then ctx.audio:play_sfx("shoot", 0.6) end
    end
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
    if self.active_cooldown > 0 then self.active_cooldown = self.active_cooldown - dt end
    if self.modifiers.shield_timer > 0 then
        self.modifiers.shield_timer = self.modifiers.shield_timer - dt
    end
    if self.pickup_notice then
        self.pickup_notice.timer = self.pickup_notice.timer - dt
        if self.pickup_notice.timer <= 0 then self.pickup_notice = nil end
    end

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
