-- Комната: прямоугольная арена с тайловыми стенами и дверями.
-- Размер: фиксированный, ~14×8 тайлов (224×128px) — больше логического кадра,
-- чтобы камера могла плавно двигаться внутри.
local utils = require("utils")

local M = {}
M.__index = M

local TILE = 16
local ROOM_TILES_W = 14
local ROOM_TILES_H = 8

M.TILE = TILE
M.W_TILES = ROOM_TILES_W
M.H_TILES = ROOM_TILES_H

local DOOR_DIRS = {
    north = {dx = 0, dy = -1},
    south = {dx = 0, dy = 1},
    west  = {dx = -1, dy = 0},
    east  = {dx = 1,  dy = 0},
}

local function door_tile_pos(dir)
    local mid_x = math.floor(ROOM_TILES_W / 2)
    local mid_y = math.floor(ROOM_TILES_H / 2)
    if dir == "north" then return mid_x, 0 end
    if dir == "south" then return mid_x, ROOM_TILES_H - 1 end
    if dir == "west"  then return 0, mid_y end
    if dir == "east"  then return ROOM_TILES_W - 1, mid_y end
end

-- node: {id, x, y, doors={dir=true,...}, type}
function M.new(node, biome, assets)
    local self = setmetatable({}, M)
    self.id = node.id
    self.node = node
    self.biome = biome
    self.type = node.type
    self.tile_w = ROOM_TILES_W
    self.tile_h = ROOM_TILES_H
    self.w = ROOM_TILES_W * TILE
    self.h = ROOM_TILES_H * TILE
    -- В мировых координатах все комнаты находятся в (0,0)..(w,h); сцена
    -- переключает их by-reference. Это упрощает камеру.
    self.x = 0
    self.y = 0

    self.assets = assets
    self.tiles = assets.sprites.tiles[biome.id]
    self.doors = {}
    for dir in pairs(DOOR_DIRS) do
        self.doors[dir] = node.doors and node.doors[dir] or false
    end

    self.cleared = (node.type == "start") and true or false
    self.doors_locked = not self.cleared

    -- Спавны врагов (заполняется game_scene при первом входе)
    self.enemies = {}
    self.enemies_spawned = false

    return self
end

function M:is_wall(tx, ty)
    if tx < 0 or ty < 0 or tx >= self.tile_w or ty >= self.tile_h then return true end
    if tx == 0 or ty == 0 or tx == self.tile_w - 1 or ty == self.tile_h - 1 then
        -- проверка двери
        for dir, has in pairs(self.doors) do
            if has then
                local dx, dy = door_tile_pos(dir)
                if tx == dx and ty == dy then return false end
            end
        end
        return true
    end
    return false
end

function M:get_door_world_pos(dir)
    local tx, ty = door_tile_pos(dir)
    return self.x + (tx + 0.5) * TILE, self.y + (ty + 0.5) * TILE
end

function M:get_center()
    return self.x + self.w / 2, self.y + self.h / 2
end

function M:draw()
    -- Пол
    love.graphics.setColor(1, 1, 1, 1)
    for ty = 1, self.tile_h - 2 do
        for tx = 1, self.tile_w - 2 do
            love.graphics.draw(self.tiles.floor,
                self.x + tx * TILE, self.y + ty * TILE)
        end
    end
    -- Стены (по периметру)
    for tx = 0, self.tile_w - 1 do
        love.graphics.draw(self.tiles.wall, self.x + tx * TILE, self.y)
        love.graphics.draw(self.tiles.wall, self.x + tx * TILE, self.y + (self.tile_h - 1) * TILE)
    end
    for ty = 0, self.tile_h - 1 do
        love.graphics.draw(self.tiles.wall, self.x, self.y + ty * TILE)
        love.graphics.draw(self.tiles.wall, self.x + (self.tile_w - 1) * TILE, self.y + ty * TILE)
    end
    -- Двери: на тайлах двери рисуем либо открытую, либо закрытую дверную клетку
    for dir, has in pairs(self.doors) do
        if has then
            local dx_t, dy_t = door_tile_pos(dir)
            if self.doors_locked then
                love.graphics.draw(self.tiles.door, self.x + dx_t * TILE, self.y + dy_t * TILE)
            else
                love.graphics.draw(self.tiles.floor, self.x + dx_t * TILE, self.y + dy_t * TILE)
                -- лёгкая подсветка
                love.graphics.setColor(self.biome.palette.accent[1],
                    self.biome.palette.accent[2], self.biome.palette.accent[3], 0.3)
                love.graphics.rectangle("fill",
                    self.x + dx_t * TILE, self.y + dy_t * TILE, TILE, TILE)
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    end
end

-- Проверка коллизии AABB со стенами
function M:collides(x, y, w, h)
    local t0x = math.floor(x / TILE)
    local t0y = math.floor(y / TILE)
    local t1x = math.floor((x + w - 1) / TILE)
    local t1y = math.floor((y + h - 1) / TILE)
    for ty = t0y, t1y do
        for tx = t0x, t1x do
            if self:is_wall(tx, ty) then return true end
        end
    end
    return false
end

-- Есть ли дверь в направлении dir и проходима ли она сейчас
function M:can_exit(dir)
    return self.doors[dir] and not self.doors_locked
end

function M:check_door_trigger(x, y)
    -- Возвращает направление, если игрок зашёл в зону двери
    for dir, has in pairs(self.doors) do
        if has and not self.doors_locked then
            local dxw, dyw = self:get_door_world_pos(dir)
            if utils.dist(x, y, dxw, dyw) < 8 then
                return dir
            end
        end
    end
    return nil
end

function M:on_enemies_cleared()
    self.cleared = true
    self.doors_locked = false
end

function M:lock_doors()
    self.doors_locked = true
end

return M
