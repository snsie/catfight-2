-- player.lua
-- Defines Player entity supporting two instances with different control mappings.

local Player = {}
Player.__index = Player
local blood = require('effects.blood')

local ATTACKS = {
  light = { name = "light", startup = 0.08, active = 0.10, recovery = 0.20, damage = 6, knockback = 1180, stamina = 0 },
  heavy = { name = "heavy", startup = 0.18, active = 0.14, recovery = 0.35, damage = 14, knockback = 1320, stamina = 0 },
  special = { name = "special", startup = 0.25, active = 0.25, recovery = 0.45, damage = 22, knockback = 1450, stamina = 35 },
}

-- Utility AABB collision
local function aabb(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Shared sprite sheet (3 columns x 4 rows)
local SPRITE_SHEET_PATH = 'assets/sprites/3_4_kicks.png' -- put your 3x4 sheet here
local SHEET_COLS, SHEET_ROWS = 4, 3
local function ensureSheet()
  if Player.sheet then return end
  if love.filesystem.getInfo(SPRITE_SHEET_PATH) then
    Player.sheet = love.graphics.newImage(SPRITE_SHEET_PATH)
    Player.sheet:setFilter('nearest', 'nearest')
    local fw = Player.sheet:getWidth() / SHEET_COLS
    local fh = Player.sheet:getHeight() / SHEET_ROWS
    Player.frames = {}
    for row = 0, SHEET_ROWS - 1 do
      for col = 0, SHEET_COLS - 1 do
        table.insert(Player.frames, love.graphics.newQuad(col * fw, row * fh, fw, fh, Player.sheet:getDimensions()))
      end
    end
    Player.frameW, Player.frameH = fw, fh
  else
    -- No sheet available; will fallback to rectangles
  end
end

-- Animation definitions referencing frame indices (row-major)
local ANIMS = {
  idle   = { frames = { 1, 2, 3 }, fps = 6, loop = true },
  walk   = { frames = { 4, 5, 6 }, fps = 10, loop = true },
  attack = { frames = { 7, 8, 9 }, fps = 14, loop = false },
  jump   = { frames = { 10, 11, 12 }, fps = 8, loop = true },
  hit    = { frames = { 10, 11 }, fps = 14, loop = false },
  dash   = { frames = { 4, 5, 6 }, fps = 20, loop = true },
  ko     = { frames = { 11 }, fps = 1, loop = false },
}

function Player.new(opts)
  local self = setmetatable({}, Player)
  ensureSheet()
  self.id = opts.id or 1
  self.controls = opts.controls
  self.color = opts.color or { 1, 1, 1 }
  self.x = opts.x or 0
  self.y = opts.y or 0 -- y = feet position (bottom)
  self.w = 48
  self.h = 96
  self.speed = 260
  self.groundY = self.y
  self.facing = 1
  self.health = 100
  self.maxHealth = 100
  self.stamina = 100
  self.maxStamina = 100
  self.staminaRegen = 22 -- per second
  self.state = 'idle'
  self.stateTimer = 0
  self.attackData = nil
  self.attackPhase = nil -- 'startup','active','recovery'
  self.invuln = 0
  self.hitstun = 0
  self.dashTime = 0
  self.dashDuration = 0.18
  self.dashSpeed = 520
  self.dashCost = 30
  self.dashIFrames = 0.12
  self.velx = 0
  self.vely = 0
  -- Jump parameters
  self.gravity = 1800
  self.jumpVel = -720
  self.airControl = 0.55
  self.jumpCost = 10
  self.roundsWon = 0
  self.alive = true
  self.comboCounter = 0
  self.hitVelx = 0 -- horizontal knockback velocity decays during hitstun
  self.lastDirPress = { left = -math.huge, right = -math.huge }
  self.doubleTapWindow = 0.25
  self.pendingDamage = 0
  -- Animation state
  self.anim = 'idle'
  self.animTimer = 0
  self.animFrameIndex = 1
  return self
end

function Player:onGround()
  return self.y >= self.groundY - 0.5
end

function Player:resetForRound(spawnX)
  self.x = spawnX
  self.y = self.groundY
  self.health = self.maxHealth
  self.stamina = self.maxStamina
  self.state = 'idle'
  self.stateTimer = 0
  self.attackData = nil
  self.attackPhase = nil
  self.invuln = 0
  self.hitstun = 0
  self.dashTime = 0
  self.velx = 0
  self.vely = 0
  self.alive = true
end

function Player:isBusy()
  return self.state == 'attacking' or self.state == 'dashing' or self.hitstun > 0
end

function Player:pressDirection(dir, time)
  local t = self.lastDirPress[dir]
  self.lastDirPress[dir] = time
  if time - t <= self.doubleTapWindow and self:onGround() then
    self:tryDash(dir)
  end
end

function Player:tryDash(dir)
  if not self:onGround() then return end
  if self.stamina < self.dashCost or self.state == 'dashing' or self.hitstun > 0 then return end
  self.state = 'dashing'
  self.stateTimer = 0
  self.dashTime = 0
  self.facing = (dir == 'left') and -1 or 1
  self.velx = self.facing * self.dashSpeed
  self.stamina = math.max(0, self.stamina - self.dashCost)
  self.invuln = self.dashIFrames
end

function Player:jump()
  if not self:onGround() then return end
  if self.state == 'dashing' then return end
  if self.stamina < self.jumpCost then return end
  self.stamina = self.stamina - self.jumpCost
  self.vely = self.jumpVel
end

function Player:attemptAttack(kind, simultaneousPressed)
  if self.state == 'dashing' or self.hitstun > 0 then return end
  if self.state == 'attacking' then return end
  local atk
  if kind == 'light' then
    atk = ATTACKS.light
  elseif kind == 'heavy' then
    atk = ATTACKS.heavy
  end
  -- Special: both attack buttons considered simultaneously
  if simultaneousPressed and self.stamina >= ATTACKS.special.stamina then
    atk = ATTACKS.special
    self.stamina = self.stamina - atk.stamina
  end
  if not atk then return end
  self.state = 'attacking'
  self.attackData = atk
  self.attackPhase = 'startup'
  self.stateTimer = 0
end

function Player:takeHit(atk, dir)
  if self.invuln > 0 or not self.alive then return end
  self.health = self.health - atk.damage
  if self.health <= 0 then
    self.health = 0
    self.alive = false
  end
  self.hitstun = math.max(0.18, 0.12 + (atk.damage / 100))
  -- Set immediate knockback velocity; player control suspended while in hitstun
  self.hitVelx = dir * atk.knockback
  self.velx = self.hitVelx
  -- Small vertical pop if airborne system wants (optional)
  if not self:onGround() then
    self.vely = self.vely - 120
  end
  self.invuln = 0.05
  -- Spawn blood at center of hurtbox
  local hb = self:getHurtbox()
  blood:spawn(hb.x + hb.w/2, hb.y + hb.h/2, dir, atk.damage)
end

function Player:updateAttack(dt, opponent)
  if self.state ~= 'attacking' then return end
  local atk = self.attackData
  self.stateTimer = self.stateTimer + dt
  local phaseTime = self.stateTimer
  local phaseDur
  if self.attackPhase == 'startup' then
    phaseDur = atk.startup
    if phaseTime >= phaseDur then
      self.attackPhase = 'active'
      self.stateTimer = 0
    end
  elseif self.attackPhase == 'active' then
    phaseDur = atk.active
    local hb = self:getHitbox()
    if opponent.alive and opponent.hitstun <= 0 and aabb(hb, opponent:getHurtbox()) then
      opponent:takeHit(atk, self.facing)
    end
    if phaseTime >= phaseDur then
      self.attackPhase = 'recovery'
      self.stateTimer = 0
    end
  elseif self.attackPhase == 'recovery' then
    phaseDur = atk.recovery
    if phaseTime >= phaseDur then
      self.state = 'idle'
      self.attackData = nil
      self.attackPhase = nil
      self.stateTimer = 0
    end
  end
end

function Player:getHurtbox()
  return { x = self.x - self.w / 2, y = self.y - self.h, w = self.w, h = self.h }
end

function Player:getHitbox()
  local base = self:getHurtbox()
  local rangeX = 30
  local hbWidth = 34
  local hbHeight = 48
  local x = base.x + (self.facing == 1 and (self.w + rangeX) or -(rangeX + hbWidth))
  local y = base.y + 20
  return { x = x, y = y, w = hbWidth, h = hbHeight }
end

function Player:update(dt, opponent, input, now)
  -- Regenerate stamina
  if self.stamina < self.maxStamina and self.state ~= 'attacking' then
    self.stamina = math.min(self.maxStamina, self.stamina + self.staminaRegen * dt)
  end

  if self.invuln > 0 then self.invuln = math.max(0, self.invuln - dt) end
  if self.hitstun > 0 then
    self.hitstun = math.max(0, self.hitstun - dt)
  end

  if opponent then
    self.facing = (opponent.x < self.x) and -1 or 1
  end

  if self.alive and self.hitstun <= 0 then
    local moveX = 0
    if input:down(self.controls.left) then moveX = moveX - 1 end
    if input:down(self.controls.right) then moveX = moveX + 1 end

    -- Horizontal control: limited in air
    local controlFactor = self:onGround() and 1 or self.airControl
    if self.state ~= 'dashing' and self.state ~= 'attacking' then
      self.velx = moveX * self.speed * controlFactor
    end

    -- Double tap (ground only)
    for _, dir in ipairs({ 'left', 'right' }) do
      if input:pressed(self.controls[dir]) then
        self:pressDirection(dir, now)
      end
    end

    -- Jump
    if input:pressed(self.controls.up) then
      self:jump()
    end

    local lightPressed = input:pressed(self.controls.light)
    local heavyPressed = input:pressed(self.controls.heavy)
    if lightPressed or heavyPressed then
      local simultaneous = lightPressed and heavyPressed
      self:attemptAttack(lightPressed and 'light' or 'heavy', simultaneous)
    end
  end

  if self.state == 'dashing' then
    self.dashTime = self.dashTime + dt
    if self.dashTime >= self.dashDuration then
      self.state = 'idle'
      self.velx = 0
    end
  end

  self:updateAttack(dt, opponent)

  -- Apply knockback decay while in hitstun
  if self.hitstun > 0 then
    local decay = 6 -- higher = faster slowdown
    self.hitVelx = self.hitVelx * math.exp(-decay * dt)
    self.velx = self.hitVelx
  elseif self.hitstun == 0 and math.abs(self.hitVelx) > 1 then
    -- Reset after stun ends
    self.hitVelx = 0
  end

  -- Apply gravity & vertical motion
  self.vely = self.vely + self.gravity * dt
  self.y = self.y + self.vely * dt
  if self.y > self.groundY then
    self.y = self.groundY
    self.vely = 0
  end

  -- Friction: do not apply while in hitstun (maintain knockback), but resume after
  if self:onGround() and self.state ~= 'dashing' and self.state ~= 'attacking' then
    if self.hitstun <= 0 then
      self.velx = self.velx * 0.80
    end
  end

  self.x = self.x + self.velx * dt

  local minX, maxX = 80, 1280 - 80
  if self.x < minX then self.x = minX end
  if self.x > maxX then self.x = maxX end
end

function Player:draw()
  -- Update / select animation just before draw (after physics)
  self:updateAnimation(love.timer.getDelta())
  if Player.sheet then
    local anim = ANIMS[self.anim]
    local frameId = anim.frames[self.animFrameIndex]
    local quad = Player.frames and Player.frames[frameId]
    local sx = self.facing == -1 and -1 or 1
    local ox = Player.frameW / 2
    local oy = Player.frameH
    local alpha = self.invuln > 0 and 0.6 or 1
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(Player.sheet, quad, self.x, self.y, 0, sx, 1, ox, oy)
  else
    -- Fallback rectangle placeholder if sheet missing
    local hb = self:getHurtbox()
    local alpha = self.invuln > 0 and 0.4 or 1
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
    love.graphics.rectangle('fill', hb.x, hb.y, hb.w, hb.h, 6, 6)
  end
  -- Optional debug shadow & hitbox overlays
  if not self:onGround() then
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.ellipse('fill', self.x, self.groundY + 4, 24, 8)
  end
  if self.state == 'attacking' and self.attackPhase == 'active' then
    local hb2 = self:getHitbox()
    love.graphics.setColor(1, 0.2, 0.2, 0.25)
    love.graphics.rectangle('line', hb2.x, hb2.y, hb2.w, hb2.h)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Animation system (placed after return so local ANIMS is in scope)
function Player:updateAnimation(dt)
  -- Choose animation
  local new
  if not self.alive then
    new = 'ko'
  elseif self.hitstun > 0 then
    new = 'hit'
  elseif self.state == 'attacking' then
    new = 'attack'
  elseif not self:onGround() then
    new = 'jump'
  elseif self.state == 'dashing' then
    new = 'dash'
  elseif math.abs(self.velx) > 40 then
    new = 'walk'
  else
    new = 'idle'
  end
  if new ~= self.anim then
    self.anim = new
    self.animTimer = 0
    self.animFrameIndex = 1
  end
  local spec = ANIMS[self.anim]
  if not spec then return end
  self.animTimer = self.animTimer + dt
  local frameDur = 1 / spec.fps
  while self.animTimer >= frameDur do
    self.animTimer = self.animTimer - frameDur
    if self.animFrameIndex < #spec.frames then
      self.animFrameIndex = self.animFrameIndex + 1
    else
      if spec.loop then
        self.animFrameIndex = 1
      end
    end
  end
end

return Player
