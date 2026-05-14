-- Spatial hash для AABB-коллизий. Ячейка = 32×32.
local M = {}
M.__index = M

local CELL = 32

function M.new()
    local self = setmetatable({}, M)
    self.cells = {}
    self.cell_size = CELL
    return self
end

local function key(cx, cy) return cx * 100000 + cy end

local function cell_coords(x, y)
    return math.floor(x / CELL), math.floor(y / CELL)
end

function M:insert(entity)
    -- entity: {x, y, w, h, _grid_cells (auto)}
    local x0, y0 = cell_coords(entity.x, entity.y)
    local x1, y1 = cell_coords(entity.x + entity.w - 1, entity.y + entity.h - 1)
    entity._grid_cells = {}
    for cy = y0, y1 do
        for cx = x0, x1 do
            local k = key(cx, cy)
            local list = self.cells[k]
            if not list then list = {}; self.cells[k] = list end
            list[#list + 1] = entity
            entity._grid_cells[#entity._grid_cells + 1] = k
        end
    end
end

function M:remove(entity)
    if not entity._grid_cells then return end
    for _, k in ipairs(entity._grid_cells) do
        local list = self.cells[k]
        if list then
            for i = #list, 1, -1 do
                if list[i] == entity then table.remove(list, i); break end
            end
        end
    end
    entity._grid_cells = nil
end

function M:update(entity)
    self:remove(entity)
    self:insert(entity)
end

function M:query(x, y, w, h)
    local x0, y0 = cell_coords(x, y)
    local x1, y1 = cell_coords(x + w - 1, y + h - 1)
    local seen = {}
    local result = {}
    for cy = y0, y1 do
        for cx = x0, x1 do
            local list = self.cells[key(cx, cy)]
            if list then
                for _, e in ipairs(list) do
                    if not seen[e] then
                        seen[e] = true
                        result[#result + 1] = e
                    end
                end
            end
        end
    end
    return result
end

function M:clear()
    self.cells = {}
end

function M:count_occupancy()
    local n = 0
    for _ in pairs(self.cells) do n = n + 1 end
    return n
end

return M
