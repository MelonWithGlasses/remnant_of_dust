-- Основная сцена геймплея: загружает этаж, управляет комнатами, врагами, пикапами.
local utils = require("utils")
local camera_mod = require("core.camera")
local player_mod = require("gameplay.player")
local enemy_mod = require("gameplay.enemy")
local room_mod = require("gameplay.room")
local projectile_mod = require("gameplay.projectile")
local pickup_mod = require("gameplay.pickup")
local item_mod = require("gameplay.item")
local floor_gen = require("gameplay.floor_generator")
local hud_mod = require("ui.hud")
local inventory_ui_mod = require("ui.inventory_ui")

local M = {}
M.__index = M

local PLAYER_CLASSES = require("data.player_classes")
local ENEMIES_DATA = require("data.enemies")
local ITEMS_DATA = require("data.items")
local BIOMES_DATA = require("data.biomes")

-- Быстрый доступ к данным по id
local enemies_by_id = {}
for _, e in ipairs(ENEMIES_DATA) do enemies_by_id[e.id] = e end
local items_by_id = {}
for _, i in ipairs(ITEMS_DATA) do items_by_id[i.id] = i end

function M.new() return setmetatable({}, M) end

function M:enter(ctx, params)
    self.ctx = ctx
    self.assets = ctx.assets

    self.class = PLAYER_CLASSES[params and params.class_id or "strand"]
        or PLAYER_CLASSES.strand

    self.biome_index = 1
    self.biome = BIOMES_DATA[self.biome_index]
    self.floor = floor_gen.generate()
    self.rooms = {}   -- кэш Room по node.id
    self.current_room_id = self.floor.start_id
    self.visited_rooms = {[self.floor.start_id] = true}
    ctx.visited_rooms = self.visited_rooms

    self.camera = camera_mod.new(ctx.logical_w, ctx.logical_h)
    self.projectile_pool = projectile_mod.new_pool()

    -- Создать стартовую комнату и поставить игрока в центр
    local start_room = self:get_or_create_room(self.current_room_id)
    self.current_room = start_room
    local cx, cy = start_room:get_center()
    self.player = player_mod.new(self.class, cx, cy, self.assets)
    start_room.camera = self.camera

    self.hud = hud_mod.new(ctx)
    self.inventory_ui = inventory_ui_mod.new(ctx)
    self.show_inventory = false
    self.combo = 0
    self.combo_timer = 0

    ctx.audio:play_music("game")
    self:enter_room(start_room)
end

function M:exit()
    self.ctx.visited_rooms = nil
end

function M:get_or_create_room(node_id)
    if self.rooms[node_id] then return self.rooms[node_id] end
    local node = self.floor.nodes[node_id]
    local room = room_mod.new(node, self.biome, self.assets)
    self.rooms[node_id] = room
    return room
end

