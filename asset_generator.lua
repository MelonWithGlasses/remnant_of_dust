-- Процедурная генерация ВСЕХ графических и звуковых ассетов.
-- На первом запуске создаёт ImageData/SoundData в памяти, при необходимости
-- сохраняет их в save-каталог LÖVE (/generated_assets/...). Повторный запуск
-- использует уже созданные файлы.
local utils = require("utils")

local AG = {}

-- Корневой каталог в save-директории LÖVE
local ASSET_DIR = "generated_assets"

-- =====================================================================
-- ГРАФИКА: примитивы рисования по ImageData
-- =====================================================================

-- Установить пиксель с защитой от выхода за границы
local function set_pixel(data, x, y, r, g, b, a)
    if x < 0 or y < 0 or x >= data:getWidth() or y >= data:getHeight() then return end
    data:setPixel(x, y, r, g, b, a or 1)
end

-- Заполненный круг
local function fill_circle(data, cx, cy, radius, r, g, b, a)
    local r2 = radius * radius
    for y = -radius, radius do
        for x = -radius, radius do
            if x * x + y * y <= r2 then
                set_pixel(data, cx + x, cy + y, r, g, b, a)
            end
        end
    end
end

-- Заполненный прямоугольник
local function fill_rect(data, x0, y0, w, h, r, g, b, a)
    for y = y0, y0 + h - 1 do
        for x = x0, x0 + w - 1 do
            set_pixel(data, x, y, r, g, b, a)
        end
    end
end

-- Контур круга (одна толщина)
local function stroke_circle(data, cx, cy, radius, r, g, b, a)
    local r2_out = radius * radius
    local r2_in = (radius - 1) * (radius - 1)
    for y = -radius, radius do
        for x = -radius, radius do
            local d = x * x + y * y
            if d <= r2_out and d >= r2_in then
                set_pixel(data, cx + x, cy + y, r, g, b, a)
            end
        end
    end
end

-- Линия (Bresenham)
local function draw_line(data, x0, y0, x1, y1, r, g, b, a)
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    while true do
        set_pixel(data, x0, y0, r, g, b, a)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy; x0 = x0 + sx end
        if e2 < dx then err = err + dx; y0 = y0 + sy end
    end
end

-- =====================================================================
-- ГЕНЕРАЦИЯ СПРАЙТОВ
-- =====================================================================

-- Создаёт новую ImageData нужного размера, прозрачную
local function new_image(w, h)
    return love.image.newImageData(w, h)
end

-- Базовый «биоморфный» силуэт для спрайта врага/игрока:
-- округлое тело + симметричный паттерн пикселей по color_secondary.
local function draw_biomorph(data, w, h, body_color, accent_color, pattern_seed)
    local cx = math.floor(w / 2)
    local cy = math.floor(h / 2) + 1
    local radius = math.floor(math.min(w, h) / 2) - 1
    fill_circle(data, cx, cy, radius, body_color[1], body_color[2], body_color[3], 1)

    -- Внутренние акценты — симметричные пятна
    love.math.setRandomSeed(pattern_seed)
    local n_dots = 3 + love.math.random(0, 3)
    for i = 1, n_dots do
        local dx = love.math.random(0, radius - 1)
        local dy = love.math.random(-radius + 1, radius - 1)
        fill_circle(data, cx + dx, cy + dy, 1, accent_color[1], accent_color[2], accent_color[3], 1)
        fill_circle(data, cx - dx, cy + dy, 1, accent_color[1], accent_color[2], accent_color[3], 1)
    end

    -- Тёмная окантовка снизу для объёма
    for x = -radius, radius do
        local dy = math.floor(math.sqrt(math.max(0, radius * radius - x * x)))
        set_pixel(data, cx + x, cy + dy,
            body_color[1] * 0.5, body_color[2] * 0.5, body_color[3] * 0.5, 1)
    end

    -- Глаза (для всех существ — узнаваемая черта)
    local eye_y = cy - math.floor(radius / 2)
    local eye_offset = math.max(1, math.floor(radius / 3))
    set_pixel(data, cx - eye_offset, eye_y, 1, 1, 1, 1)
    set_pixel(data, cx + eye_offset, eye_y, 1, 1, 1, 1)
end

-- Игрок: 4 класса × кадры (idle/run/hurt/death/shoot)
function AG.gen_player_sprites(player_classes)
    local sprites = {}
    for class_id, class_def in pairs(player_classes) do
        sprites[class_id] = {}
        for _, anim in ipairs({"idle", "run", "hurt", "death", "shoot"}) do
            sprites[class_id][anim] = {}
        end

        local body = class_def.color_primary
        local accent = class_def.color_secondary
        local seed = class_def.sprite_seed or 1

        -- idle: 2 кадра (лёгкое дыхание — сдвиг по Y на 1 пиксель)
        for f = 1, 2 do
            local img = new_image(16, 16)
            local offset = (f == 2) and 1 or 0
            draw_biomorph(img, 16, 16 - offset, body, accent, seed + f)
            sprites[class_id].idle[f] = love.graphics.newImage(img)
            sprites[class_id].idle[f]:setFilter("nearest", "nearest")
        end

        -- run: 4 кадра (наклон + ноги)
        for f = 1, 4 do
            local img = new_image(16, 16)
            draw_biomorph(img, 16, 16, body, accent, seed + 10 + f)
            -- псевдо-ноги
            local leg_offset = (f % 2 == 0) and 1 or -1
            set_pixel(img, 7 + leg_offset, 14, accent[1], accent[2], accent[3], 1)
            set_pixel(img, 8 - leg_offset, 14, accent[1], accent[2], accent[3], 1)
            sprites[class_id].run[f] = love.graphics.newImage(img)
            sprites[class_id].run[f]:setFilter("nearest", "nearest")
        end

        -- hurt: 1 кадр (красно-белый)
        do
            local img = new_image(16, 16)
            draw_biomorph(img, 16, 16, {1, 0.4, 0.4}, {1, 1, 1}, seed + 99)
            sprites[class_id].hurt[1] = love.graphics.newImage(img)
            sprites[class_id].hurt[1]:setFilter("nearest", "nearest")
        end

        -- death: 4 кадра распадения
        for f = 1, 4 do
            local img = new_image(16, 16)
            local radius = math.max(1, 6 - f)
            fill_circle(img, 8, 8, radius,
                body[1] * (1 - f * 0.2), body[2] * (1 - f * 0.2), body[3] * (1 - f * 0.2), 1)
            sprites[class_id].death[f] = love.graphics.newImage(img)
            sprites[class_id].death[f]:setFilter("nearest", "nearest")
        end

        -- shoot: 2 кадра (вспышка у дула)
        for f = 1, 2 do
            local img = new_image(16, 16)
            draw_biomorph(img, 16, 16, body, accent, seed + f)
            if f == 1 then
                fill_circle(img, 13, 8, 2, 1, 0.9, 0.5, 1)
            end
            sprites[class_id].shoot[f] = love.graphics.newImage(img)
            sprites[class_id].shoot[f]:setFilter("nearest", "nearest")
        end
    end
    return sprites
end

-- Враги по data/enemies.lua
function AG.gen_enemy_sprites(enemies_data)
    local sprites = {}
    for _, enemy in ipairs(enemies_data) do
        local size = enemy.size or 16
        local img = new_image(size, size)
        draw_biomorph(img, size, size,
            enemy.color_primary, enemy.color_secondary,
            enemy.sprite_seed or 0)

        -- Дополнительные признаки по AI-типу
        if enemy.ai_type == "shooter" then
            -- «дуло» по бокам
            fill_rect(img, size - 2, math.floor(size / 2), 2, 1,
                enemy.color_secondary[1], enemy.color_secondary[2], enemy.color_secondary[3], 1)
        elseif enemy.ai_type == "tank" then
            -- толстая окантовка
            stroke_circle(img, math.floor(size / 2), math.floor(size / 2),
                math.floor(size / 2) - 1, 0.3, 0.3, 0.3, 1)
        elseif enemy.ai_type == "dasher" then
            -- шипы спереди
            for i = -2, 2 do
                set_pixel(img, size - 1, math.floor(size / 2) + i,
                    enemy.color_secondary[1], enemy.color_secondary[2], enemy.color_secondary[3], 1)
            end
        elseif enemy.ai_type == "spawner" then
            -- кольцо вокруг
            stroke_circle(img, math.floor(size / 2), math.floor(size / 2),
                math.floor(size / 2),
                enemy.color_secondary[1], enemy.color_secondary[2], enemy.color_secondary[3], 1)
        end

        sprites[enemy.id] = love.graphics.newImage(img)
        sprites[enemy.id]:setFilter("nearest", "nearest")
    end
    return sprites
