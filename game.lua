
local composer = require( "composer" )

local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

centerX = display.contentCenterX
centerY = display.contentCenterY

screenLeft = display.screenOriginX
screenWidth = display.contentWidth - screenLeft * 2
screenRight = screenLeft + screenWidth
screenTop = display.screenOriginY
screenHeight = display.contentHeight - screenTop * 2
screenBottom = screenTop + screenHeight

display.contentWidth = screenWidth
display.contentHeight = screenHeight

--[[todo:
pick a theme
graphics sigh
music/audio
instructions
new mechanic????
]]--

local physics = require("physics")
local json = require("json")

local ball --forward references
local goal
local levelText
local scoreText
local level = 1 --defaults
local score = 0
local hiscore = 0
local potScore = 0 --potential score in a run
local multiplierSet = {0, 100, 50, 25, 10, 5, 3, 2, 1, 1, 0.5} --turn multiplier, needs a buffer item for some reason?
local multiStage = 2 --index of multiplier in multiplierSet, again needs to be started at first index + 1
local xStash = 0 --used to store last xvalue of ball after dropping
local playReady = true

local goalImg = {type = "image", filename = "assets/img/goal.png"}

local ballImg = {type = "image", filename = "assets/img/ball.png"}

local onImg = {type = "image", filename = "assets/img/on.png"}
local offImg1 = {type = "image", filename = "assets/img/off1.png"}
local offImg2 = {type = "image", filename = "assets/img/off2.png"}
local offImg3 = {type = "image", filename = "assets/img/off3.png"}
local offImg4 = {type = "image", filename = "assets/img/off4.png"}
local offImg5 = {type = "image", filename = "assets/img/off5.png"}

local offImgSet = {offImg1, offImg2, offImg3, offImg4, offImg5}

local pegGroup

physics.start()
physics.setGravity(0, 9.8)
physics.setDrawMode("normal")

math.randomseed(os.time())

pixelFont = "assets/fonts/pixelFont.ttf"
funFont = "assets/fonts/funFont.otf"

on = audio.loadSound("assets/audio/on1.wav")
miss = audio.loadSound("assets/audio/miss.wav")
win = audio.loadSound("assets/audio/win.wav")
off1 = audio.loadSound("assets/audio/off1.wav")
off2 = audio.loadSound("assets/audio/off2.wav")
off3 = audio.loadSound("assets/audio/off3.wav")
pop = audio.loadSound("assets/audio/in.wav")
overlap = audio.loadSound("assets/audio/overlap.wav")
ready = audio.loadSound("assets/audio/ready.wav")
gameover = audio.loadSound("assets/audio/gameover.wav")

off = {off1, off2, off3}

music = audio.loadStream("assets/audio/gameLoop.wav")
audio.play(music, {channel = 2, loops = -1})

audio.setVolume(0.5, {channel = 2})

audio.setVolume(0.5)

local locked = false

scrollSpeed = 1
local gamebg = display.newImage("assets/img/gamebg.png", centerX, centerY)
gamebg.alpha = 0.2
local scaler = screenWidth / gamebg.width
gamebg:scale(scaler, scaler)
local moveMode = true

local function checkGameWin(level)
  if level > 10 then
    local function exitGame()
      os.exit()
    end
    scrollSpeed = 0
    physics.stop()
    audio.stop()
    audio.play(gameover)
    local padding = display.newRoundedRect(centerX, centerY, 750, 500, 20)
    padding.alpha = 0.4
    local winText = display.newText("All levels complete!", centerX, centerY-200, pixelFont, 60)
    winText.fill = {1, 0, 0}
    local finalScoreStr = ("Score: "..score)
    local finalScoreText = display.newText(finalScoreStr, centerX, centerY, pixelFont, 100)
    winText.fill = {0, 1, 0}
    local thanks = display.newText("Thanks for playing! <3", centerX, centerY+200, pixelFont, 60)
    thanks.fill = {0, 0, 1}
    
    timer.performWithDelay(8000, exitGame)
    return true
  end
  return false
end


local function move(event)
  if moveMode then
    gamebg.y = gamebg.y - scrollSpeed
  else
    gamebg.y = gamebg.y + scrollSpeed
  end
  if gamebg.y > 5000 or gamebg.y < -4000 then
    moveMode = not moveMode
  end
