-- Камера с плавным следованием, shake и границами.
local utils = require("utils")
local M = {}
M.__index = M

function M.new(view_w, view_h)
    local self = setmetatable({}, M)
    self.x = 0
    self.y = 0
    self.target_x = 0
    self.target_y = 0
    self.view_w = view_w
    self.view_h = view_h
    self.shake_intensity = 0
    self.shake_time = 0
    self.shake_offset_x = 0
    self.shake_offset_y = 0
    self.bounds = nil  -- {x, y, w, h} (в мировых координатах)
    self.smooth = 8.0
    return self
end

function M:set_target(x, y)
    self.target_x = x
    self.target_y = y
end

function M:set_bounds(x, y, w, h)
    self.bounds = {x = x, y = y, w = w, h = h}
end

function M:clear_bounds()
    self.bounds = nil
end

function M:shake(intensity, duration)
    self.shake_intensity = math.max(self.shake_intensity, intensity)
    self.shake_time = math.max(self.shake_time, duration)
end

function M:update(dt)
    -- Плавное приближение к target (центр камеры в target)
    local target_cam_x = self.target_x - self.view_w / 2
    local target_cam_y = self.target_y - self.view_h / 2
    self.x = utils.lerp_dt(self.x, target_cam_x, self.smooth, dt)
    self.y = utils.lerp_dt(self.y, target_cam_y, self.smooth, dt)

    if self.bounds then
        if self.bounds.w >= self.view_w then
            self.x = utils.clamp(self.x, self.bounds.x, self.bounds.x + self.bounds.w - self.view_w)
        else
            self.x = self.bounds.x + (self.bounds.w - self.view_w) / 2
        end
        if self.bounds.h >= self.view_h then
            self.y = utils.clamp(self.y, self.bounds.y, self.bounds.y + self.bounds.h - self.view_h)
        else
            self.y = self.bounds.y + (self.bounds.h - self.view_h) / 2
        end
    end

    if self.shake_time > 0 then
        self.shake_time = self.shake_time - dt
        local k = math.min(1, self.shake_time)
        self.shake_offset_x = (love.math.random() - 0.5) * 2 * self.shake_intensity * k
        self.shake_offset_y = (love.math.random() - 0.5) * 2 * self.shake_intensity * k
        if self.shake_time <= 0 then
            self.shake_intensity = 0
            self.shake_offset_x, self.shake_offset_y = 0, 0
        end
    else
        self.shake_offset_x, self.shake_offset_y = 0, 0
    end
end

function M:apply()
    love.graphics.push()
    love.graphics.translate(
        -math.floor(self.x + self.shake_offset_x),
        -math.floor(self.y + self.shake_offset_y))
end

function M:reset()
    love.graphics.pop()
end

-- Видимость прямоугольника в мировой системе (для culling)
function M:is_visible(x, y, w, h)
    return x + w >= self.x and x <= self.x + self.view_w
       and y + h >= self.y and y <= self.y + self.view_h
end

return M
