-- effects/money.lua
-- Money particle manager - similar to blood but with golden coins

local money = {
  particles = {},
  max = 8000, -- slightly lower than blood for performance
  totalSpawned = 0,
}

local GRAVITY = 1200 -- slightly less gravity than blood for more floaty feel
local SCREEN_W, SCREEN_H = 1280, 720

-- Tunables for money feel
local BASE_LIFE_MIN, BASE_LIFE_MAX = 1.2, 2.0 -- longer life than blood
local R_MIN, R_MAX = 3, 8 -- slightly larger than blood particles
local COVERAGE_SOFT_CAP = 0.4 -- less coverage than blood
local AVG_PARTICLE_AREA = math.pi * ((R_MIN + R_MAX) / 4) ^ 2

local function estimatedCoverage(particles)
  return (particles * AVG_PARTICLE_AREA) / (SCREEN_W * SCREEN_H)
end

function money:spawn(x, y, dir, damage, huge)
  if self.max <= 0 then return end
  damage = damage or 10
  -- Baseline count - fewer coins than blood particles
  local base = math.floor(damage * (huge and 80 or 45))
  -- Damp spawn if we already approximate high coverage
  local cover = estimatedCoverage(#self.particles)
  if cover > COVERAGE_SOFT_CAP then
    base = math.floor(base * (1 - (cover - COVERAGE_SOFT_CAP) * 1.5))
  end
  if base < 1 then return end
  base = math.min(base, 1000) -- per-call safety

  for i = 1, base do
    if #self.particles >= self.max then break end
    local spread = huge and 280 or 24
    local px = x + (math.random() - 0.5) * spread
    local py = y + (math.random() - 0.5) * (huge and 200 or 24)
    if huge then
      -- Occasionally seed full-screen stray coins
      if math.random() < 0.12 then
        px = math.random() * SCREEN_W
        py = math.random() * SCREEN_H
      end
    end
    local angBase = (dir or 1) * math.rad(15)
    local angVar = (math.random() - 0.5) * math.rad(100)
    local ang = (dir == -1 and math.pi or 0) + angBase + angVar
    local spd = (huge and 300 or 180) + math.random() * (huge and 400 or 280)
    local vx = math.cos(ang) * spd
    local vy = -math.abs(math.sin(ang)) * spd * (huge and 0.8 or 0.5) - math.random() * (huge and 150 or 100)
    local r = R_MIN + math.random() * (R_MAX - R_MIN)
    if huge and math.random() < 0.25 then r = r * 1.6 end
    local life = BASE_LIFE_MIN + math.random() * (BASE_LIFE_MAX - BASE_LIFE_MIN)
    if huge then life = life * (1.3 + math.random() * 0.7) end
    self.particles[#self.particles + 1] = {
      x = px,
      y = py,
      vx = vx,
      vy = vy,
      r = r,
      life = life,
      age = 0,
      spin = (math.random() - 0.5) * 8, -- slower spin than blood
      dr = (math.random() < 0.5) and 0 or 1,
      sticky = math.random() < 0.15, -- less sticky than blood
      sparkle = math.random() * math.pi * 2, -- for sparkle effect
    }
  end
end

-- Convenience to trigger an extreme burst (e.g., special KO)
function money:screenBurst(centerX, centerY, dir, damage)
  self:spawn(centerX, centerY, dir, damage * 1.5, true)
end

function money:update(dt)
  local i = 1
  while i <= #self.particles do
    local p = self.particles[i]
    p.age = p.age + dt
    if p.age >= p.life then
      table.remove(self.particles, i)
    else
      p.vy = p.vy + GRAVITY * dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.vx = p.vx * 0.985 -- slightly less friction than blood
      p.sparkle = p.sparkle + dt * 8 -- sparkle animation
      
      -- ground collide (simple)
      local ground = 640 -- approximate foot level area: groundY
      if p.y > ground then
        p.y = ground
        p.vy = -p.vy * 0.3 -- slightly more bounce than blood
        if math.abs(p.vy) < 50 then p.vy = 0 end
        p.vx = p.vx * 0.75 -- slightly more friction on ground
      end
      i = i + 1
    end
  end
end

function money:draw()
  if #self.particles == 0 then return end
  
  -- Draw coins with golden color and sparkle effect
  for _, p in ipairs(self.particles) do
    local t = 1 - (p.age / p.life)
    local alpha = 0.15 + 0.75 * t
    
    -- Main coin body - golden color
    love.graphics.setColor(0.9, 0.7, 0.1, alpha)
    love.graphics.circle('fill', p.x, p.y, p.r * (0.6 + 0.4 * t))
    
    -- Inner circle for coin detail
    love.graphics.setColor(1.0, 0.85, 0.2, alpha * 0.8)
    love.graphics.circle('fill', p.x, p.y, p.r * (0.3 + 0.2 * t))
    
    -- Sparkle effect
    if t > 0.3 then
      love.graphics.setBlendMode('add')
      local sparkleAlpha = 0.3 * t * (0.5 + 0.5 * math.sin(p.sparkle))
      love.graphics.setColor(1, 1, 0.8, sparkleAlpha)
      love.graphics.circle('fill', p.x, p.y, p.r * 0.2)
      love.graphics.setBlendMode('alpha')
    end
    
    -- Coin edge highlight
    love.graphics.setColor(1.0, 0.9, 0.3, alpha * 0.6)
    love.graphics.circle('line', p.x, p.y, p.r * (0.6 + 0.4 * t))
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

return money