end

local function checkSameSpot()
  for i = 1, pegGroup.numChildren do
    for j = 1, pegGroup.numChildren do
      if i ~= j then
        if pegGroup[i].x == pegGroup[j].x and pegGroup[i].y == pegGroup[j].y then
          return true
        end
      end
    end
  end
  return false
end

local function update(mode)
  if mode == 1 then
    local scoreStr = ("Score: "..score)
    local hiStr = ("High: "..hiscore)
    local levelStr = ("Level "..level)
    scoreText.text = scoreStr
    hiScoreText.text = hiStr
    levelText.text = levelStr
  elseif mode == 2 then
    potStr = ("+"..potScore)
    potScoreText.text = potStr
    multiStr = ("×"..multiplierSet[multiStage])
    multiText.text = multiStr
  elseif mode == 3 then
    update(1)
    update(2) --recursive function wooo
  end
end

local function randFill()
  x = math.random(1, #offImgSet)
  return offImgSet[x]
end

local function makePeg(count)
  local function genPeg()
    local x = math.random(screenLeft + 100, screenRight - 100)
    local y = math.random(screenTop + 250, screenBottom - 280)
    
    peg = display.newCircle(x, y, 40)
    peg.fill = randFill()
    peg.name = "peg"
    peg.hit = false
    
    --peg.touch = movePeg
    peg.collision = processHit
    
    physics.addBody(peg, "static", {density = 1, friction = 1, bounce = 1, radius = peg.path.radius})
    pegGroup:insert(peg)
    
    peg:addEventListener("touch", peg)
    peg:addEventListener("collision", peg)
    
    local function check(self)
      moved = false
      if (self.x - self.path.radius <= screenLeft) then
        self.x = screenLeft + self.path.radius
        moved = true
      elseif (self.x + self.path.radius >= screenRight) then
        self.x = screenRight - self.path.radius
        moved = true
      end
      if (self.y - self.path.radius * 2 <= centerY - 600) then
        self.y = centerY - 600 + self.path.radius * 2
        moved = true
      elseif (self.y + self.path.radius * 2 >= centerY + 550) then
        self.y = centerY + 550 - self.path.radius * 2
        moved = true
      end
      return moved
    end
    
    function peg:touch(event)
      if not locked then
        if (event.phase == "began") then
          self.oldx = self.x
          self.oldy = self.y
          display.getCurrentStage():setFocus(self)
          self.hasFocus=true
        elseif (self.hasFocus) then
          if (event.phase == "moved") then
            self.x = (event.x - event.xStart) + self.oldx
            self.y = (event.y - event.yStart) + self.oldy
            check(self)
          elseif (event.phase == "ended" or event.phase == "cancelled") then
            display.getCurrentStage():setFocus(nil)
            self.hasFocus = false
            if checkSameSpot() then
              print("Pegs overlapped! Relocating...")
              audio.play(overlap)
              while check(self) do --repeat until in bounds
                self.x = self.x + math.random(-30, 30)
                self.y = self.y + math.random(-30, 30)
              end
            end
          end
        end
      end
      return true
    end
    
    peg = nil
    audio.play(pop)
    
    return true
  end

  if not checkGameWin(count) then
    for i = 1, count+1 do
      timer.performWithDelay((((count+1)*500)-(i*500)), genPeg) --supposed to get faster as more pegs are generated but idk if it works
    end
  end
    
  return true
end

local function nextLevel() --needs to be outside reset() for resetSaveState() to access
  for i = 1, pegGroup.numChildren do
    pegGroup:remove(pegGroup[1])
  end
  pegGroup.alpha = 1
  makePeg(level)
  if score > hiscore then
    hiscore = score
  end
  update(1)
  local levelStr = ("Level "..level)
  if level <= 10 then
    levelText.text = levelStr
  else
    --game over
  end
  return true
end

local function moveBall(self,event)
  if not locked then
    if (event.phase == "began") then
      self.oldx = self.x
      display.getCurrentStage():setFocus(self)
      self.hasFocus=true
    elseif (self.hasFocus) then
      if (event.phase == "moved") then
        self.x = (event.x - event.xStart) + self.oldx
        if (self.x - self.path.radius <= screenLeft) then --too far left
          self.x = screenLeft + self.path.radius + 1 
        elseif (self.x + self.path.radius >= screenRight) then --too far right
          self.x = screenRight - self.path.radius - 1
        end
      elseif (event.phase == "ended" or event.phase == "cancelled") then
        display.getCurrentStage():setFocus(nil)
        self.hasFocus = false
      end
    end
  end
  return true
end

local function checkWin(lastHitGoal)
  local win = lastHitGoal
  for i = 1, pegGroup.numChildren do
    if pegGroup[i].hit == false then
      win = false
    end
  end
  return win
end

local function reset(lastHitGoal)
  
  scrollSpeed = 1
  goal.fill.effect = "filter.grayscale"
  playReady = true
  
  local win = checkWin(lastHitGoal)
  
  if win then
    score = score + (potScore * multiplierSet[multiStage])
    level = level + 1
    multiStage = 1
  else
    potScore = 0
    if multiStage < #multiplierSet then
      multiStage = multiStage + 1
    end
  end
  
  local function makeStatic(win)
    if win then
      print("hit")
      ball.x, ball.y = centerX, centerY-650
    else
      print("miss")
      ball.x, ball.y = xStash, centerY-650 --last position
    end
    ball.bodyType="static"
    ball:addEventListener("touch", ball) --neccesary?
  end
  
  transition.to(ball, {time = 250, alpha=0, onComplete = makeStatic})
  transition.to(ball, {delay= 300, time=500, alpha=1})
  
  local function clearPegs()
    for i = 1, pegGroup.numChildren do
      pegGroup[i].hit = false
      pegGroup[i].fill = randFill()
    end
    return true
  end
  
  if win then --if level pass
    clearPegs() -- needs to check before clearing or the logic fails
    transition.to(pegGroup, {time = 250, alpha=0, onComplete=nextLevel})
  else
    clearPegs()
  end

  locked = false
  update(2)
  return true
  
end

local function drop(self, event)
  self.dead = false
  xStash = self.x
  self.bodyType = "dynamic"
  locked = true
  return true
end

local function processHit(self, event)
  obj = event.other
  if event.phase == "began" and not self.dead then
    print("Ball collided with "..obj.name)
    if obj.name == "peg" then
      if obj.hit == false then
        obj.fill = onImg
        obj.hit = true
        audio.play(on)
        potScore = potScore + (10 + level * 10) --hit fresh peg
      else
        audio.play(off[math.random(1, #off)])
        potScore = (potScore + 10) --hit stale peg
      end
      potStr = ("+"..potScore)
      potScoreText.text = potStr
      if checkWin(true) then --check if all pegs hit
        scrollSpeed = 3
        goal.fill.effect = "filter.brightness" --clears filter
        if playReady then
          audio.play(ready)
        end
        playReady = false
      end
    elseif obj.name == "ground" or obj.name == "goal" or obj.name == "wall" then --maybe disable once hit object to avoid double sound?
      if event.other.name == "goal" and checkWin(true) then
        audio.play(win)
        reset(true)
      else
        ball.dead = true
        audio.play(miss)
      end
      reset(false)
    end
  end
  return true
end

local function newGame()
  level = 1
  score = 0
  potScore = 0
  multiStage = 2
  startGame()
end

local function startGame()
  makePeg(level)
end

local function fileExists()
  path = system.pathForFile("save.json", system.DocumentsDirectory)
  local f = io.open(path, 'r')
  if f ~= nil then
    io.close(f)
    return true
  end
  return false
end

local function saveState()
  local path = system.pathForFile("save.json", system.DocumentsDirectory)
  local file = io.open(path, 'w')
  saveTable = {
    hiscore = hiscore,
    score = score,
    level = level,
    multiStage = multiStage,
    xStash = ball.x
  }
  local contents = json.encode(saveTable)
  print("File saved!")
  file:write(contents)
  io.close(file)
  return true
end

local function loadSavedState()
  local path = system.pathForFile("save.json", system.DocumentsDirectory)
  local file = io.open(path, 'r')
  local contents = file.read(file, "*a")
  saveTable = json.decode(contents)
  hiscore = saveTable.hiscore
  print("File loaded!\t Score: "..score.."\t Level: "..level)
  score = saveTable.score
  level = saveTable.level
  multiStage = saveTable.multiStage
  io.close(file)
  update(3)
  return true
end

local function resetSaveState()
  local path = system.pathForFile("save.json", system.DocumentsDirectory)
  local file = io.open(path, 'w')
  saveTable = {
    hiscore = 0,
    score = 0,
    level = 1,
    multiStage = 2
  }
  local contents = json.encode(saveTable)
  file:write(contents)
  hiscore = saveTable.hiscore
  score = saveTable.score
  level = saveTable.level
  multiStage = saveTable.multiStage
  io.close(file)
  nextLevel()
  update(3)
  return true
end

local function onSystemEvent(event)
  if event.type == "applicationExit" then
    print("Saving data...")
    saveState()
    print("Save complete.")
  --[[elseif event.type == "applicationStart" then
    print("Loading save data...")
    loadSavedState()
    update(1)
    print("Loading complete!")]] --already handled by menu function
  end
end

local function randOff(event)
  if pegGroup ~= nil then
    for i = 1, pegGroup.numChildren do
      if pegGroup[i].hit == false then
        pegGroup[i].fill = randFill()
      end
    end
  end
end

timer.performWithDelay(200, randOff, 0)
-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

	local sceneGroup = self.view
  -- Code here runs when the scene is first created but has not yet appeared on screen
  
  physics.pause()
  
  pegGroup = display.newGroup()
  
  local ground = display.newRect(centerX, screenBottom+10, screenWidth, 20)
  physics.addBody(ground, "static", {density = 1, friction = 1, bounce = 1})
  ground.name = "ground"
  ground.fill = {0.5}

  goal = display.newRect(centerX, screenBottom-80, 200, 150)
  physics.addBody(goal, "static", {density = 1, friction = 1, bounce = 1})
  goal.name = "goal"
  goal.fill = goalImg
  goal.fill.effect = "filter.grayscale"

  local leftBorder = display.newRect(screenLeft, centerY, 1, screenHeight)
  physics.addBody(leftBorder, "static", {density = 1, friction = 1, bounce = 1})
  leftBorder.name = "wall"
  leftBorder.isVisible = false

  local rightBorder = display.newRect(screenRight, centerY, 1, screenHeight)
  physics.addBody(rightBorder, "static", {density = 1, friction = 1, bounce = 1})
  rightBorder.name = "wall"
  rightBorder.isVisible = false

  ball = display.newCircle(centerX, centerY-650, 50)
  ball.name = "ball"
  ball.dead = false
  ball.tap = drop
  ball.touch = moveBall
  ball.collision = processHit
  -- at some point, add fail condition if ball falls asleep (ball.isAwake() == false)
  physics.addBody(ball, "static", {density = 10, friction = 0.3, bounce = 0.2, radius = ball.path.radius})
  ball.fill = ballImg

  levelText = display.newText(("Level "..level), centerX-380, centerY-675, pixelFont, 60) --needs to be drawn above everything anyway
  levelText.anchorX = 0
  levelText.fill = {0, 0.5, 1, 0.5}

  hiScoreText = display.newText(("High: "..hiscore), centerX+380, centerY-675, pixelFont, 60) --needs to be drawn above everything anyway
  hiScoreText.anchorX = 1
  hiScoreText.fill = {1, 1, 0, 0.5}

  scoreText = display.newText(("Score: "..score), centerX+380, centerY-625, pixelFont, 60) --needs to be drawn above everything anyway
  scoreText.anchorX = 1
  scoreText.fill = {0.5, 0, 1, 0.5}

  potScoreText = display.newText(("+"..potScore), centerX+380, centerY-575, pixelFont, 60) --needs to be drawn above everything anyway
  potScoreText.anchorX = 1
  potScoreText.fill = {0.5, 0, 1, 0.5}

  multiText = display.newText(("×"..multiplierSet[multiStage]), centerX+380, centerY-525, pixelFont, 60) --needs to be drawn above everything anyway
  multiText.anchorX = 1
  multiText.fill = {0.5, 0, 1, 0.5}
  
  loadSavedState()
  
  update(3)
  
  ball:addEventListener("tap", ball)
  ball:addEventListener("touch", ball)
  ball:addEventListener("collision", ball)
  
  Runtime:addEventListener("system", onSystemEvent)
  Runtime:addEventListener("enterFrame", move)
end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
    physics.start()
    timer.performWithDelay(1000, startGame)

	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen

	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view

end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene
