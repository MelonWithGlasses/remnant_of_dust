-- Главное меню: анимированный органический фон, glitch-логотип, кнопки.
local M = {}
M.__index = M

local function point_in_rect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function M.new()
    return setmetatable({}, M)
end

function M:enter(ctx, params)
    self.ctx = ctx
    self.time = 0
    self.bg = ctx.assets.sprites.menu_bg
    self.font_logo = ctx.assets.font_large
    self.font_btn = ctx.assets.font_medium

    self.buttons = {
        {label = "Играть", action = "start"},
        {label = "Настройки", action = "settings"},
        {label = "Кодекс", action = "codex"},
        {label = "Выход", action = "quit"},
    }
    self.hover = 0
    ctx.audio:play_music("menu")
end

function M:exit() end

function M:update(dt)
    self.time = self.time + dt
    local mx, my = self.ctx.input:get_mouse_logical()
    local btn_x, btn_y, btn_w, btn_h, gap = 100, 90, 120, 14, 4
    self.hover = 0
    for i, b in ipairs(self.buttons) do
        local y = btn_y + (i - 1) * (btn_h + gap)
        if point_in_rect(mx, my, btn_x, y, btn_w, btn_h) then
            self.hover = i
        end
    end
end

function M:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.hover > 0 then
        local action = self.buttons[self.hover].action
        self.ctx.audio:play_sfx("click")
        if action == "start" then
            require("core.engine").replace("game", {class_id = "strand"})
        elseif action == "quit" then
            love.event.quit()
        end
        -- Остальные пункты пока без реализации (Stage 11)
    end
end

function M:keypressed(key)
    if key == "return" or key == "space" then
        self.ctx.audio:play_sfx("click")
        require("core.engine").replace("game", {class_id = "strand"})
    end
end

local function draw_glitch_text(text, x, y, font, t)
    local prev_font = love.graphics.getFont()
    love.graphics.setFont(font)
    -- Сдвиг каналов R/G/B
    local dx_r = math.floor((math.sin(t * 7.0) + 1) * 1.5) - 1
    local dx_b = -math.floor((math.cos(t * 5.0) + 1) * 1.5) + 1
    love.graphics.setColor(1, 0, 0, 0.7)
    love.graphics.print(text, x + dx_r, y)
    love.graphics.setColor(0, 1, 1, 0.7)
    love.graphics.print(text, x + dx_b, y)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(text, x, y)
    love.graphics.setFont(prev_font)
end

function M:draw()
    -- Фон: пульсация по альфе + плавающий вертикальный сдвиг
    love.graphics.setColor(1, 1, 1, 1)
    local off = math.floor(math.sin(self.time * 0.5) * 2)
    love.graphics.draw(self.bg, 0, off)

    -- Случайные «глитч-полосы»
    love.graphics.setColor(1, 1, 1, 0.05 + 0.05 * math.sin(self.time * 3))
    for i = 0, 179, 4 do
        love.graphics.rectangle("fill", 0, i, 320, 1)
    end

    -- Логотип
    draw_glitch_text("REMNANT", 60, 28, self.font_logo, self.time)
    draw_glitch_text(" OF DUST", 70, 50, self.font_logo, self.time + 1)

    -- Кнопки
    love.graphics.setFont(self.font_btn)
    local btn_x, btn_y, btn_w, btn_h, gap = 100, 90, 120, 14, 4
    for i, b in ipairs(self.buttons) do
        local y = btn_y + (i - 1) * (btn_h + gap)
        local hovered = self.hover == i
        if hovered then
            love.graphics.setColor(0.4, 0.6, 1.0, 0.4)
            love.graphics.rectangle("fill", btn_x, y, btn_w, btn_h)
            love.graphics.setColor(0.6, 0.9, 1.0, 1)
        else
            love.graphics.setColor(0.2, 0.3, 0.5, 0.3)
            love.graphics.rectangle("fill", btn_x, y, btn_w, btn_h)
            love.graphics.setColor(0.8, 0.8, 0.9, 1)
        end
        love.graphics.rectangle("line", btn_x, y, btn_w, btn_h)
        love.graphics.printf(b.label, btn_x, y + 1, btn_w, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- Подсказка
    love.graphics.setFont(self.ctx.assets.font_small)
    love.graphics.setColor(0.5, 0.6, 0.7, 1)
    love.graphics.print("WASD двигаться  |  ЛКМ стрелять  |  TAB инвентарь  |  F3 отладка",
        16, 166)
    love.graphics.setColor(1, 1, 1, 1)
end

return M