function M:enter_room(room)
    self.current_room = room
    room.camera = self.camera
    self.visited_rooms[room.id] = true

    -- Спавн врагов, если ещё не спавнили и комната не «start»
    if not room.enemies_spawned and room.type ~= "start" then
        local enemy_count
        if room.type == "elite" then
            enemy_count = love.math.random(3, 5)
        elseif room.type == "boss" then
            enemy_count = 1   -- заглушка: один «жирный» враг как промежуточный босс
        elseif room.type == "shop" or room.type == "altar" then
            enemy_count = 0
        else
            enemy_count = love.math.random(2, 4)
        end
        local pool = self.biome.enemies
        for _ = 1, enemy_count do
            local id = pool[love.math.random(1, #pool)]
            if room.type == "boss" then id = "elite_tank" end
            if room.type == "elite" then
                local elites = {"elite_tank", "heavy_spitter", "elite_spawner"}
                id = elites[love.math.random(1, #elites)]
            end
            local margin = 24
            local ex = room.x + margin + love.math.random() * (room.w - margin * 2)
            local ey = room.y + margin + love.math.random() * (room.h - margin * 2)
            self:spawn_enemy(id, ex, ey)
        end
        room.enemies_spawned = true
    end

    -- Спавн предметов в особых комнатах (один раз)
    if not room.items_spawned then
        room.items = room.items or {}
        if room.type == "shop" then
            -- 3 предмета на постаментах, требуют ДНК
            local choices = self:pick_items({"axon", "dendrite", "ribosome_shield", "axon_accel", "myelin_layer", "glycine"}, 3)
            for i, def in ipairs(choices) do
                local price = (def.rarity == "rare" and 3) or (def.rarity == "epic" and 5) or 2
                local rx = room.x + room.w * (0.25 + (i - 1) * 0.25)
                local ry = room.y + room.h * 0.45
                table.insert(room.items, item_mod.new(def, rx, ry, self.assets, price))
            end
        elseif room.type == "altar" then
            -- 1 редкий/эпический предмет бесплатно (на алтаре)
            local choices = self:pick_items({"viral_vector", "mito_drain", "vampiric", "quantum_rift", "biomass"}, 1)
            for _, def in ipairs(choices) do
                table.insert(room.items, item_mod.new(def, room.x + room.w / 2, room.y + room.h / 2, self.assets, 0))
            end
        end
        room.items_spawned = true
    end

    if #room.enemies > 0 then
        room:lock_doors()
        self.ctx.audio:play_music("battle")
    else
        room.cleared = true
        room.doors_locked = false
        self.ctx.audio:play_music("game")
    end

    -- Камера: ограничить камерой комнаты
    self.camera:set_bounds(room.x, room.y, room.w, room.h)
    self.camera:set_target(self.player.x, self.player.y)
    -- Мгновенный snap при первом входе
    self.camera.x = self.player.x - self.ctx.logical_w / 2
    self.camera.y = self.player.y - self.ctx.logical_h / 2
end

function M:spawn_enemy(id, x, y)
    local def = enemies_by_id[id]
    if not def then return nil end
    local e = enemy_mod.new(def, x, y, self.assets)
    table.insert(self.current_room.enemies, e)
    return e
end

-- Выбрать N случайных уникальных предметов по списку id
function M:pick_items(ids, n)
    local pool = {}
    for _, id in ipairs(ids) do
        if items_by_id[id] then table.insert(pool, items_by_id[id]) end
    end
    -- Перемешать (Fisher–Yates)
    for i = #pool, 2, -1 do
        local j = love.math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local out = {}
    for i = 1, math.min(n, #pool) do out[i] = pool[i] end
    return out
end

-- Подбор пол-предмета (item), вызывается по E или при покупке.
-- Возвращает true, если предмет был добавлен.
function M:try_pickup_item(item)
    if not item or item.collected then return false end
    local def = item:try_pickup(self.player)
    if not def then return false end
    self.player:add_item(def)
    self.ctx.audio:play_sfx("pickup", 1.2)
    self.ctx.renderer:flash({1, 1, 1, 0.25}, 0.15)
    return true
end

-- ===== Подбор предмета (вызывается из update) =====
function M:on_pickup(def)
    self.player.stats.items = self.player.stats.items + 1
    self.ctx.audio:play_sfx("pickup")
    if def.id == "glial_cell" then
        self.player.glial_count = self.player.glial_count + 1
        if self.player.glial_count >= 3 then
            self.player.glial_count = 0
            self.player:heal_synapse()
            self.ctx.renderer:flash({0.4, 1, 0.6, 0.4}, 0.2)
        end
    elseif def.id == "dna_fragment" then
        self.player.dna_count = self.player.dna_count + 1
    elseif def.id == "memory_fragment" then
        self.player.codex_count = self.player.codex_count + 1
    end
end

function M:on_enemy_killed(e)
    self.player.stats.kills = self.player.stats.kills + 1
    self.combo = self.combo + 1
    self.combo_timer = 4.0
    self.ctx.renderer:burst(self.assets.sprites.particles.blood,
        e.x, e.y, 8, 60, 0.4, {0.8, 0.2, 0.2})
    self.ctx.audio:play_sfx("explosion", 1.5 + love.math.random() * 0.4, 0.3)
    -- Шанс дропа
    if love.math.random() < (e.def.drop_chance or 0) then
        -- 60% глиальная, 30% DNA, 10% memory
        local r = love.math.random()
        local drop_id
        if r < 0.6 then drop_id = "glial_cell"
        elseif r < 0.9 then drop_id = "dna_fragment"
        else drop_id = "memory_fragment" end
        local def = items_by_id[drop_id]
        if def then
            self.current_room.pickups = self.current_room.pickups or {}
            table.insert(self.current_room.pickups, pickup_mod.new(def, e.x, e.y, self.assets))
        end
    end
end

function M:update(dt)
    local ctx = self.ctx
    local room = self.current_room
    local player = self.player

    -- Инвентарь: всё остальное замораживается (только эффекты на фоне)
    if self.show_inventory then
        self.inventory_ui:update(dt, player)
        self.ctx.renderer:update(dt)
        return
    end

    -- Игрок
    player:update(dt, ctx.input, self.projectile_pool, room)

    -- Враги
    local enemy_ctx = {
        player = player,
        room = room,
        projectile_pool = self.projectile_pool,
        assets = self.assets,
        spawn_enemy = function(id, x, y) return self:spawn_enemy(id, x, y) end,
    }
    for _, e in ipairs(room.enemies) do
        e:update(dt, enemy_ctx)
    end

    -- Снаряды
    projectile_mod.update(self.projectile_pool, dt, room)

    -- Столкновения снарядов с врагами и игроком
    for p in projectile_mod.iter(self.projectile_pool) do
        if p.team == "player" then
            for _, e in ipairs(room.enemies) do
                if not e.dead and utils.dist_sq(p.x, p.y, e.x, e.y) < (e.w * 0.6) ^ 2 then
                    e:take_damage(p.damage)
                    if not p.pierce then p.alive = false end
                    if e.dead then self:on_enemy_killed(e) end
                    break
                end
            end
        else
            if utils.dist_sq(p.x, p.y, player.x, player.y) < 36 then
                if player:take_damage(p.damage) then
                    self.combo = 0
                    self.ctx.audio:play_sfx("hurt")
                    self.camera:shake(2, 0.15)
                end
                p.alive = false
            end
        end
    end

    -- Контактный урон врагов
    for _, e in ipairs(room.enemies) do
        if not e.dead and e.def.contact_only and
           utils.dist_sq(e.x, e.y, player.x, player.y) < ((e.w + player.w) * 0.45) ^ 2 then
            if player:take_damage(e.damage) then
                self.combo = 0
                self.ctx.audio:play_sfx("hurt")
                self.camera:shake(2, 0.15)
            end
        end
    end

    -- Удалить мёртвых врагов; обновить блокировку дверей
    for i = #room.enemies, 1, -1 do
        if room.enemies[i].dead then table.remove(room.enemies, i) end
    end
    if room.doors_locked and #room.enemies == 0 then
        room:on_enemies_cleared()
        self.ctx.audio:play_sfx("door", 0.6, 0.6)
        self.ctx.audio:play_music("game")
    end

    -- Пикапы
    if room.pickups then
        for i = #room.pickups, 1, -1 do
            local pu = room.pickups[i]
            local def = pu:update(dt, player)
            if pu.collected then
                if def then self:on_pickup(def) end
                table.remove(room.pickups, i)
            end
        end
    end

    -- Предметы на полу (item.lua)
    if room.items then
        local nearest, nearest_d = nil, 1e9
        for i = #room.items, 1, -1 do
            local it = room.items[i]
            it:update(dt, player)
            if it.collected then
                table.remove(room.items, i)
            else
                local d = utils.dist_sq(it.x, it.y, player.x, player.y)
                if d < 14 * 14 and d < nearest_d then
                    nearest, nearest_d = it, d
                end
            end
        end
        self.pickup_target = nearest
    else
        self.pickup_target = nil
    end

    -- Комбо таймер
    if self.combo_timer > 0 then
        self.combo_timer = self.combo_timer - dt
        if self.combo_timer <= 0 then self.combo = 0 end
    end

    -- Триггер перехода в соседнюю комнату
    if not room.doors_locked then
        local dir = room:check_door_trigger(player.x, player.y)
        if dir then
            local node = self.floor.nodes[self.current_room_id]
            local opp = {north="south", south="north", east="west", west="east"}
            local DIRS = {north={0,-1}, south={0,1}, east={1,0}, west={-1,0}}
            local d = DIRS[dir]
            local nb_node = self.floor.by_pos[(node.x + d[1]) * 1000 + (node.y + d[2])]
            if nb_node then
                self.current_room_id = nb_node.id
                local nb = self:get_or_create_room(nb_node.id)
                self:enter_room(nb)
                -- Поставить игрока у противоположной двери
                local ex_door, ey_door = nb:get_door_world_pos(opp[dir])
                self.player.x = ex_door + (-d[1]) * 16
                self.player.y = ey_door + (-d[2]) * 16
                self.ctx.audio:play_sfx("door")
            end
        end
    end

    -- Камера
    self.camera:set_target(player.x, player.y)
    self.camera:update(dt)

    -- Партиклы
    self.ctx.renderer:update(dt)

    -- Смерть
    if player:is_dead() then
        require("core.engine").replace("gameover", {
            class_id = self.class.id,
            stats = {
                time = player.stats.time,
                kills = player.stats.kills,
                items = player.stats.items,
                cause = "Враг",
            },
        })
    end
end

function M:keypressed(key)
    if key == "tab" then
        self.show_inventory = not self.show_inventory
        return
    end
    if self.show_inventory then
        if key == "escape" then
            self.show_inventory = false
        end
        return
    end
    if key == "e" then
        if self.pickup_target then
            self:try_pickup_item(self.pickup_target)
            self.pickup_target = nil
        end
        return
    end
    if key == "space" then
        self.player:use_active(self:build_active_ctx())
        return
    end
    if key == "escape" or key == "p" then
        require("core.engine").push("pause")
    end
end

function M:mousepressed(x, y, button)
    if self.show_inventory then
        local mx, my = self.ctx.input:get_mouse_logical()
        local def, dx, dy = self.inventory_ui:mousepressed(mx, my, button, self.player)
        if def then
            self.current_room.items = self.current_room.items or {}
            -- Спавним обратно как item-на-полу (без цены)
            table.insert(self.current_room.items, item_mod.new(def, dx, dy, self.assets, 0))
        end
        return
    end
    if button == 2 then
        -- ПКМ — активный протокол
        self.player:use_active(self:build_active_ctx())
    end
end

function M:build_active_ctx()
    return {
        room = self.current_room,
        projectile_pool = self.projectile_pool,
        renderer = self.ctx.renderer,
        audio = self.ctx.audio,
        input = self.ctx.input,
        camera = self.camera,
    }
end

function M:draw()
    local room = self.current_room
    -- Очистка фоном биома (вне комнаты)
    love.graphics.clear(room.biome.palette.wall[1] * 0.5,
        room.biome.palette.wall[2] * 0.5,
        room.biome.palette.wall[3] * 0.5, 1)

    self.camera:apply()
    room:draw()

    -- Пикапы
    if room.pickups then
        for _, pu in ipairs(room.pickups) do pu:draw() end
    end

    -- Предметы на полу
    if room.items then
        for _, it in ipairs(room.items) do it:draw() end
    end

    -- Враги
    for _, e in ipairs(room.enemies) do e:draw() end

    -- Снаряды
    projectile_mod.draw(self.projectile_pool)

    -- Игрок
    self.player:draw()

    -- «Нажмите E» над ближайшим предметом
    if self.pickup_target and not self.show_inventory then
        local it = self.pickup_target
        love.graphics.setColor(0.9, 0.95, 1, 0.85 + 0.15 * math.sin(love.timer.getTime() * 6))
        love.graphics.printf("E", it.x - 10, it.y - 18, 20, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Партиклы
    self.ctx.renderer:draw_particles()

    -- Отладка
    if _G.RD.debug then
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.rectangle("line", self.player.x - 6, self.player.y - 6, 12, 12)
        for _, e in ipairs(room.enemies) do
            love.graphics.rectangle("line", e.x - e.w / 2, e.y - e.h / 2, e.w, e.h)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    self.camera:reset()

    -- Полноэкранные эффекты
    self.ctx.renderer:draw_flashes(self.ctx.logical_w, self.ctx.logical_h)

    -- Цифровой шок при низком HP
    if self.player.hp <= 2 then
        if math.floor(love.timer.getTime() * 8) % 2 == 0 then
            love.graphics.setColor(1, 0.2, 0.2, 0.15)
            love.graphics.rectangle("fill", 0, 0, self.ctx.logical_w, self.ctx.logical_h)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- HUD
    self.hud:draw(self.player, self.floor, self.current_room_id, self.combo)

    -- Инвентарь (поверх HUD)
    if self.show_inventory then
        self.inventory_ui:draw(self.player)
    end
end

return M
