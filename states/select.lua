local select = {}

function select:enter(ctx)
  self.confirmed = false
end

function select:update(dt, ctx)
  if ctx.input:pressed('return') or ctx.input:pressed('enter') then
    ctx.switchState('versus')
  end
end

function select:draw(ctx)
  love.graphics.clear(0.05, 0.05, 0.08, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf('CHARACTER SELECT', 0, 80, 1280, 'center')
  love.graphics.printf('Both players are stylish cyber cats (placeholder).', 0, 180, 1280, 'center')
  love.graphics.printf('Press ENTER to proceed to the fight.', 0, 260, 1280, 'center')
end

return select
