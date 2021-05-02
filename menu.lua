
local composer = require( "composer" )
local json = require("json")

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

local reset = 2
local resetButton

local music = audio.loadStream("assets/audio/menuLoop.wav")

local saveTable = {
  hiscore = 0,
  score = 0,
  level = 1,
  multiStage = 2,
  xStash = (centerX)
}

local function createNewFile()
  path = system.pathForFile("save.json", system.DocumentsDirectory)
  contents = json.encode(saveTable)
  file = io.open(path, 'w')
  file:write(contents)
  io.close(file)
  return true
end

local function fileExists()
  path = system.pathForFile("save.json", system.DocumentsDirectory)
  local f = io.open(path, 'r')
  if f ~= nil then
    print("Save file found.")
    io.close(f)
    return true
  else
    createNewFile()
    print("Save not found. Creating new save.")
    return false
  end
end

local function newGame()
  print("Starting new game...")
  if fileExists() and saveTable ~= nil then
    local path = system.pathForFile("save.json", system.DocumentsDirectory)
    local file2 = io.open(path, 'r')
    local contents2 = file2.read(file2, "*a")
    saveTable2 = json.decode(contents2)
    hiscoreTemp = saveTable.hiscore --saves old hiscore so that it is not overwritten
    io.close(file2)
    print("Old hiscore of "..hiscoreTemp.." transferred.")
    
    local file = io.open(path, 'w')
    saveTable.hiscore = hiscoreTemp
    saveTable.score = 0
    saveTable.level = 1
    saveTable.multiStage = 2
    saveTable.xStash = (centerX)
    local contents = json.encode(saveTable)
    file:write(contents)
    io.close(file)
  end
  composer.gotoScene("game")
  print("New file created.")
  return true
end

local function getSaveInfo()
  local path = system.pathForFile("save.json", system.DocumentsDirectory)
  if not fileExists() then
    print("Save not found!")
  end
  local file = io.open(path, 'r')
  contents = file.read(file, "*a")
  print("Save data found.")
  saveTable = json.decode(contents)
  io.close(file)
end

local function loadGame()
  print("Loading game...")
  print(saveTable.score)
  print(saveTable.level)
  composer.gotoScene("game")
end

--[[local function resetHs()
  if reset == 2 then
    local resetText = display.newText("Are you sure? Click again to confirm.", centerX, screenBottom-150)
    resetText.fill = {0}
    local function removeResetText()
      resetText:removeSelf()
      resetText = nil
      resetButton.fill.effect = "none"
      resetButton:addEventListener("tap", resetHs)
    end
    timer.performWithDelay(1500, removeResetText)
  elseif reset == 1 then
    local resetText = display.newText("Cleared.", centerX, screenBottom-150)
    resetText.fill = {0}
    local function removeResetText()
      resetText:removeSelf()
      resetText = nil
    end
    timer.performWithDelay(1500, removeResetText)
    
    if saveTable ~= nil then
      local file2 = io.open(path, 'r')
      contents = file2.read(file2, "*a")
      print(contents)
      saveTable = json.decode(contents)
      io.close(file2)
      
      local newST = {}
      
      newST.hiscore = 0
      newST.level = saveTable.level
      newST.score = saveTable.score
      newST.multiStage = saveTable.multiStage
      newST.xStash = saveTable.xStash
      
      file = io.open(path, 'w')
      contents = json.encode(newST)
      print(contents)
      file:write(contents)
    end
  end
  reset = reset - 1
  resetButton.fill.effect = "filter.grayscale"
  resetButton:removeEventListener("tap", resetHs)
end]]

--decided not to implement this, it kept corrupting my savefile for no reason at all and was a total pain to fix

-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

	local sceneGroup = self.view
	-- Code here runs when the scene is first created but has not yet appeared on screen
  
  audio.play(music, {loops = -1})
  audio.setVolume(0.5)
  
  local scrollSpeed = 5

  local bg = display.newImage(sceneGroup, "assets/img/menubg.png", centerX, centerY)
  local scaler = screenWidth / bg.width
  bg:scale(scaler, scaler*1.05)
  local moveMode = true

  local function move(event)
    if moveMode then
      bg.y = bg.y - scrollSpeed
    else
      bg.y = bg.y + scrollSpeed
    end
    if bg.y > 5000 or bg.y < -4000 then
      moveMode = not moveMode
    end
  end
  
  local logo = display.newImage(sceneGroup, "assets/img/logo.png", centerX, centerY-400)
  
  local newGameButton = display.newImage(sceneGroup, "assets/img/newgame.png", centerX, centerY-200)

  local loadGameButton = display.newImage(sceneGroup, "assets/img/loadgame.png", centerX, centerY)
  
  local savePadding = display.newRoundedRect(sceneGroup, centerX, centerY+350, 550, 300, 30)
  savePadding.fill = {0.3, 0.5, 1, 0.6}
  
  newGameButton:scale(1.5, 1.5)
  loadGameButton:scale(1.5, 1.5)
  
  --[[resetButton = display.newImage(sceneGroup, "assets/img/reset.png", screenLeft+5, screenBottom-5)
  resetButton.anchorX = 0
  resetButton.anchorY = 1]]
  
  getSaveInfo()
  
  if saveTable ~= nil then
    score = saveTable.score
    level = saveTable.level 
    if level ~= 1 then
      scoreStr = ("Current Score: "..score)
      levelStr = ("Current Level: "..level)
      
      local saveScore = display.newText(sceneGroup, scoreStr, centerX, centerY+300, native.systemFont, 60)
      local saveLevel = display.newText(sceneGroup, levelStr, centerX, centerY+400, native.systemFont, 60)
    
      loadGameButton:addEventListener("tap", loadGame)
    else
      local noSave = display.newText(sceneGroup, "No save found!", centerX, centerY+350, native.systemFont, 80)
      loadGameButton.fill.effect = "filter.grayscale"
    end
  else
    error("SAVE CORRUPT.")
  end
  
  newGameButton:addEventListener("tap", newGame)
  --resetButton:addEventListener("tap", resetHs)
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

	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)
  audio.stop()

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen
  Runtime:removeEventListener("enterFrame", move)

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
