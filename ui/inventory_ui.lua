-- Экран инвентаря (overlay поверх игры). Открывается по TAB.
-- 4x4 сетка собранных предметов + 6 слотов мутаций + слот активного протокола.
-- Hover показывает подсказку, ПКМ выбрасывает (не-мутагены).
local M = {}
M.__index = M

local RARITY_COLOR = {
    common    = {0.7, 0.9, 0.7, 1},
    rare      = {0.4, 0.6, 1.0, 1},
    epic      = {0.7, 0.4, 1.0, 1},
    legendary = {1.0, 0.8, 0.3, 1},
}

local function point_in_rect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function M.new(ctx)
    local self = setmetatable({}, M)
    self.ctx = ctx
    self.assets = ctx.assets
    self.font = ctx.assets.font_small
    self.font_med = ctx.assets.font_medium
    self.hover = nil    -- {kind = "inv"|"mut"|"active", index = i}
    return self
end

function M:layout()
    return {
        inv = {x = 40,  y = 50,  cols = 4, rows = 4, cell = 18},
        mut = {x = 200, y = 50,  cols = 1, rows = 6, cell = 14},
        active = {x = 240, y = 50, w = 36, h = 36},
    }
end

function M:hit_test(mx, my)
    local L = self:layout()
    local g = L.inv
    for r = 0, g.rows - 1 do
        for c = 0, g.cols - 1 do
            local x = g.x + c * g.cell
            local y = g.y + r * g.cell
            if point_in_rect(mx, my, x, y, g.cell, g.cell) then
                return {kind = "inv", index = r * g.cols + c + 1}
            end
        end
    end
    g = L.mut
    for r = 0, g.rows - 1 do
        local x = g.x
        local y = g.y + r * g.cell
        if point_in_rect(mx, my, x, y, g.cell, g.cell) then
            return {kind = "mut", index = r + 1}
        end
    end
    local a = L.active
    if point_in_rect(mx, my, a.x, a.y, a.w, a.h) then
        return {kind = "active"}
    end
    return nil
end

function M:update(dt, player)
    local mx, my = self.ctx.input:get_mouse_logical()
    self.hover = self:hit_test(mx, my)
end

-- ПКМ выбрасывает не-мутаген; возвращает (def, x, y) если был дроп.
function M:mousepressed(x, y, button, player)
    if button ~= 2 then return nil end
    local h = self:hit_test(x, y)
    if not h or h.kind ~= "inv" then return nil end
    local def = player:drop_item(h.index)
    if def then return def, player.x + 8, player.y + 8 end
    return nil
end

