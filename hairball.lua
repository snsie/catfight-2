-- hairball.lua
-- Hairball projectile class for cat fight attacks

local Hairball = {}
Hairball.__index = Hairball

function Hairball.new(x, y, direction, ownerId)
  local self = setmetatable({}, Hairball)
  self.x = x
  self.y = y
  self.direction = direction -- 1 for right, -1 for left
  self.ownerId = ownerId -- ID of the player who shot this hairball
  self.speed = 400 -- pixels per second
  self.velx = self.direction * self.speed
  self.vely = 0
  self.w = 16
  self.h = 12
  self.damage = 8
  self.knockback = 800
  self.lifetime = 3.0 -- seconds before disappearing
  self.age = 0
  self.active = true
  self.gravity = 200 -- slight gravity effect
  self.bounce = 0.3 -- bounce factor when hitting ground
  self.groundY = 640 -- same as player ground level
  self.bounced = false
  return self
end

function Hairball:update(dt)
  if not self.active then return end
  
  self.age = self.age + dt
  
  -- Remove if lifetime exceeded
  if self.age >= self.lifetime then
    self.active = false
    return
  end
  
  -- Apply gravity
  self.vely = self.vely + self.gravity * dt
  
  -- Update position
  self.x = self.x + self.velx * dt
  self.y = self.y + self.vely * dt
  
  -- Bounce off ground
  if self.y >= self.groundY - self.h/2 and not self.bounced then
    self.y = self.groundY - self.h/2
    self.vely = -self.vely * self.bounce
    self.bounced = true
  end
  
  -- Remove if off screen
  if self.x < -50 or self.x > 1330 then
    self.active = false
  end
end

function Hairball:getHitbox()
  return {
    x = self.x - self.w/2,
    y = self.y - self.h/2,
    w = self.w,
    h = self.h
  }
end

function Hairball:draw()
  if not self.active then return end
  
  -- Draw hairball as a brownish oval
  love.graphics.setColor(0.6, 0.4, 0.2, 1) -- brown color
  love.graphics.ellipse('fill', self.x, self.y, self.w/2, self.h/2)
  
  -- Add some texture with darker spots
  love.graphics.setColor(0.4, 0.25, 0.1, 1)
  love.graphics.ellipse('fill', self.x - 2, self.y - 1, 3, 2)
  love.graphics.ellipse('fill', self.x + 1, self.y + 1, 2, 2)
  
  -- Reset color
  love.graphics.setColor(1, 1, 1, 1)
end

function Hairball:isActive()
  return self.active
end

function Hairball:getDamage()
  return self.damage
end

function Hairball:getKnockback()
  return self.knockback
end

function Hairball:getDirection()
  return self.direction
end

function Hairball:getOwnerId()
  return self.ownerId
end

return Hairball
