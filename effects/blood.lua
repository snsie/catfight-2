-- effects/blood.lua
-- Simple blood particle manager

local blood = {
  particles = {},
  max = 12000, -- higher ceiling for heavy coverage
  totalSpawned = 0,
}

local GRAVITY = 1800
local SCREEN_W, SCREEN_H = 1280, 720 -- adapt if your window changes

-- Tunables for coverage feel
local BASE_LIFE_MIN, BASE_LIFE_MAX = 0.8, 1.4
local R_MIN, R_MAX = 2, 7
local COVERAGE_SOFT_CAP = 0.65 -- fraction of screen we try not to exceed (est.)
local AVG_PARTICLE_AREA = math.pi * ((R_MIN + R_MAX) / 4) ^ 2

local function estimatedCoverage(particles)
  -- Rough estimation: (#particles * avg area)/screen area
  return (particles * AVG_PARTICLE_AREA) / (SCREEN_W * SCREEN_H)
end

function blood:spawn(x, y, dir, damage, huge)
  if self.max <= 0 then return end
  damage = damage or 10
  -- Baseline count scaled up aggressively; huge flag triggers screen-wide burst
  local base = math.floor(damage * (huge and 160 or 90))
  -- Damp spawn if we already approximate high coverage
  local cover = estimatedCoverage(#self.particles)
  if cover > COVERAGE_SOFT_CAP then
    base = math.floor(base * (1 - (cover - COVERAGE_SOFT_CAP) * 1.5))
  end
  if base < 1 then return end
  base = math.min(base, 2000) -- per-call safety

  for i = 1, base do
    if #self.particles >= self.max then break end
    local spread = huge and 320 or 28
    local px = x + (math.random() - 0.5) * spread
    local py = y + (math.random() - 0.5) * (huge and 240 or 28)
    if huge then
      -- Occasionally seed full-screen stray droplets
      if math.random() < 0.15 then
        px = math.random() * SCREEN_W
        py = math.random() * SCREEN_H
      end
    end
    local angBase = (dir or 1) * math.rad(18)
    local angVar = (math.random() - 0.5) * math.rad(120)
    local ang = (dir == -1 and math.pi or 0) + angBase + angVar
    local spd = (huge and 340 or 220) + math.random() * (huge and 520 or 360)
    local vx = math.cos(ang) * spd
    local vy = -math.abs(math.sin(ang)) * spd * (huge and 0.9 or 0.6) - math.random() * (huge and 200 or 120)
    local r = R_MIN + math.random() * (R_MAX - R_MIN)
    if huge and math.random() < 0.30 then r = r * 1.8 end
    local life = BASE_LIFE_MIN + math.random() * (BASE_LIFE_MAX - BASE_LIFE_MIN)
    if huge then life = life * (1.2 + math.random() * 0.8) end
    self.particles[#self.particles + 1] = {
      x = px,
      y = py,
      vx = vx,
      vy = vy,
      r = r,
      life = life,
      age = 0,
      spin = (math.random() - 0.5) * 10,
      dr = (math.random() < 0.5) and 0 or 1,
      sticky = math.random() < 0.25,
    }
  end
end

-- Convenience to trigger an extreme burst (e.g., special KO)
function blood:screenBurst(centerX, centerY, dir, damage)
  self:spawn(centerX, centerY, dir, damage * 2, true)
end

function blood:update(dt)
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
  -- Two-pass: base fill + additive brighter pass for fresher droplets
  for _, p in ipairs(self.particles) do
    local t = 1 - (p.age / p.life)
    local alpha = 0.12 + 0.68 * t
    love.graphics.setColor(0.55, 0, 0, alpha)
    love.graphics.circle('fill', p.x, p.y, p.r * (0.5 + 0.5 * t))
  end
  -- Highlight pass
  love.graphics.setBlendMode('add')
  for _, p in ipairs(self.particles) do
    local t = 1 - (p.age / p.life)
    if t > 0.25 then
      love.graphics.setColor(0.9, 0.05, 0.05, 0.15 * t)
      love.graphics.circle('fill', p.x, p.y, p.r * 0.4)
    end
  end
  love.graphics.setBlendMode('alpha')
  love.graphics.setColor(1, 1, 1, 1)
end

return blood
