-- Процедурный граф этажа: случайное остовное дерево DFS + 2-4 цикла.
-- 10-18 комнат с типами: start, normal, elite, shop, altar, secret, boss.
local utils = require("utils")

local M = {}

local DIRS = {
    {name = "north", dx = 0, dy = -1, opp = "south"},
    {name = "south", dx = 0, dy = 1,  opp = "north"},
    {name = "west",  dx = -1, dy = 0, opp = "east"},
    {name = "east",  dx = 1,  dy = 0, opp = "west"},
}

local function key(x, y) return x * 1000 + y end

-- Генерация графа этажа.
-- room_count: целевое число комнат (10-18 по умолчанию).
function M.generate(room_count)
    room_count = room_count or love.math.random(12, 16)

    local nodes = {}
    local by_pos = {}
    local function add_node(x, y)
        local n = {
            id = #nodes + 1, x = x, y = y, doors = {},
            type = "normal", distance = 0,
        }
        nodes[#nodes + 1] = n
        by_pos[key(x, y)] = n
        return n
    end

    -- Стартовая комната в (0,0)
    local start = add_node(0, 0)
    start.type = "start"

    -- DFS-обход: на каждом шаге случайно выбираем направление и добавляем
    local stack = {start}
    while #nodes < room_count and #stack > 0 do
        local cur = stack[#stack]
        -- Перемешиваем направления
        local dirs = {}
        for i = 1, #DIRS do dirs[i] = DIRS[i] end
        utils.shuffle(dirs)
        local placed = false
        for _, d in ipairs(dirs) do
            local nx, ny = cur.x + d.dx, cur.y + d.dy
            if not by_pos[key(nx, ny)] then
                local n = add_node(nx, ny)
                n.distance = cur.distance + 1
                cur.doors[d.name] = true
                n.doors[d.opp] = true
                table.insert(stack, n)
                placed = true
                break
            end
        end
        if not placed then table.remove(stack) end
    end

    -- Добавим 2-4 цикла (рёбра между соседними узлами без двери)
    local cycles = love.math.random(2, 4)
    local attempts = 0
    while cycles > 0 and attempts < 50 do
        attempts = attempts + 1
        local n = nodes[love.math.random(1, #nodes)]
        local d = DIRS[love.math.random(1, #DIRS)]
        local neighbor = by_pos[key(n.x + d.dx, n.y + d.dy)]
        if neighbor and not n.doors[d.name] then
            n.doors[d.name] = true
            neighbor.doors[d.opp] = true
            cycles = cycles - 1
        end
    end

    -- Найти самую дальнюю комнату для босса (по BFS)
    local function bfs_distances(root)
        local q = {root}
        root.bfs_dist = 0
        for _, n in ipairs(nodes) do if n ~= root then n.bfs_dist = nil end end
        while #q > 0 do
            local cur = table.remove(q, 1)
            for _, d in ipairs(DIRS) do
                if cur.doors[d.name] then
                    local nb = by_pos[key(cur.x + d.dx, cur.y + d.dy)]
                    if nb and nb.bfs_dist == nil then
                        nb.bfs_dist = cur.bfs_dist + 1
                        table.insert(q, nb)
                    end
                end
            end
        end
    end
    bfs_distances(start)

    local boss = start
    for _, n in ipairs(nodes) do
        if (n.bfs_dist or 0) > (boss.bfs_dist or 0) then boss = n end
    end
    boss.type = "boss"

    -- Раздать оставшиеся типы (исключая start/boss): elite/shop/altar/secret
    local available = {}
    for _, n in ipairs(nodes) do
        if n.type == "normal" then table.insert(available, n) end
    end
    utils.shuffle(available)
    local types = {
        {type = "elite", count = math.floor(#available * 0.15)},
        {type = "shop", count = math.max(1, math.floor(#available * 0.10))},
        {type = "altar", count = math.max(1, math.floor(#available * 0.08))},
        {type = "secret", count = math.max(0, math.floor(#available * 0.05))},
    }
    local idx = 1
    for _, t in ipairs(types) do
        for _ = 1, t.count do
            if available[idx] then
                available[idx].type = t.type
                idx = idx + 1
            end
        end
    end

    return {
        nodes = nodes,
        by_pos = by_pos,
        start_id = start.id,
        boss_id = boss.id,
    }
end

return M
