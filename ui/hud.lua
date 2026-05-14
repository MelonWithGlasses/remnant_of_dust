-- HUD: синапсы (HP), перегрев, миникарта, комбо.
local M = {}
M.__index = M

function M.new(ctx)
    local self = setmetatable({}, M)
    self.ctx = ctx
    self.assets = ctx.assets
    self.font = ctx.assets.font_small
    return self
end

local function draw_synapses(self, player, x, y)
    local syn_full = self.assets.sprites.ui.synapse_full
    local syn_empty = self.assets.sprites.ui.synapse_empty
    -- HP в виде узлов: один узел = 2 HP. Полностью целый = full; полу-узел = full с тиром; пустой = empty.
    local nodes = math.min(player.max_synapses, 10)
    for i = 1, nodes do
        local node_hp = math.max(0, math.min(2, player.hp - (i - 1) * 2))
        local img = (node_hp > 0) and syn_full or syn_empty
        local cx = x + (i - 1) * 9
        love.graphics.draw(img, cx, y)
        if node_hp == 1 then
            -- полу-нота: затемнить правую половину
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("fill", cx + 4, y, 4, 8)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

local function draw_heat(self, player, x, y)
    local w, h = 60, 5
    love.graphics.setColor(0.1, 0.1, 0.15, 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.3, 0.3, 0.4, 1)
    love.graphics.rectangle("line", x, y, w, h)
    local pct = player.heat / 100
    local r, g, b
    if pct < 0.5 then
        r, g, b = 0.2, 1, 0.4
    elseif pct < 0.8 then
        r, g, b = 1, 0.9, 0.3
    else
        r, g, b = 1, 0.3, 0.3
    end
    if player.overheated and math.floor(love.timer.getTime() * 6) % 2 == 0 then
        r, g, b = 1, 1, 1
    end
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, (w - 2) * pct, h - 2)
    love.graphics.setColor(1, 1, 1, 1)
end

local function draw_minimap(self, floor, current_id, x, y)
    local size = 60
    local cell = 5
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, y, size, size)
    love.graphics.setColor(0.3, 0.3, 0.4, 1)
    love.graphics.rectangle("line", x, y, size, size)
    if not floor then love.graphics.setColor(1, 1, 1, 1); return end

    -- Найти границы
    local min_x, max_x, min_y, max_y = 999, -999, 999, -999
    for _, n in ipairs(floor.nodes) do
        if n.x < min_x then min_x = n.x end
        if n.x > max_x then max_x = n.x end
        if n.y < min_y then min_y = n.y end
        if n.y > max_y then max_y = n.y end
    end
    local cx = x + size / 2
    local cy = y + size / 2
    local cur_node = floor.nodes[current_id]
    local off_x = cx - cur_node.x * cell
    local off_y = cy - cur_node.y * cell
    local visited_ids = self.ctx.visited_rooms or {}

    -- Связи
    love.graphics.setColor(0.4, 0.4, 0.5, 1)
    for _, n in ipairs(floor.nodes) do
        if visited_ids[n.id] then
            local nx = off_x + n.x * cell
            local ny = off_y + n.y * cell
            if n.doors.east and visited_ids[floor.by_pos[(n.x + 1) * 1000 + n.y] and
                floor.by_pos[(n.x + 1) * 1000 + n.y].id] then
                love.graphics.line(nx + cell / 2, ny, nx + cell, ny)
            end
            if n.doors.south and visited_ids[floor.by_pos[n.x * 1000 + (n.y + 1)] and
                floor.by_pos[n.x * 1000 + (n.y + 1)].id] then
                love.graphics.line(nx, ny + cell / 2, nx, ny + cell)
            end
        end
    end

    -- Узлы
    for _, n in ipairs(floor.nodes) do
        if visited_ids[n.id] then
            local nx = off_x + n.x * cell
            local ny = off_y + n.y * cell
            local rx = nx - cell / 2 + 1
            local ry = ny - cell / 2 + 1
            local sw = cell - 1
            if n.type == "boss" then
                love.graphics.setColor(1, 0.3, 0.3, 1)
            elseif n.type == "shop" then
                love.graphics.setColor(0.4, 0.8, 1, 1)
            elseif n.type == "altar" then
                love.graphics.setColor(1, 0.5, 1, 1)
            elseif n.type == "elite" then
                love.graphics.setColor(1, 0.7, 0.3, 1)
            elseif n.type == "start" then
                love.graphics.setColor(0.4, 1, 0.4, 1)
            elseif n.type == "secret" then
                love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
            else
                love.graphics.setColor(0.7, 0.7, 0.8, 1)
            end
            if x <= rx and rx + sw <= x + size and y <= ry and ry + sw <= y + size then
                love.graphics.rectangle("fill", rx, ry, sw, sw)
            end
        end
    end

    -- Текущая комната (мигающая)
    if math.floor(love.timer.getTime() * 4) % 2 == 0 then
        local nx = off_x + cur_node.x * cell
        local ny = off_y + cur_node.y * cell
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", nx - cell / 2, ny - cell / 2, cell, cell)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function M:draw(player, floor, current_room_id, combo)
    love.graphics.setFont(self.font)

    -- Синапсы (top-left)
    draw_synapses(self, player, 4, 4)
    -- Перегрев под синапсами
    draw_heat(self, player, 4, 14)
    -- Миникарта (top-right)
    draw_minimap(self, floor, current_room_id, 320 - 64, 4)

    -- Комбо в центре сверху
    if combo and combo > 1 then
        love.graphics.setColor(1, 0.9, 0.3, 1)
        love.graphics.printf("x" .. combo, 0, 4, 320, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Глиальный счётчик и DNA
    love.graphics.setColor(0.4, 1, 0.6, 1)
    love.graphics.print("GLI " .. player.glial_count .. "/3", 4, 24)
    love.graphics.setColor(0.6, 0.4, 1, 1)
    love.graphics.print("DNA " .. player.dna_count, 4, 32)
    love.graphics.setColor(1, 1, 1, 1)
end

return M
