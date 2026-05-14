-- Сцена паузы (полупрозрачный оверлей).
local M = {}
M.__index = M

function M.new() return setmetatable({}, M) end

function M:enter(ctx, params)
    self.ctx = ctx
end

function M:exit() end

function M:update(dt) end

function M:keypressed(key)
    if key == "escape" or key == "p" then
        require("core.engine").pop()
    end
    if key == "q" then
        require("core.engine").replace("menu")
    end
end

function M:draw()
    -- Текущая сцена снизу не рисуется (ниже неё в стеке всё равно есть game,
    -- но engine рисует только верх). Рисуем затемнение и текст.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, 320, 180)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.ctx.assets.font_large)
    love.graphics.printf("ПАУЗА", 0, 60, 320, "center")
    love.graphics.setFont(self.ctx.assets.font_medium)
    love.graphics.printf("ESC — продолжить", 0, 100, 320, "center")
    love.graphics.printf("Q — выйти в меню", 0, 116, 320, "center")
end

return M
