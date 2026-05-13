-- Вспомогательные функции: math, table, string
local utils = {}

-- Зажимает значение в диапазоне [min, max]
function utils.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- Линейная интерполяция
function utils.lerp(a, b, t)
    return a + (b - a) * t
end

-- Линейная интерполяция, кадронезависимая (smoothing)
function utils.lerp_dt(a, b, rate, dt)
    return utils.lerp(a, b, 1 - math.exp(-rate * dt))
end

-- Квадрат расстояния
function utils.dist_sq(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return dx * dx + dy * dy
end

-- Расстояние между двумя точками
function utils.dist(x1, y1, x2, y2)
    return math.sqrt(utils.dist_sq(x1, y1, x2, y2))
end

-- Нормализация вектора
function utils.normalize(x, y)
    local len = math.sqrt(x * x + y * y)
    if len < 1e-6 then return 0, 0 end
    return x / len, y / len
end

-- Угол вектора в радианах
function utils.angle(x, y)
    return math.atan2(y, x)
end

-- AABB пересечение
function utils.aabb_overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx
        and ay < by + bh and ay + ah > by
end

-- Точка внутри прямоугольника
function utils.point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px < rx + rw and py >= ry and py < ry + rh
end

-- Глубокая копия таблицы
function utils.deep_copy(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local copy = {}
    seen[t] = copy
    for k, v in pairs(t) do
        copy[utils.deep_copy(k, seen)] = utils.deep_copy(v, seen)
    end
    return setmetatable(copy, getmetatable(t))
end

-- Случайный элемент массива
function utils.random_choice(arr)
    if #arr == 0 then return nil end
    return arr[love.math.random(1, #arr)]
end

-- Взвешенный случайный выбор: items = {{value=x, weight=w}, ...}
function utils.weighted_choice(items)
    local total = 0
    for _, item in ipairs(items) do total = total + item.weight end
    local r = love.math.random() * total
    local acc = 0
    for _, item in ipairs(items) do
        acc = acc + item.weight
        if r <= acc then return item.value end
    end
    return items[#items].value
end

-- Перемешать массив на месте (Fisher-Yates)
function utils.shuffle(arr)
    for i = #arr, 2, -1 do
        local j = love.math.random(1, i)
        arr[i], arr[j] = arr[j], arr[i]
    end
    return arr
end

-- Подсчёт элементов в таблице (любые ключи)
function utils.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Простая сериализация Lua-таблиц в строку (для save_manager)
function utils.serialize(value, indent)
    indent = indent or ""
    local t = type(value)
    if t == "nil" then return "nil" end
    if t == "boolean" then return tostring(value) end
    if t == "number" then return tostring(value) end
    if t == "string" then return string.format("%q", value) end
    if t == "table" then
        local parts = {"{"}
        local next_indent = indent .. "  "
        for k, v in pairs(value) do
            local key
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                key = k .. "="
            else
                key = "[" .. utils.serialize(k, next_indent) .. "]="
            end
            table.insert(parts, next_indent .. key .. utils.serialize(v, next_indent) .. ",")
        end
        table.insert(parts, indent .. "}")
        return table.concat(parts, "\n")
    end
    return "nil"
end

-- Десериализация строки обратно в Lua-таблицу
function utils.deserialize(str)
    local chunk = loadstring("return " .. str)
    if not chunk then return nil end
    local ok, value = pcall(chunk)
    if not ok then return nil end
    return value
end

-- HSV -> RGB (для процедурных палитр)
function utils.hsv_to_rgb(h, s, v)
    local c = v * s
    local hh = (h % 1) * 6
    local x = c * (1 - math.abs(hh % 2 - 1))
    local r, g, b
    if hh < 1 then r, g, b = c, x, 0
    elseif hh < 2 then r, g, b = x, c, 0
    elseif hh < 3 then r, g, b = 0, c, x
    elseif hh < 4 then r, g, b = 0, x, c
    elseif hh < 5 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    local m = v - c
    return r + m, g + m, b + m
end

-- Знак числа
function utils.sign(x)
    if x > 0 then return 1 end
    if x < 0 then return -1 end
    return 0
end

-- math.atan2 для Lua 5.3+ (LÖVE 11 использует LuaJIT, у которого есть math.atan2)
if not math.atan2 then
    math.atan2 = function(y, x) return math.atan(y, x) end
end

return utils
