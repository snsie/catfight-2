local pause = {}

function pause:enter(ctx)
end

function pause:update(dt, ctx)
  if ctx.input:pressed('escape') then
    ctx.popState()     -- resume
  elseif ctx.input:pressed('m') then
    ctx.resetMatch()
    ctx.switchState('menu', true)
  elseif ctx.input:pressed('r') then
    ctx.resetMatch()
    ctx.popState()     -- remove pause
    ctx.switchState('versus')
  end
end

function pause:draw(ctx)
  ctx.drawBelow()   -- draw the versus underneath
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle('fill', 0, 0, 1280, 720)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf('PAUSED', 0, 200, 1280, 'center')
  love.graphics.printf('ESC: Resume   R: Restart Match   M: Main Menu', 0, 320, 1280, 'center')
end

return pause
