local Player = require('player')
local money = require('effects.money')
local Hairball = require('hairball')

local versus = {}

function versus:enter(ctx)
  -- Music: randomly pick one of the available tracks each time we enter
  if not self.musicPool then
    self.musicPool = {}
    local candidates = {
      { path = 'audio/Theme_of_Felicia.mp3',  volume = 0.85 },
      { path = 'audio/fight_music_speed.mp3', volume = 0.85 }, -- add your 2nd track here
    }
    for _, m in ipairs(candidates) do
      if love.filesystem.getInfo(m.path) then
        local src = love.audio.newSource(m.path, 'stream')
        src:setLooping(true)
        src:setVolume(m.volume or 0.85)
        table.insert(self.musicPool, src)
      end
    end
  end
  if #self.musicPool > 0 then
    -- Stop any previously playing track (in case of re-entry without leave)
    if self.currentTheme and self.currentTheme:isPlaying() then self.currentTheme:stop() end
    self.currentTheme = self.musicPool[love.math.random(1, #self.musicPool)]
    if not self.currentTheme:isPlaying() then self.currentTheme:play() end
  end

  -- Load hiss sound effects
  if not self.hissSounds then
    self.hissSounds = {}
    local hissFiles = {
      'audio/hisses/meow_1.mp3',
      'audio/hisses/mixkit-angry-cartoon-kitty-meow-94.wav',
      'audio/hisses/shrt-meow-352842.mp3',
      'audio/hisses/mixkit-angry-wild-cat-roar-89.wav',
      'audio/hisses/bbc_cats-and-k_07045220.wav',
    }
    for _, path in ipairs(hissFiles) do
      if love.filesystem.getInfo(path) then
        local src = love.audio.newSource(path, 'static')
        src:setVolume(0.7)
        table.insert(self.hissSounds, src)
      end
    end
  end

  -- Load slap sound effects
  if not self.slapSounds then
    self.slapSounds = {}
    local slapFiles = {
      'audio/slaps/hard-slap-46388.mp3',
      'audio/slaps/slap-90128.mp3',
      'audio/slaps/smack-80173.mp3'
    }
    for _, path in ipairs(slapFiles) do
      if love.filesystem.getInfo(path) then
        local src = love.audio.newSource(path, 'static')
        src:setVolume(0.8)
        table.insert(self.slapSounds, src)
      end
    end
  end

  -- Background (load once)
  if not self.bg then
    if love.filesystem.getInfo('assets/backgrounds/alley.png') then
      self.bg = love.graphics.newImage('assets/backgrounds/alley.png')
      self.bg:setFilter('nearest', 'nearest')
    end
  end

  self.timer = 0
  self.roundTimer = 0
  self.roundMessage = 'ROUND 1'
  self.roundMessageTime = 2
  self.roundNumber = 1
  self.roundActive = false
  self.koTimer = 0
  self.koFreeze = 2
  self.startDelay = 1.2
  self.postRoundDelay = 2
  self.finishHimTimer = 0
  self.finishHimDuration = 3
  self.showFinishHim = false
  self.finishHimFont = love.graphics.newFont(64)
  self.finishMoveActive = false
  self.finishMoveTimer = 0
  self.finishMoveDuration = 20
  self.deadPlayerFlying = false
  self.flyingTimer = 0
  self.flyingDuration = 1
  self.bloodSpillActive = false
  self.bloodSpillTimer = 0
  self.hairballs = {} -- Array of active hairball projectiles
  self.players = {
    Player.new({ id = 1, x = 340, y = 640, color = { 0.9, 0.6, 0.2 }, controls = { left = 'a', right = 'd', up = 'w', down = 's', light = 'f', heavy = 'r', hairball = 'g' } }),
    Player.new({ id = 2, x = 940, y = 640, color = { 0.3, 0.7, 1.0 }, controls = { left = 'left', right = 'right', up = 'up', down = 'down', light = ';', heavy = "'", hairball = 'p' } }),
  }
  
  -- Set up finishing move callbacks
  self.players[1].finishMoveCallback = function(deadOpponent, atk) self:onFinishingMove(self.players[1], deadOpponent, atk) end
  self.players[2].finishMoveCallback = function(deadOpponent, atk) self:onFinishingMove(self.players[2], deadOpponent, atk) end
  
  -- Set up hit sound callbacks
  self.players[1].hitSoundCallback = function() self:playRandomHiss() end
  self.players[2].hitSoundCallback = function() self:playRandomHiss() end
  
  -- Set up attack sound callbacks
  self.players[1].attackSoundCallback = function() self:playRandomSlap() end
  self.players[2].attackSoundCallback = function() self:playRandomSlap() end
  
  -- Set up hairball callbacks
  self.players[1].hairballCallback = function(x, y, direction, ownerId) self:spawnHairball(x, y, direction, ownerId) end
  self.players[2].hairballCallback = function(x, y, direction, ownerId) self:spawnHairball(x, y, direction, ownerId) end
end

function versus:playRandomHiss()
  if self.hissSounds and #self.hissSounds > 0 then
    local randomIndex = love.math.random(1, #self.hissSounds)
    local sound = self.hissSounds[randomIndex]
    -- Clone the source to allow overlapping sounds
    local newSound = sound:clone()
    newSound:play()
  end
end

function versus:playRandomSlap()
  if self.slapSounds and #self.slapSounds > 0 then
    local randomIndex = love.math.random(1, #self.slapSounds)
    local sound = self.slapSounds[randomIndex]
    -- Clone the source to allow overlapping sounds
    local newSound = sound:clone()
    newSound:play()
  end
end

function versus:spawnHairball(x, y, direction, ownerId)
  local hairball = Hairball.new(x, y, direction, ownerId)
  table.insert(self.hairballs, hairball)
end

function versus:restartRound()
  self.players[1]:resetForRound(340)
  self.players[2]:resetForRound(940)
  self.roundActive = false
  self.roundMessage = 'ROUND ' .. self.roundNumber
  self.roundMessageTime = 2
  self.timer = 0
  self.showFinishHim = false
  self.finishHimTimer = 0
  self.finishMoveActive = false
  self.finishMoveTimer = 0
  self.deadPlayerFlying = false
  self.flyingTimer = 0
  self.bloodSpillActive = false
  self.bloodSpillTimer = 0
  self.hairballs = {} -- Clear all hairballs
  -- Clear finishing move flags
  self.players[1].finishingMove = false
  self.players[2].finishingMove = false
end

function versus:update(dt, ctx)
  local input = ctx.input
  if input:pressed('escape') then
    ctx.pushState('pause')
    return
  end

  self.timer = self.timer + dt

  if not self.roundActive then
    if self.timer >= self.startDelay then
      self.roundActive = true
      self.roundMessage = 'FIGHT!'
      self.roundMessageTime = 1
    end
  end

  -- Update message timer
  if self.roundMessageTime > 0 then
    self.roundMessageTime = self.roundMessageTime - dt
    if self.roundMessageTime < 0 then self.roundMessageTime = 0 end
  end

  local now = love.timer.getTime()
  local p1, p2 = self.players[1], self.players[2]

  if self.roundActive then
    p1:update(dt, p2, input, now)
    p2:update(dt, p1, input, now)
  elseif self.showFinishHim and not self.finishMoveActive then
    -- Allow finishing moves during "finish him" window
    local allowFinishingMove = true
    p1:update(dt, p2, input, now, allowFinishingMove)
    p2:update(dt, p1, input, now, allowFinishingMove)
  end

  -- Check round end
  if self.roundActive and (not p1.alive or not p2.alive) then
    self.roundActive = false
    self.roundMessage = 'KO!'
    self.roundMessageTime = self.koFreeze
    if p1.alive and not p2.alive then
      p1.roundsWon = p1.roundsWon + 1
    elseif p2.alive and not p1.alive then
      p2.roundsWon = p2.roundsWon + 1
    else
      -- Double KO: nobody gains round
    end
    self.koTimer = 0
    -- Show "finish him" banner
    self.showFinishHim = true
    self.finishHimTimer = 0
  end

  if self.roundMessage == 'KO!' then
    self.koTimer = self.koTimer + dt
    if self.koTimer >= self.koFreeze then
      -- Match end?
      local win
      for _, pl in ipairs(self.players) do
        if pl.roundsWon >= 2 then win = pl end
      end
      if win then
        ctx.switchState('victory', false, win)
        return
      else
        -- Next round
        self.roundNumber = self.roundNumber + 1
        self:restartRound()
      end
    end
  end

  -- Update "finish him" banner timer
  if self.showFinishHim then
    self.finishHimTimer = self.finishHimTimer + dt
    if self.finishHimTimer >= self.finishHimDuration then
      self.showFinishHim = false
    end
  end

  -- Update finishing move effects
  if self.finishMoveActive then
    self.finishMoveTimer = self.finishMoveTimer + dt
    
    -- Update flying animation
    if self.deadPlayerFlying then
      self.flyingTimer = self.flyingTimer + dt
      local progress = math.min(1, self.flyingTimer / self.flyingDuration)
      
      -- Find the dead player and animate them flying to center
      local deadPlayer = nil
      for _, p in ipairs(self.players) do
        if not p.alive then deadPlayer = p break end
      end
      
      if deadPlayer then
        -- Smooth interpolation to center
        deadPlayer.x = self.deadPlayerStartX + (self.deadPlayerTargetX - self.deadPlayerStartX) * progress
        deadPlayer.y = self.deadPlayerStartY + (self.deadPlayerTargetY - self.deadPlayerStartY) * progress
      end
      
      if self.flyingTimer >= self.flyingDuration then
        self.deadPlayerFlying = false
        self.bloodSpillActive = true
        self.bloodSpillTimer = 0
      end
    end
    
    -- Update money spill
    if self.bloodSpillActive then
      self.bloodSpillTimer = self.bloodSpillTimer + dt
      -- Spawn continuous money
      if self.bloodSpillTimer % 0.1 < dt then -- Every 0.1 seconds
        local centerX = 640
        local centerY = 360
        money:spawn(centerX + love.math.random(-50, 50), centerY + love.math.random(-30, 30), 
                   love.math.random(-1, 1), 20)
      end
    end
    
    -- End finishing move after duration
    if self.finishMoveTimer >= self.finishMoveDuration then
      self.finishMoveActive = false
      self.bloodSpillActive = false
      -- Proceed to next round or match end
      local win
      for _, pl in ipairs(self.players) do
        if pl.roundsWon >= 2 then win = pl end
      end
      if win then
        ctx.switchState('victory', false, win)
        return
      else
        self.roundNumber = self.roundNumber + 1
        self:restartRound()
      end
    end
  end
  
  -- Update hairballs
  for i = #self.hairballs, 1, -1 do
    local hairball = self.hairballs[i]
    hairball:update(dt)
    
    -- Check collision with players
    if hairball:isActive() then
      for _, player in ipairs(self.players) do
        -- Don't hit the player who shot the hairball
        if player.id ~= hairball:getOwnerId() and player.alive and player.invuln <= 0 then
          local hairballBox = hairball:getHitbox()
          local playerBox = player:getHurtbox()
          
          -- Simple AABB collision detection
          if hairballBox.x < playerBox.x + playerBox.w and 
             hairballBox.x + hairballBox.w > playerBox.x and
             hairballBox.y < playerBox.y + playerBox.h and 
             hairballBox.y + hairballBox.h > playerBox.y then
            
            -- Hit the player
            local attackData = {
              damage = hairball:getDamage(),
              knockback = hairball:getKnockback()
            }
            player:takeHit(attackData, hairball:getDirection())
            
            -- Remove the hairball
            hairball.active = false
            break
          end
        end
      end
    end
    
    -- Remove inactive hairballs
    if not hairball:isActive() then
      table.remove(self.hairballs, i)
    end
  end
  
  money:update(dt)
end

function versus:draw(ctx)
  love.graphics.clear(0, 0, 0, 1)
  -- Background stage
  if self.bg then
    local sw, sh = self.bg:getDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    -- Stretch independently to fully cover (no letterboxing, no cropping)
    love.graphics.draw(self.bg, 0, 0, 0, 1280 / sw, 720 / sh)
  else
    love.graphics.setColor(0.02, 0.02, 0.03, 1)
    love.graphics.rectangle('fill', 0, 0, 1280, 720)
  end
  love.graphics.setColor(1, 1, 1, 1)

  -- Draw players
  for _, p in ipairs(self.players) do p:draw() end

  -- Draw hairballs
  for _, hairball in ipairs(self.hairballs) do
    hairball:draw()
  end

  -- Money FX (draw atop players for visibility)
  money:draw()

  -- UI bars
  self:drawBars()

  -- Round message
  if self.roundMessageTime > 0 then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.roundMessage, 0, 120, 1280, 'center')
  end

  -- "Finish Him" banner
  if self.showFinishHim then
    self:drawFinishHimBanner()
  end
  
end

function versus:drawBars()
  local p1, p2 = self.players[1], self.players[2]
  local function bar(x, y, w, h, ratio, color)
    love.graphics.setColor(0.15, 0.15, 0.2, 1)
    love.graphics.rectangle('fill', x, y, w, h, 4, 4)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle('fill', x + 2, y + 2, (w - 4) * ratio, h - 4, 4, 4)
  end
  local w = 420
  bar(40, 40, w, 24, p1.health / p1.maxHealth, p1.color)
  bar(40, 72, w, 16, p1.stamina / p1.maxStamina, { 0.4, 0.8, 1 })
  -- Rounds
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(string.rep('●', p1.roundsWon) .. string.rep('○', 2 - p1.roundsWon), 40, 98)

  bar(1280 - w - 40, 40, w, 24, p2.health / p2.maxHealth, p2.color)
  bar(1280 - w - 40, 72, w, 16, p2.stamina / p2.maxStamina, { 0.4, 0.8, 1 })
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(string.rep('●', p2.roundsWon) .. string.rep('○', 2 - p2.roundsWon), 1280 - w - 40, 98)
end

function versus:onFinishingMove(attacker, deadOpponent, atk)
  print("FINISHING MOVE TRIGGERED!")
  print("Attacker:", attacker.id, "Dead player:", deadOpponent.id)
  print("Dead player position:", deadOpponent.x, deadOpponent.y)
  
  -- Start the finishing move sequence
  self.finishMoveActive = true
  self.finishMoveTimer = 0
  self.showFinishHim = false
  
  -- Mark dead player as in finishing move
  deadOpponent.finishingMove = true
  
  -- Start flying animation
  self.deadPlayerFlying = true
  self.flyingTimer = 0
  
  -- Store original position for flying animation
  self.deadPlayerStartX = deadOpponent.x
  self.deadPlayerStartY = deadOpponent.y
  self.deadPlayerTargetX = 640 -- Center of screen
  self.deadPlayerTargetY = 360
  
  print("Flying animation started from", self.deadPlayerStartX, self.deadPlayerStartY, "to", self.deadPlayerTargetX, self.deadPlayerTargetY)
end

function versus:drawFinishHimBanner()
  local catText = "FINISH HIM! 🐱"
  
  -- Set the large font
  love.graphics.setFont(self.finishHimFont)
  
  -- Bright red color with pulsing effect
  local pulse = 0.8 + 0.2 * math.sin(self.finishHimTimer * 6)
  love.graphics.setColor(1, 0.2, 0.2, pulse)
  love.graphics.printf(catText, 0, 300, 1280, 'center')
  
  -- Add instruction text below
  love.graphics.setFont(love.graphics.newFont(24))
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.printf("Press ATTACK to perform finishing move!", 0, 380, 1280, 'center')
  
  -- Reset color and font
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(love.graphics.newFont(12))
end

function versus:leave(ctx)
  -- Stop music when leaving the fight (victory, menu, etc.)
  if self.currentTheme and self.currentTheme:isPlaying() then
    self.currentTheme:stop()
  end
end

return versus
