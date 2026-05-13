-- Динамический микшер: переходы музыки, громкости.
local M = {}
M.__index = M

function M.new(assets)
    local self = setmetatable({}, M)
    self.assets = assets
    self.music_current = nil
    self.master_vol = 0.7
    self.music_vol = 0.6
    self.sfx_vol = 0.9
    self.target_music_vol = self.music_vol
    self.fade_speed = 1.5
    return self
end

function M:play_music(name)
    local src = self.assets.music[name]
    if not src then return end
    if self.music_current == src and src:isPlaying() then return end
    if self.music_current and self.music_current ~= src then
        self.music_current:stop()
    end
    src:setVolume(self.music_vol * self.master_vol)
    src:play()
    self.music_current = src
end

function M:stop_music()
    if self.music_current then
        self.music_current:stop()
        self.music_current = nil
    end
end

function M:play_sfx(name, pitch, volume)
    local src = self.assets.sfx[name]
    if not src then return end
    local s = src:clone()
    s:setPitch(pitch or 1)
    s:setVolume((volume or 1) * self.sfx_vol * self.master_vol)
    s:play()
end

function M:update(dt)
    if self.music_current then
        local target = self.music_vol * self.master_vol
        local cur = self.music_current:getVolume()
        if math.abs(cur - target) > 0.01 then
            local dir = (target - cur) > 0 and 1 or -1
            cur = cur + dir * self.fade_speed * dt
            if (dir > 0 and cur > target) or (dir < 0 and cur < target) then cur = target end
            self.music_current:setVolume(cur)
        end
    end
end

function M:set_master(v) self.master_vol = math.max(0, math.min(1, v)) end
function M:set_music(v) self.music_vol = math.max(0, math.min(1, v)) end
function M:set_sfx(v) self.sfx_vol = math.max(0, math.min(1, v)) end

return M
