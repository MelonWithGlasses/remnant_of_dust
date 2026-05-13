-- Экран смерти: статистика забега и кнопки.
local M = {}
M.__index = M

local function point_in_rect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function M.new() return setmetatable({}, M) end

function M:enter(ctx, params)
    self.ctx = ctx
    self.params = params or {}
    self.hover = 0
    self.buttons = {
        {label = "Попробовать снова", action = "retry"},
        {label = "Главное меню", action = "menu"},
    }
    self.ctx.audio:play_music("death")
end

function M:exit() end

function M:update(dt)
    local mx, my = self.ctx.input:get_mouse_logical()
    self.hover = 0
    for i = 1, #self.buttons do
        local y = 120 + (i - 1) * 18
        if point_in_rect(mx, my, 100, y, 120, 14) then self.hover = i end
    end
end

function M:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.hover == 0 then return end
    self.ctx.audio:play_sfx("click")
    local action = self.buttons[self.hover].action
    if action == "retry" then
        require("core.engine").replace("game", {class_id = self.params.class_id or "strand"})
    else
        require("core.engine").replace("menu")
    end
end

function M:keypressed(key)
    if key == "return" or key == "space" then
        self.ctx.audio:play_sfx("click")
        require("core.engine").replace("game", {class_id = self.params.class_id or "strand"})
    elseif key == "escape" then
        require("core.engine").replace("menu")
    end
end

function M:draw()
    love.graphics.clear(0.05, 0.0, 0.05, 1)
    -- Заголовок
    love.graphics.setFont(self.ctx.assets.font_large)
    love.graphics.setColor(1, 0.3, 0.3, 1)
    love.graphics.printf("ВЫ УМЕРЛИ", 0, 20, 320, "center")

    -- Статистика
    love.graphics.setFont(self.ctx.assets.font_medium)
    love.graphics.setColor(0.85, 0.85, 0.9, 1)
    local stats = self.params.stats or {}
    local t_sec = math.floor(stats.time or 0)
    local lines = {
        string.format("Время:  %02d:%02d", math.floor(t_sec / 60), t_sec % 60),
        string.format("Убито:  %d", stats.kills or 0),
        string.format("Собрано предметов: %d", stats.items or 0),
        string.format("Причина: %s", stats.cause or "Враг"),
    }
    for i, l in ipairs(lines) do
        love.graphics.printf(l, 0, 60 + (i - 1) * 12, 320, "center")
    end

    -- Кнопки
    for i, b in ipairs(self.buttons) do
        local y = 120 + (i - 1) * 18
        if self.hover == i then
            love.graphics.setColor(0.4, 0.6, 1.0, 0.5)
            love.graphics.rectangle("fill", 100, y, 120, 14)
            love.graphics.setColor(0.6, 0.9, 1.0, 1)
        else
            love.graphics.setColor(0.2, 0.3, 0.5, 0.4)
            love.graphics.rectangle("fill", 100, y, 120, 14)
            love.graphics.setColor(0.8, 0.8, 0.9, 1)
        end
        love.graphics.rectangle("line", 100, y, 120, 14)
        love.graphics.printf(b.label, 100, y + 1, 120, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return M
