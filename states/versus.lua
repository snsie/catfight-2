local Player = require('player')
local blood = require('effects.blood')

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
  self.players = {
    Player.new({ id = 1, x = 340, y = 640, color = { 0.9, 0.6, 0.2 }, controls = { left = 'a', right = 'd', up = 'w', down = 's', light = 'f', heavy = 'r' } }),
    Player.new({ id = 2, x = 940, y = 640, color = { 0.3, 0.7, 1.0 }, controls = { left = 'left', right = 'right', up = 'up', down = 'down', light = ';', heavy = "'" } }),
  }
end

function versus:restartRound()
  self.players[1]:resetForRound(340)
  self.players[2]:resetForRound(940)
  self.roundActive = false
  self.roundMessage = 'ROUND ' .. self.roundNumber
  self.roundMessageTime = 2
  self.timer = 0
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
  blood:update(dt)
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

  -- Blood FX (draw atop players for visibility)
  blood:draw()

  -- UI bars
  self:drawBars()

  -- Round message
  if self.roundMessageTime > 0 then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.roundMessage, 0, 120, 1280, 'center')
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

function versus:leave(ctx)
  -- Stop music when leaving the fight (victory, menu, etc.)
  if self.currentTheme and self.currentTheme:isPlaying() then
    self.currentTheme:stop()
  end
end

return versus
