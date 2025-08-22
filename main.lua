-- main.lua
-- Entry point for CatFight 2. Implements state management & input handling.

local states = {
  menu = require('states.menu'),
  select = require('states.select'),
  versus = require('states.versus'),
  pause = require('states.pause'),
  victory = require('states.victory'),
}

local stack = {}
local ctx = {}

-- Simple input helper capturing pressed / released each frame
local Input = {}
Input.__index = Input
function Input.new()
  return setmetatable({ downMap = {}, pressedMap = {}, releasedMap = {} }, Input)
end

function Input:update()
  self.pressedMap = {}
  self.releasedMap = {}
end

function Input:keypressed(k)
  if not self.downMap[k] then self.pressedMap[k] = true end
  self.downMap[k] = true
end

function Input:keyreleased(k)
  self.downMap[k] = nil
  self.releasedMap[k] = true
end

function Input:pressed(k) return self.pressedMap[k] end

function Input:released(k) return self.releasedMap[k] end

function Input:down(k) return self.downMap[k] end

local input = Input.new()
ctx.input = input

function ctx.switchState(name, clear, ...)
  if clear then
    -- Call leave on all existing states
    for i = #stack, 1, -1 do
      local s = stack[i].inst
      if s.leave then s:leave(ctx) end
      stack[i] = nil
    end
  else
    -- Leave current top before replacing (single-stack style)
    if stack[#stack] and stack[#stack].inst.leave then
      stack[#stack].inst:leave(ctx)
    end
  end
  stack[#stack + 1] = { name = name, inst = states[name] }
  if states[name].enter then states[name]:enter(ctx, ...) end
end

function ctx.pushState(name, ...)
  stack[#stack + 1] = { name = name, inst = states[name] }
  if states[name].enter then states[name]:enter(ctx, ...) end
end

function ctx.popState()
  local top = stack[#stack]
  if top and top.inst.leave then top.inst:leave(ctx) end
  stack[#stack] = nil
end

function ctx.drawBelow()
  -- Draw state underneath top (used for pause overlay)
  if #stack >= 2 then
    local below = stack[#stack - 1].inst
    if below.draw then below:draw(ctx) end
  end
end

function ctx.resetMatch()
  -- Currently handled inside states when needed
end

local function current()
  return stack[#stack].inst
end

function love.load()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.window.setMode(1280, 720)
  ctx.switchState('menu', true)
end

function love.update(dt)
  -- Cap dt to avoid huge jumps
  if dt > 0.1 then dt = 0.1 end
  if #stack == 0 then return end
  local c = current()
  if c.update then c:update(dt, ctx) end
  input:update()
end

function love.draw()
  if #stack == 0 then return end
  local c = current()
  if c.draw then c:draw(ctx) end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print('FPS ' .. tostring(love.timer.getFPS()), 10, 700)
end

function love.keypressed(key)
  input:keypressed(key)
end

function love.keyreleased(key)
  input:keyreleased(key)
end

-- Notes:
-- Special attack is performed by pressing both attack buttons simultaneously.
-- Dashes are triggered by double tapping left/right within a short window.
