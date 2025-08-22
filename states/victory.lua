local victory = {}

function victory:enter(ctx, winner)
  self.winner = winner
  self.timer = 0
end

function victory:update(dt, ctx)
  self.timer = self.timer + dt
  if ctx.input:pressed('return') or ctx.input:pressed('enter') then
    ctx.resetMatch()
    ctx.switchState('versus')
  elseif ctx.input:pressed('m') then
    ctx.resetMatch()
    ctx.switchState('menu', true)
  end
end

function victory:draw(ctx)
  love.graphics.setColor(0.05, 0.05, 0.08, 1)
  love.graphics.rectangle('fill', 0, 0, 1280, 720)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf('VICTORY', 0, 140, 1280, 'center')
  love.graphics.printf('Winner: Player ' .. self.winner.id, 0, 260, 1280, 'center')
  love.graphics.printf('ENTER: Rematch   M: Menu', 0, 340, 1280, 'center')
end

return victory