end

-- Тайлы для биомов
function AG.gen_tile_sprites(biomes_data)
    local sprites = {}
    for _, biome in ipairs(biomes_data) do
        sprites[biome.id] = {}
        local palette = biome.palette
        local seed = biome.tile_seed or 0

        -- floor: основной цвет с лёгким шумом
        do
            local img = new_image(16, 16)
            love.math.setRandomSeed(seed)
            for y = 0, 15 do
                for x = 0, 15 do
                    local jitter = love.math.random() * 0.15 - 0.075
                    local c = palette.floor
                    set_pixel(img, x, y,
                        utils.clamp(c[1] + jitter, 0, 1),
                        utils.clamp(c[2] + jitter, 0, 1),
                        utils.clamp(c[3] + jitter, 0, 1), 1)
                end
            end
            sprites[biome.id].floor = love.graphics.newImage(img)
            sprites[biome.id].floor:setFilter("nearest", "nearest")
        end

        -- wall: тёмный цвет с органичным паттерном
        do
            local img = new_image(16, 16)
            love.math.setRandomSeed(seed + 1)
            for y = 0, 15 do
                for x = 0, 15 do
                    local jitter = love.math.random() * 0.2 - 0.1
                    local c = palette.wall
                    set_pixel(img, x, y,
                        utils.clamp(c[1] + jitter, 0, 1),
                        utils.clamp(c[2] + jitter, 0, 1),
                        utils.clamp(c[3] + jitter, 0, 1), 1)
                end
            end
            -- «жилы» по диагоналям
            for i = 0, 15 do
                if i % 3 == 0 then
                    local c = palette.accent
                    set_pixel(img, i, (i + 4) % 16, c[1], c[2], c[3], 1)
                end
            end
            sprites[biome.id].wall = love.graphics.newImage(img)
            sprites[biome.id].wall:setFilter("nearest", "nearest")
        end

        -- door (закрытая)
        do
            local img = new_image(16, 16)
            fill_rect(img, 0, 0, 16, 16, palette.wall[1], palette.wall[2], palette.wall[3], 1)
            fill_rect(img, 4, 4, 8, 8, palette.accent[1], palette.accent[2], palette.accent[3], 1)
            stroke_circle(img, 8, 8, 4, palette.floor[1], palette.floor[2], palette.floor[3], 1)
            sprites[biome.id].door = love.graphics.newImage(img)
            sprites[biome.id].door:setFilter("nearest", "nearest")
        end
    end
    return sprites
end

-- Предметы (по items_data; рисуем иконку 16×16 по типу/редкости)
function AG.gen_item_sprites(items_data)
    local sprites = {}
    for _, item in ipairs(items_data) do
        local img = new_image(16, 16)
        local color = item.color or {1, 1, 1}
        local rarity_ring = {
            common = {0.4, 1, 0.4},
            rare = {0.4, 0.6, 1},
            epic = {0.8, 0.4, 1},
            legendary = {1, 0.85, 0.3},
        }
        local ring = rarity_ring[item.rarity] or rarity_ring.common

        stroke_circle(img, 8, 8, 7, ring[1], ring[2], ring[3], 1)
        fill_circle(img, 8, 8, 5, color[1], color[2], color[3], 1)

        -- Символ по типу
        if item.type == "passive" then
            -- спираль
            for i = 0, 6 do
                local ang = i * 0.6
                local r = i * 0.5
                local x = math.floor(8 + math.cos(ang) * r)
                local y = math.floor(8 + math.sin(ang) * r)
                set_pixel(img, x, y, 1, 1, 1, 1)
            end
        elseif item.type == "active" then
            -- молния
            draw_line(img, 6, 4, 10, 8, 1, 1, 0.4, 1)
            draw_line(img, 10, 8, 6, 12, 1, 1, 0.4, 1)
        elseif item.type == "glitch" then
            -- крест-глюк
            draw_line(img, 5, 5, 11, 11, 1, 0.3, 1, 1)
            draw_line(img, 11, 5, 5, 11, 1, 0.3, 1, 1)
        elseif item.type == "consumable" then
            -- сердце
            fill_circle(img, 6, 7, 2, 1, 0.3, 0.3, 1)
            fill_circle(img, 10, 7, 2, 1, 0.3, 0.3, 1)
            fill_rect(img, 6, 8, 5, 3, 1, 0.3, 0.3, 1)
        else
            -- круг по умолчанию
            fill_circle(img, 8, 8, 2, 1, 1, 1, 1)
        end

        sprites[item.id] = love.graphics.newImage(img)
        sprites[item.id]:setFilter("nearest", "nearest")
    end
    return sprites
