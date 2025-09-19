-- player.lua
-- Defines Player entity supporting two instances with different control mappings.

local Player = {}
Player.__index = Player
local money = require('effects.money')

local ATTACKS = {
  light = { name = "light", startup = 0.08, active = 0.10, recovery = 0.20, damage = 6, knockback = 1180, stamina = 0 },
  heavy = { name = "heavy", startup = 0.18, active = 0.14, recovery = 0.35, damage = 14, knockback = 1320, stamina = 0 },
  special = { name = "special", startup = 0.25, active = 0.25, recovery = 0.45, damage = 22, knockback = 1450, stamina = 35 },
  hairball = { name = "hairball", startup = 0.12, active = 0.05, recovery = 0.30, damage = 8, knockback = 800, stamina = 15 },
}

-- Taunt messages for players
local TAUNT_MESSAGES = {
  "Hiss! 🐱",
  "You're going down!",
  "Meow meow!",
  "Bring it on!",
  "You can't handle this!",
  "Purr-fect timing!",
  "Claws out!",
  "I'm the alpha cat!",
  "Time to scratch!",
  "You're just a kitten!",
  "Rawr! 🦁",
  "I'll make you purr!",
  "Cat got your tongue?",
  "Nine lives, zero chance!",
  "I'm feline dangerous!",
  "Let's claw this out!",
  "You're not cat enough!",
  "Time to pounce!",
  "I'm the cat's meow!",
  "Prepare for the claw!"
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
  self.dashSpeed = 1180
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
  -- Flash state for down key
  self.flashTime = 0
  self.flashDuration = 0.5
  self.hairballCallback = nil -- callback for spawning hairballs
  -- Taunt system
  self.tauntTimer = 0
  self.tauntCooldown = 0
  self.currentTaunt = nil
  self.tauntDisplayTime = 0
  self.tauntDuration = 2.0
  self.tauntCooldownDuration = 3.0
  self.minTauntInterval = 3.0
  self.maxTauntInterval = 8.0
  self.nextTauntTime = love.math.random(self.minTauntInterval, self.maxTauntInterval)
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
  self.flashTime = 0
  -- Reset taunt system
  self.tauntTimer = 0
  self.tauntCooldown = 0
  self.currentTaunt = nil
  self.tauntDisplayTime = 0
  self.nextTauntTime = love.math.random(self.minTauntInterval, self.maxTauntInterval)
end

function Player:isBusy()
  return self.state == 'attacking' or self.state == 'dashing' or self.hitstun > 0
end

function Player:canTaunt()
  return self.alive and not self:isBusy() and self.tauntCooldown <= 0 and self.currentTaunt == nil
end

function Player:startTaunt()
  if not self:canTaunt() then return end
  
  -- Pick a random taunt message
  local tauntIndex = love.math.random(1, #TAUNT_MESSAGES)
  self.currentTaunt = TAUNT_MESSAGES[tauntIndex]
  self.tauntDisplayTime = 0
  
  
  -- Set cooldown
  self.tauntCooldown = self.tauntCooldownDuration
  
  -- Schedule next taunt
  self.nextTauntTime = love.math.random(self.minTauntInterval, self.maxTauntInterval)
end

function Player:updateTaunt(dt)
  -- Update taunt cooldown
  if self.tauntCooldown > 0 then
    self.tauntCooldown = math.max(0, self.tauntCooldown - dt)
  end
  
  -- Update current taunt display
  if self.currentTaunt then
    self.tauntDisplayTime = self.tauntDisplayTime + dt
    if self.tauntDisplayTime >= self.tauntDuration then
      self.currentTaunt = nil
      self.tauntDisplayTime = 0
    end
  end
  
  -- Check if it's time to taunt
  if self:canTaunt() then
    self.tauntTimer = self.tauntTimer + dt
    if self.tauntTimer >= self.nextTauntTime then
      self:startTaunt()
      self.tauntTimer = 0
    end
  else
    -- Reset timer if we can't taunt
    self.tauntTimer = 0
  end
  
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

function Player:attemptAttack(kind, simultaneousPressed, allowOnDead)
  if self.state == 'dashing' or self.hitstun > 0 then return end
  if self.state == 'attacking' then return end
  local atk
  if kind == 'light' then
    atk = ATTACKS.light
  elseif kind == 'heavy' then
    atk = ATTACKS.heavy
  elseif kind == 'hairball' then
    atk = ATTACKS.hairball
    -- Check stamina for hairball attack
    if self.stamina < atk.stamina then return end
    self.stamina = self.stamina - atk.stamina
  end
  -- Special: both attack buttons considered simultaneously
  if simultaneousPressed and self.stamina >= ATTACKS.special.stamina then
    atk = ATTACKS.special
    self.stamina = self.stamina - atk.stamina
  end
  if not atk then return end
  
  -- Play attack sound when attack is initiated
  if self.attackSoundCallback then
    self.attackSoundCallback()
  end
  
  self.state = 'attacking'
  self.attackData = atk
  self.attackPhase = 'startup'
  self.stateTimer = 0
  self.allowAttackOnDead = allowOnDead or false
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
  -- Spawn money at center of hurtbox
  local hb = self:getHurtbox()
  money:spawn(hb.x + hb.w / 2, hb.y + hb.h / 2, dir, atk.damage)
  -- Play hit sound
  if self.hitSoundCallback then
    self.hitSoundCallback()
  end
end

function Player:performFinishingMove(deadOpponent, atk)
  -- Signal to versus state that finishing move was performed
  if self.finishMoveCallback then
    self.finishMoveCallback(deadOpponent, atk)
  end
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
    if atk.name == 'hairball' then
      -- Spawn hairball projectile
      if self.hairballCallback then
        local spawnX = self.x + (self.facing * 30) -- spawn in front of player
        local spawnY = self.y - 20 -- slightly above player center
        self.hairballCallback(spawnX, spawnY, self.facing, self.id)
      end
    else
      -- Regular melee attack
      local hb = self:getHitbox()
      local canHit = (opponent.alive and opponent.hitstun <= 0) or (self.allowAttackOnDead and not opponent.alive)
      if canHit and aabb(hb, opponent:getHurtbox()) then
        if opponent.alive then
          opponent:takeHit(atk, self.facing)
        else
          -- Finishing move on dead opponent
          self:performFinishingMove(opponent, atk)
        end
      end
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
  local rangeX = 30 * 1.5 -- increased forward reach
  local hbWidth = 34 * 1.5
  local hbHeight = 48 * 1.5
  local x = base.x + (self.facing == 1 and (self.w + rangeX) or -(rangeX + hbWidth))
  local y = base.y + 20
  return { x = x, y = y, w = hbWidth, h = hbHeight }
end

function Player:update(dt, opponent, input, now, allowFinishingMove)
  -- Regenerate stamina
  if self.stamina < self.maxStamina and self.state ~= 'attacking' then
    self.stamina = math.min(self.maxStamina, self.stamina + self.staminaRegen * dt)
  end

  if self.invuln > 0 then self.invuln = math.max(0, self.invuln - dt) end
  if self.hitstun > 0 then
    self.hitstun = math.max(0, self.hitstun - dt)
  end
  
  -- Update flash timer
  if self.flashTime > 0 then
    self.flashTime = math.max(0, self.flashTime - dt)
    -- Keep invincibility during flash
    if self.flashTime > 0 then
      self.invuln = math.max(self.invuln, 0.01)
    end
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
    
    -- Flash/Invincibility (down key)
    if input:pressed(self.controls.down) and self.flashTime <= 0 then
      self.flashTime = self.flashDuration
    end

    local lightPressed = input:pressed(self.controls.light)
    local heavyPressed = input:pressed(self.controls.heavy)
    local hairballPressed = input:pressed(self.controls.hairball)
    if lightPressed or heavyPressed then
      local simultaneous = lightPressed and heavyPressed
      self:attemptAttack(lightPressed and 'light' or 'heavy', simultaneous, allowFinishingMove)
    elseif hairballPressed then
      self:attemptAttack('hairball', false, allowFinishingMove)
    end
  elseif not self.alive then
    -- Dead players stand in place - stop all movement
    self.velx = 0
    self.vely = 0
    self.state = 'idle'
    self.attackData = nil
    self.attackPhase = nil
    self.hitstun = 0
    self.invuln = 0
  end

  if self.state == 'dashing' then
    self.dashTime = self.dashTime + dt
    if self.dashTime >= self.dashDuration then
      self.state = 'idle'
      self.velx = 0
    end
  end

  self:updateAttack(dt, opponent)
  
  -- Update taunt system
  self:updateTaunt(dt)

  -- Apply knockback decay while in hitstun
  if self.hitstun > 0 then
    local decay = 6 -- higher = faster slowdown
    self.hitVelx = self.hitVelx * math.exp(-decay * dt)
    self.velx = self.hitVelx
  elseif self.hitstun == 0 and math.abs(self.hitVelx) > 1 then
    -- Reset after stun ends
    self.hitVelx = 0
  end

  -- Skip position updates during finishing move (handled by versus state)
  if not self.finishingMove then
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
end

function Player:draw()
  -- Update / select animation just before draw (after physics)
  self:updateAnimation(love.timer.getDelta())
  
  -- Calculate alpha for flashing effect
  local alpha = 1
  if self.invuln > 0 then
    if self.flashTime > 0 then
      -- Fast flashing during down key invincibility
      alpha = (math.sin(self.flashTime * 20) > 0) and 1 or 0.3
    else
      -- Normal invincibility flash (slower)
      alpha = 0.6
    end
  end
  
  if Player.sheet then
    local anim = ANIMS[self.anim]
    local frameId = anim.frames[self.animFrameIndex]
    local quad = Player.frames and Player.frames[frameId]
    local sx = self.facing == -1 and -1 or 1
    local ox = Player.frameW / 2
    local oy = Player.frameH
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(Player.sheet, quad, self.x, self.y, 0, sx, 1, ox, oy)
  else
    -- Fallback rectangle placeholder if sheet missing
    local hb = self:getHurtbox()
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
  
  -- Draw taunt text box
  if self.currentTaunt then
    self:drawTaunt()
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

function Player:drawTaunt()
  if not self.currentTaunt then return end
  
  -- Set up font for taunt text
  local font = love.graphics.newFont(16)
  love.graphics.setFont(font)
  
  -- Calculate text dimensions
  local textWidth = font:getWidth(self.currentTaunt)
  local textHeight = font:getHeight()
  
  -- Calculate bubble dimensions with padding
  local padding = 12
  local bubbleWidth = textWidth + padding * 2
  local bubbleHeight = textHeight + padding * 2
  
  -- Position bubble above player (ensure it's well above the player)
  local bubbleX = self.x - bubbleWidth / 2
  local bubbleY = self.y - self.h - bubbleHeight -240  -- Increased distance from player
  
  
  -- Calculate alpha based on remaining display time (fade out in last 0.5 seconds)
  local alpha = 1
  if self.tauntDisplayTime > self.tauntDuration - 0.5 then
    local fadeTime = self.tauntDisplayTime - (self.tauntDuration - 0.5)
    alpha = 1 - (fadeTime / 0.5)
  end
  
  -- Draw speech bubble background
  love.graphics.setColor(1, 1, 1, alpha * 0.95)
  love.graphics.rectangle('fill', bubbleX, bubbleY, bubbleWidth, bubbleHeight, 8, 8)
  
  -- Draw speech bubble border
  love.graphics.setColor(0.2, 0.2, 0.2, alpha)
  love.graphics.rectangle('line', bubbleX, bubbleY, bubbleWidth, bubbleHeight, 8, 8)
  
  -- Draw speech bubble tail (pointing down to player)
  local tailX = self.x
  local tailY = bubbleY + bubbleHeight
  local tailSize = 8
  love.graphics.setColor(1, 1, 1, alpha * 0.95)
  love.graphics.polygon('fill', 
    tailX, tailY,
    tailX - tailSize, tailY + tailSize,
    tailX + tailSize, tailY + tailSize
  )
  love.graphics.setColor(0.2, 0.2, 0.2, alpha)
  love.graphics.polygon('line', 
    tailX, tailY,
    tailX - tailSize, tailY + tailSize,
    tailX + tailSize, tailY + tailSize
  )
  
  -- Draw taunt text
  love.graphics.setColor(0.1, 0.1, 0.1, alpha)
  love.graphics.printf(self.currentTaunt, bubbleX + padding, bubbleY + padding, textWidth, 'center')
  
  -- Reset font
  love.graphics.setFont(love.graphics.newFont(12))
end

return Player
