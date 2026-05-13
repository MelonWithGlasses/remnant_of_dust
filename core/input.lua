-- Обёртка над клавиатурой и мышью. Хранит логические координаты курсора.
local M = {}
M.__index = M

function M.new()
    local self = setmetatable({}, M)
    self.mouse_x = 0
    self.mouse_y = 0
    self.scale = 1
    self.offset_x = 0
    self.offset_y = 0
    self.mouse_buttons = {}
    self.mouse_pressed = {}
    self.keys_pressed = {}
    return self
end

function M:update(dt, scale, offset_x, offset_y)
    self.scale = scale
    self.offset_x = offset_x
    self.offset_y = offset_y
    local mx, my = love.mouse.getPosition()
    self.mouse_x = (mx - offset_x) / scale
    self.mouse_y = (my - offset_y) / scale
    -- Сбросить «однокадровые» нажатия
    for k in pairs(self.mouse_pressed) do self.mouse_pressed[k] = false end
    for k in pairs(self.keys_pressed) do self.keys_pressed[k] = false end
end

function M:get_mouse_logical() return self.mouse_x, self.mouse_y end

function M:mousepressed(x, y, button)
    self.mouse_buttons[button] = true
    self.mouse_pressed[button] = true
end

function M:mousereleased(x, y, button)
    self.mouse_buttons[button] = false
end

function M:keypressed(key, scancode, isrepeat)
    if not isrepeat then self.keys_pressed[key] = true end
end

function M:keyreleased(key, scancode) end

function M:is_mouse_down(button) return self.mouse_buttons[button] == true end
function M:was_mouse_pressed(button) return self.mouse_pressed[button] == true end
function M:was_key_pressed(key) return self.keys_pressed[key] == true end

-- Удобная функция: единичный вектор движения от WASD/стрелок
function M:get_move_axis()
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then dy = dy - 1 end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then dy = dy + 1 end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then dx = dx - 1 end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then dx = dx + 1 end
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 1 then dx, dy = dx / len, dy / len end
    return dx, dy
end

return M