end

-- Частицы (8×8)
function AG.gen_particle_sprites()
    local sprites = {}
    local function make(name, draw_fn)
        local img = new_image(8, 8)
        draw_fn(img)
        sprites[name] = love.graphics.newImage(img)
        sprites[name]:setFilter("nearest", "nearest")
    end

    make("dot", function(img) fill_circle(img, 4, 4, 2, 1, 1, 1, 1) end)
    make("spark", function(img)
        draw_line(img, 4, 1, 4, 6, 1, 1, 0.5, 1)
        draw_line(img, 1, 4, 6, 4, 1, 1, 0.5, 1)
    end)
    make("blood", function(img)
        fill_circle(img, 4, 4, 3, 0.7, 0.1, 0.1, 1)
    end)
    make("glitch", function(img)
        for y = 0, 7 do
            for x = 0, 7 do
                if love.math.random() < 0.5 then
                    set_pixel(img, x, y, love.math.random(), love.math.random(), love.math.random(), 1)
                end
            end
        end
    end)
    make("smoke", function(img) fill_circle(img, 4, 4, 3, 0.6, 0.6, 0.6, 0.8) end)
    make("bullet", function(img)
        fill_circle(img, 4, 4, 2, 1, 1, 0.6, 1)
        fill_circle(img, 4, 4, 1, 1, 1, 1, 1)
    end)
    make("acid", function(img)
        fill_circle(img, 4, 4, 3, 0.4, 0.9, 0.2, 1)
    end)
    make("frag", function(img)
        fill_rect(img, 3, 2, 2, 4, 0.5, 1, 1, 1)
        fill_rect(img, 2, 3, 4, 2, 0.5, 1, 1, 1)
    end)

    return sprites
end

-- UI элементы (курсор, иконки в HUD)
function AG.gen_ui_sprites()
    local sprites = {}
    -- Курсор: перекрестие 9×9
    do
        local img = new_image(9, 9)
        draw_line(img, 4, 0, 4, 3, 1, 1, 1, 1)
        draw_line(img, 4, 5, 4, 8, 1, 1, 1, 1)
        draw_line(img, 0, 4, 3, 4, 1, 1, 1, 1)
        draw_line(img, 5, 4, 8, 4, 1, 1, 1, 1)
        set_pixel(img, 4, 4, 1, 0.3, 0.3, 1)
        sprites.cursor = love.graphics.newImage(img)
        sprites.cursor:setFilter("nearest", "nearest")
    end
    -- Узел синапса (HUD): целый и пустой
    do
        local img = new_image(8, 8)
        fill_circle(img, 4, 4, 3, 0.4, 0.9, 1, 1)
        fill_circle(img, 4, 4, 1, 1, 1, 1, 1)
        sprites.synapse_full = love.graphics.newImage(img)
        sprites.synapse_full:setFilter("nearest", "nearest")
    end
    do
        local img = new_image(8, 8)
        stroke_circle(img, 4, 4, 3, 0.3, 0.3, 0.4, 1)
        sprites.synapse_empty = love.graphics.newImage(img)
        sprites.synapse_empty:setFilter("nearest", "nearest")
    end
    return sprites
end

-- Фон главного меню (320×180, плавающие «клетки»)
function AG.gen_menu_background()
    local img = new_image(320, 180)
    love.math.setRandomSeed(424242)
    -- градиент тёмно-фиолетовый -> чёрный
    for y = 0, 179 do
        local t = y / 179
        for x = 0, 319 do
            local r = 0.05 + (1 - t) * 0.15
            local g = 0.02
            local b = 0.08 + (1 - t) * 0.2
            set_pixel(img, x, y, r, g, b, 1)
        end
    end
    -- плавающие «клетки»
    for _ = 1, 40 do
        local cx = love.math.random(0, 319)
        local cy = love.math.random(0, 179)
        local radius = love.math.random(3, 8)
        local hue = 0.7 + love.math.random() * 0.2
        local r, g, b = utils.hsv_to_rgb(hue, 0.6, 0.4)
        stroke_circle(img, cx, cy, radius, r, g, b, 1)
    end
    local image = love.graphics.newImage(img)
    image:setFilter("nearest", "nearest")
    return image
