-- conf.lua
-- LOVE configuration
function love.conf(t)
  t.identity = "catfight_2"
  t.version = "11.5"   -- Target LOVE version
  t.console = true
  t.window.title = "CatFight 2"
  t.window.width = 1280
  t.window.height = 720
  t.window.vsync = 1
end