local function draw_slot(x, y, size, def, sprite, selected)
    love.graphics.setColor(0.05, 0.07, 0.12, 0.9)
    love.graphics.rectangle("fill", x, y, size, size)
    if def then
        local rc = RARITY_COLOR[def.rarity] or RARITY_COLOR.common
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.7)
    else
        love.graphics.setColor(0.25, 0.3, 0.4, 0.6)
    end
    love.graphics.rectangle("line", x, y, size, size)
    if sprite then
        local iw, ih = sprite:getWidth(), sprite:getHeight()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprite, x + (size - iw) / 2, y + (size - ih) / 2)
    end
    if selected then
        love.graphics.setColor(1, 1, 1, 0.4 + 0.4 * math.sin(love.timer.getTime() * 6))
        love.graphics.rectangle("line", x - 1, y - 1, size + 2, size + 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function draw_tooltip(self, def, mx, my)
    if not def then return end
    love.graphics.setFont(self.font)
    local lines = {def.name}
    if def.type then table.insert(lines, "Тип: " .. def.type) end
    if def.rarity then table.insert(lines, "Редкость: " .. def.rarity) end
    if def.description then table.insert(lines, def.description) end
    local pad = 3
    local w = 0
    for _, l in ipairs(lines) do
        w = math.max(w, self.font:getWidth(l))
    end
    local lh = self.font:getHeight()
    local h = lh * #lines
    local x = mx + 8
    local y = my + 8
    if x + w + pad * 2 > 320 then x = mx - w - pad * 2 - 8 end
    if y + h + pad * 2 > 180 then y = my - h - pad * 2 - 8 end
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", x, y, w + pad * 2, h + pad * 2)
    local rc = RARITY_COLOR[def.rarity] or RARITY_COLOR.common
    love.graphics.setColor(rc[1], rc[2], rc[3], 1)
    love.graphics.rectangle("line", x, y, w + pad * 2, h + pad * 2)
    love.graphics.setColor(1, 1, 1, 1)
    for i, l in ipairs(lines) do
        if i == 1 then
            love.graphics.setColor(rc[1], rc[2], rc[3], 1)
        else
            love.graphics.setColor(0.85, 0.85, 0.9, 1)
        end
        love.graphics.print(l, x + pad, y + pad + (i - 1) * lh)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function M:draw(player)
    local L = self:layout()

    -- Затемнение фона
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 320, 180)

    -- Заголовок
    love.graphics.setColor(0.8, 0.9, 1.0, 1)
    love.graphics.setFont(self.font_med)
    love.graphics.printf("ИНВЕНТАРЬ", 0, 14, 320, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.6, 0.7, 0.8, 1)
    love.graphics.printf("TAB / ESC — закрыть   ПКМ — выбросить", 0, 34, 320, "center")

    -- Сетка инвентаря
    local g = L.inv
    love.graphics.setColor(0.6, 0.7, 0.8, 1)
    love.graphics.print("Предметы", g.x, g.y - 10)
    for r = 0, g.rows - 1 do
        for c = 0, g.cols - 1 do
            local i = r * g.cols + c + 1
            local def = player.items[i]
            local sprite = def and self.assets.sprites.items[def.id] or nil
            local sel = (self.hover and self.hover.kind == "inv" and self.hover.index == i)
            draw_slot(g.x + c * g.cell, g.y + r * g.cell, g.cell - 2, def, sprite, sel)
        end
    end

    -- Мутации
    g = L.mut
    love.graphics.setColor(0.7, 0.8, 1.0, 1)
    love.graphics.print("Мутации", g.x, g.y - 10)
    for r = 0, g.rows - 1 do
        local i = r + 1
        local def = player.mutations[i]
        local sprite = def and self.assets.sprites.items[def.id] or nil
        local sel = (self.hover and self.hover.kind == "mut" and self.hover.index == i)
        draw_slot(g.x, g.y + r * g.cell, g.cell - 2, def, sprite, sel)
    end

    -- Активный слот
    local a = L.active
    love.graphics.setColor(1.0, 0.8, 0.4, 1)
    love.graphics.print("Активный", a.x, a.y - 10)
    local def = player.active_item
    local sprite = def and self.assets.sprites.items[def.id] or nil
    local sel = (self.hover and self.hover.kind == "active")
    draw_slot(a.x, a.y, a.w, def, sprite, sel)
    if def then
        love.graphics.setColor(0.7, 0.8, 1.0, 1)
        love.graphics.printf(def.name, a.x - 10, a.y + a.h + 2, a.w + 20, "center")
        if player.active_cooldown > 0 then
            love.graphics.setColor(0.2, 0.3, 0.4, 0.9)
            local pct = math.min(1, player.active_cooldown / 6.0)
            love.graphics.rectangle("fill", a.x, a.y, a.w * pct, a.h)
        end
    end

    -- Статы
    love.graphics.setColor(0.6, 0.7, 0.8, 1)
    love.graphics.print(string.format("Скорость x%.2f", player.modifiers.speed_mult),    40, 134)
    love.graphics.print(string.format("Урон     x%.2f", player.modifiers.damage_mult),   40, 142)
    love.graphics.print(string.format("Скорострел x%.2f", player.modifiers.fire_rate_mult), 40, 150)
    love.graphics.print(string.format("Крит      %d%%", math.floor(player.modifiers.crit_chance * 100)), 40, 158)

    -- Подсказка
    if self.hover then
        local mx, my = self.ctx.input:get_mouse_logical()
        local def_h
        if self.hover.kind == "inv" then def_h = player.items[self.hover.index]
        elseif self.hover.kind == "mut" then def_h = player.mutations[self.hover.index]
        elseif self.hover.kind == "active" then def_h = player.active_item end
        if def_h then draw_tooltip(self, def_h, mx, my) end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return M