end

-- =====================================================================
-- АУДИО: процедурные тоны и шум
-- =====================================================================

local SAMPLE_RATE = 22050

-- Создаёт SoundData нужной длительности и заполняет её через fn(t, i) -> [-1, 1]
local function make_sound(duration, fn)
    local samples = math.floor(duration * SAMPLE_RATE)
    local data = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
    for i = 0, samples - 1 do
        local t = i / SAMPLE_RATE
        local v = fn(t, i)
        if v > 1 then v = 1 elseif v < -1 then v = -1 end
        data:setSample(i, v)
    end
    return data
end

-- Огибающая ADSR (упрощённая: attack/decay/sustain/release)
local function envelope(t, dur, a, d, s, r)
    if t < a then return t / a end
    if t < a + d then return 1 - (1 - s) * (t - a) / d end
    if t < dur - r then return s end
    if t < dur then return s * (1 - (t - (dur - r)) / r) end
    return 0
end

-- Стандартные осцилляторы
local function osc_sine(t, f) return math.sin(2 * math.pi * f * t) end
local function osc_square(t, f) return (math.sin(2 * math.pi * f * t) >= 0) and 1 or -1 end
local function osc_saw(t, f) return 2 * (f * t - math.floor(0.5 + f * t)) end
local function osc_noise() return love.math.random() * 2 - 1 end

-- SFX генераторы (возвращают SoundData)
local function sfx_shoot()
    return make_sound(0.12, function(t)
        local env = envelope(t, 0.12, 0.005, 0.04, 0.2, 0.06)
        local f = 880 - t * 2000
        return 0.4 * env * (osc_square(t, f) * 0.6 + osc_noise() * 0.4)
    end)
end

local function sfx_hit()
    return make_sound(0.08, function(t)
        local env = envelope(t, 0.08, 0.001, 0.03, 0.0, 0.04)
        return 0.5 * env * osc_noise()
    end)
end

local function sfx_pickup()
    return make_sound(0.18, function(t)
        local env = envelope(t, 0.18, 0.01, 0.05, 0.6, 0.1)
        local f = 600 + t * 1600
        return 0.4 * env * osc_sine(t, f)
    end)
end

local function sfx_explosion()
    return make_sound(0.45, function(t)
        local env = envelope(t, 0.45, 0.005, 0.15, 0.3, 0.25)
        local low = osc_sine(t, 80) * 0.3
        return 0.6 * env * (osc_noise() * 0.7 + low)
    end)
end

local function sfx_door()
    return make_sound(0.35, function(t)
        local env = envelope(t, 0.35, 0.02, 0.1, 0.4, 0.18)
        local f = 120 + t * 60
        return 0.35 * env * (osc_sine(t, f) + osc_noise() * 0.2)
    end)
end

local function sfx_hurt()
    return make_sound(0.25, function(t)
        local env = envelope(t, 0.25, 0.005, 0.05, 0.2, 0.18)
        -- глитч: пропуски сэмплов
        if love.math.random() < 0.15 then return 0 end
        local f = 200 + osc_noise() * 80
        return 0.5 * env * osc_square(t, f)
    end)
end

local function sfx_overheat()
    return make_sound(0.4, function(t)
        local env = envelope(t, 0.4, 0.01, 0.1, 0.4, 0.25)
        return 0.4 * env * (osc_noise() * 0.6 + osc_sine(t, 150 + t * 80) * 0.4)
    end)
end

local function sfx_click()
    return make_sound(0.05, function(t)
        local env = envelope(t, 0.05, 0.001, 0.02, 0.0, 0.03)
        return 0.3 * env * osc_square(t, 1200)
    end)
end

function AG.gen_sfx()
    local sfx = {}
    local defs = {
        shoot = sfx_shoot,
        hit = sfx_hit,
        pickup = sfx_pickup,
        explosion = sfx_explosion,
        door = sfx_door,
        hurt = sfx_hurt,
        overheat = sfx_overheat,
        click = sfx_click,
    }
    for name, fn in pairs(defs) do
        local data = fn()
        sfx[name] = love.audio.newSource(data, "static")
    end
    return sfx
end

