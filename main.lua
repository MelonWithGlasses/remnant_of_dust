-- REMNANT OF DUST — точка входа.
-- Этапы 1-6 реализованы: генерация ассетов, меню, игрок/стрельба, враги,
-- процедурный этаж и переходы комнат с миникартой.

local AG = require("asset_generator")
local engine = require("core.engine")
local input = require("core.input")
local renderer = require("core.renderer")
local audio_manager = require("core.audio_manager")

-- Логическое разрешение (рисуем в Canvas, потом масштабируем на экран)
local LOGICAL_W, LOGICAL_H = 320, 180

-- Глобальные ресурсы и контекст. assets/state передаются модулям как параметры,
-- глобально храним только для отладки и общего доступа из сцен.
_G.RD = {
    logical_w = LOGICAL_W,
    logical_h = LOGICAL_H,
    debug = false,
    fps = 0,
}

local canvas
local scale = 1
local offset_x, offset_y = 0, 0

local function update_scale()
    local sw, sh = love.graphics.getDimensions()
    local sx = sw / LOGICAL_W
    local sy = sh / LOGICAL_H
    scale = math.floor(math.min(sx, sy))
    if scale < 1 then scale = 1 end
    offset_x = math.floor((sw - LOGICAL_W * scale) / 2)
    offset_y = math.floor((sh - LOGICAL_H * scale) / 2)
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.mouse.setVisible(false)
    math.randomseed(os.time())
    love.math.setRandomSeed(os.time())

    canvas = love.graphics.newCanvas(LOGICAL_W, LOGICAL_H)
    canvas:setFilter("nearest", "nearest")

    _G.RD.assets = AG.generate_all()
    _G.RD.audio = audio_manager.new(_G.RD.assets)
    _G.RD.renderer = renderer.new()
    _G.RD.input = input.new()

    engine.init(_G.RD)
    engine.push("menu")

    update_scale()
end

function love.resize() update_scale() end

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end
    _G.RD.fps = love.timer.getFPS()
    _G.RD.input:update(dt, scale, offset_x, offset_y)
    _G.RD.audio:update(dt)
    engine.update(dt)
end

function love.draw()
    -- Сцена рисует в логический canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    engine.draw()
    -- Курсор в логических координатах
    local cursor = _G.RD.assets.sprites.ui.cursor
    local mx, my = _G.RD.input:get_mouse_logical()
    love.graphics.draw(cursor, math.floor(mx) - 4, math.floor(my) - 4)
    love.graphics.setCanvas()

    -- Канвас на экран с масштабом nearest
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, offset_x, offset_y, 0, scale, scale)

    if _G.RD.debug then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print(string.format(
            "FPS: %d  scene: %s  scale: %d",
            _G.RD.fps, engine.current_name() or "-", scale), 4, 4)
    end
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f3" then _G.RD.debug = not _G.RD.debug end
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
        update_scale()
    end
    if key == "escape" and engine.current_name() == "menu" then
        love.event.quit()
        return
    end
    _G.RD.input:keypressed(key, scancode, isrepeat)
    engine.keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    _G.RD.input:keyreleased(key, scancode)
    engine.keyreleased(key, scancode)
end

function love.mousepressed(x, y, button)
    _G.RD.input:mousepressed(x, y, button)
    engine.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    _G.RD.input:mousereleased(x, y, button)
    engine.mousereleased(x, y, button)
end
