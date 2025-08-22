local menu = {}

function menu:enter(ctx)
  self.timer = 0
end

function menu:update(dt, ctx)
  self.timer = self.timer + dt
  if ctx.input:pressed('return') or ctx.input:pressed('enter') then
    ctx.switchState('select')
  end
end

function menu:draw(ctx)
  love.graphics.setColor(0.1, 0.1, 0.15, 1)
  love.graphics.rectangle('fill', 0, 0, 1280, 720)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf('CATFIGHT 2', 0, 180, 1280, 'center')
  love.graphics.printf('Press ENTER to Start', 0, 320, 1280, 'center')
  love.graphics.printf('1v1 Neon-Noir Alley Brawls', 0, 380, 1280, 'center')
end

return menu