-- Музыкальные треки: ambient drone + arpeggio.
-- duration_sec — длина лупа; bpm и note_table задают арпеджио.
local function make_music(duration_sec, bpm, root_freq, scale, with_drums)
    local samples_total = math.floor(duration_sec * SAMPLE_RATE)
    local data = love.sound.newSoundData(samples_total, SAMPLE_RATE, 16, 1)
    local beat_dur = 60 / bpm
    local step_dur = beat_dur / 2 -- восьмые

    for i = 0, samples_total - 1 do
        local t = i / SAMPLE_RATE
        -- drone: две низкие синусоиды
        local drone = osc_sine(t, root_freq * 0.5) * 0.18
                    + osc_sine(t, root_freq * 0.5 + 1.5) * 0.12
        -- arpeggio: цикл по scale
        local step = math.floor(t / step_dur)
        local note = scale[(step % #scale) + 1]
        local note_freq = root_freq * (2 ^ (note / 12))
        local local_t = t - step * step_dur
        local env = envelope(local_t, step_dur, 0.005, 0.05, 0.4, step_dur * 0.4)
        local arp = osc_square(t, note_freq) * env * 0.12

        local drums = 0
        if with_drums then
            local beat_t = t % beat_dur
            if beat_t < 0.05 then
                drums = osc_noise() * (1 - beat_t / 0.05) * 0.25
            end
        end

        local v = drone + arp + drums
        if v > 0.9 then v = 0.9 elseif v < -0.9 then v = -0.9 end
        data:setSample(i, v)
    end
    return data
end

function AG.gen_music()
    local music = {}
    -- Меню: медленный drone, 60 BPM, минорная гамма
    local menu_data = make_music(8, 60, 110, {0, 3, 7, 10}, false)
    music.menu = love.audio.newSource(menu_data, "static")
    music.menu:setLooping(true)

    -- Геймплей (стандарт): 90 BPM
    local game_data = make_music(8, 90, 130, {0, 3, 5, 7, 10}, false)
    music.game = love.audio.newSource(game_data, "static")
    music.game:setLooping(true)

    -- Бой: +20 BPM, ударные
    local battle_data = make_music(6, 110, 140, {0, 3, 5, 7, 10, 12}, true)
    music.battle = love.audio.newSource(battle_data, "static")
    music.battle:setLooping(true)

    -- Босс: агрессивные арпеджио
    local boss_data = make_music(8, 130, 87, {0, 1, 5, 7, 8, 11}, true)
    music.boss = love.audio.newSource(boss_data, "static")
    music.boss:setLooping(true)

    -- Смерть: низкочастотный спад (не луп)
    local death_data = make_sound(3.0, function(t)
        local env = envelope(t, 3.0, 0.1, 0.5, 0.4, 1.5)
        local f = 220 * math.exp(-t * 0.5)
        return 0.4 * env * (osc_sine(t, f) + osc_sine(t, f * 0.5) * 0.5)
    end)
    music.death = love.audio.newSource(death_data, "static")
    music.death:setLooping(false)

    return music
end

-- =====================================================================
-- ТОЧКА ВХОДА
-- =====================================================================

-- Полная генерация всех ассетов. Возвращает таблицу assets для глобального доступа.
function AG.generate_all()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.filesystem.createDirectory(ASSET_DIR)

    local player_classes = require("data.player_classes")
    local enemies_data = require("data.enemies")
    local items_data = require("data.items")
    local biomes_data = require("data.biomes")

    local assets = {}
    assets.sprites = {}
    assets.sprites.player = AG.gen_player_sprites(player_classes)
    assets.sprites.enemies = AG.gen_enemy_sprites(enemies_data)
    assets.sprites.items = AG.gen_item_sprites(items_data)
    assets.sprites.tiles = AG.gen_tile_sprites(biomes_data)
    assets.sprites.particles = AG.gen_particle_sprites()
    assets.sprites.ui = AG.gen_ui_sprites()
    assets.sprites.menu_bg = AG.gen_menu_background()

    assets.sfx = AG.gen_sfx()
    assets.music = AG.gen_music()

    -- Системный шрифт для UI (растягивается nearest для пиксельного стиля)
    assets.font_small = love.graphics.newFont(8)
    assets.font_small:setFilter("nearest", "nearest")
    assets.font_medium = love.graphics.newFont(12)
    assets.font_medium:setFilter("nearest", "nearest")
    assets.font_large = love.graphics.newFont(24)
    assets.font_large:setFilter("nearest", "nearest")

    return assets
end

return AG
