-- Менеджер сцен (стек). Сцены реализуют интерфейс:
--   scene.enter(ctx, params) | scene.exit() | scene.update(dt)
--   scene.draw() | scene.keypressed(k,s,r) | scene.mousepressed(x,y,b) | scene.mousereleased(x,y,b)
local M = {}

local ctx = nil
local stack = {}

local scene_factories = {
    menu = function() return require("ui.menu") end,
    game = function() return require("gameplay.game_scene") end,
    pause = function() return require("ui.pause") end,
    gameover = function() return require("ui.death_screen") end,
}

function M.init(context)
    ctx = context
end

local function instantiate(name)
    local mod = scene_factories[name]()
    if mod.new then return mod.new() end
    return mod
end

function M.push(name, params)
    local scene = instantiate(name)
    scene._name = name
    table.insert(stack, scene)
    if scene.enter then scene:enter(ctx, params) end
end

function M.pop()
    local top = stack[#stack]
    if top and top.exit then top:exit() end
    stack[#stack] = nil
end

function M.replace(name, params)
    while #stack > 0 do M.pop() end
    M.push(name, params)
end

function M.current() return stack[#stack] end
function M.current_name()
    local s = stack[#stack]
    return s and s._name or nil
end

local function call(method, ...)
    local s = stack[#stack]
    if s and s[method] then s[method](s, ...) end
end

function M.update(dt) call("update", dt) end
function M.draw() call("draw") end
function M.keypressed(k, s, r) call("keypressed", k, s, r) end
function M.keyreleased(k, s) call("keyreleased", k, s) end
function M.mousepressed(x, y, b) call("mousepressed", x, y, b) end
function M.mousereleased(x, y, b) call("mousereleased", x, y, b) end

return M
