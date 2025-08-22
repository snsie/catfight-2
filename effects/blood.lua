-- effects/blood.lua
-- Simple blood particle manager

local blood = {
  particles = {},
  max = 600,
}

local GRAVITY = 1800

function blood:spawn(x, y, dir, damage)
  -- damage scales amount
  local count = math.min(8 + math.floor(damage * 0.6), 40)
  for i=1,count do
    if #self.particles >= self.max then break end
    local ang = (dir or 1) * (math.rad(15) + (math.random()-0.5)*math.rad(50)) + (dir==-1 and math.pi or 0)
    local spd = 200 + math.random()*420
    local vx = math.cos(ang)*spd
    local vy = -math.abs(math.sin(ang))*spd*0.6 - math.random()*120
    self.particles[#self.particles+1] = {
      x = x + (math.random()-0.5)*18,
      y = y + (math.random()-0.5)*18,
      vx = vx,
      vy = vy,
      r = 3 + math.random()*3,
      life = 0.6 + math.random()*0.6,
      age = 0,
      spin = (math.random()-0.5)*8,
      dr = (math.random()<0.5) and 0 or 1,
    }
  end
end

function blood:update(dt)
  local i=1
  while i <= #self.particles do
    local p = self.particles[i]
    p.age = p.age + dt
    if p.age >= p.life then
      table.remove(self.particles, i)
    else
      p.vy = p.vy + GRAVITY*dt
      p.x = p.x + p.vx*dt
      p.y = p.y + p.vy*dt
      p.vx = p.vx * 0.98
      -- ground collide (simple)
      local ground = 640 -- approximate foot level area: groundY
      if p.y > ground then
        p.y = ground
        p.vy = -p.vy * 0.25
        if math.abs(p.vy) < 60 then p.vy = 0 end
        p.vx = p.vx * 0.7
      end
      i = i + 1
    end
  end
end

function blood:draw()
  if #self.particles == 0 then return end
  love.graphics.setColor(0.75,0,0,0.85)
  for _,p in ipairs(self.particles) do
    local t = 1 - (p.age / p.life)
    love.graphics.setColor(0.8,0.05,0.05, 0.2 + 0.7*t)
    love.graphics.circle('fill', p.x, p.y, p.r * (0.4 + 0.6*t))
  end
  love.graphics.setColor(1,1,1,1)
end

return blood
