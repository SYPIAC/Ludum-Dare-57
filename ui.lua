-- UI module for FOREMAN
-- All rendering functionality

-- Define the UI module
local ui = {}

-- Constants needed for rendering (imported from main.lua)
local SCREEN_WIDTH = 520
local SCREEN_HEIGHT = 800
local CARD_WIDTH = 48
local CARD_HEIGHT = 96
local GRID_CELL_SIZE = CARD_WIDTH
local GRID_CELL_HEIGHT = CARD_HEIGHT
local GRID_OFFSET_X = 24
local GRID_OFFSET_Y = 40
local GRID_COLS = 10
local GRID_ROWS = 7
local HAND_HEIGHT = 200
local FIELD_HEIGHT = SCREEN_HEIGHT - HAND_HEIGHT
local STATUS_BAR_WIDTH = 120
local FIELD_WIDTH = SCREEN_WIDTH - STATUS_BAR_WIDTH
local GAME_FIELD_WIDTH_EXTENSION = 3
local GAME_FIELD_DEPTH = 100
local SURFACE_LEVEL = 0
local DEEP_MINE_LEVEL = 10

-- Colors
local COLORS = {
    background = {0, 0, 0},        -- Black
    grid_line = {0.3, 0.3, 0.4, 0.7},
    grid_symbol = {0.6, 0.6, 0.6}, -- Light gray for +
    hand_bg = {0.5, 0.3, 0.2},     -- Brown for hand area
    status_bar = {0, 0, 0},        -- Black for status bar
    top_bar = {0.5, 0.3, 0.2},     -- Brown for top bar
    text = {1, 1, 1},              -- White text
    highlight = {0.5, 0.5, 0.7, 0.3}, -- Bluish highlight
    surface = {0.6, 0.4, 0.2},     -- Brown for surface (above ground)
    deep_mine = {0.3, 0.3, 0.35},  -- Grayish for deep mine
    hold_border = {1, 0.8, 0},     -- Gold for held card border
    hand_card_border = {1, 1, 1},  -- White for card border in hand
    golden_field_border = {219/255, 202/255, 135/255}, -- Golden border around play field
    clock_face = {1, 1, 0},        -- Yellow for clock face
    clock_segment_used = {0, 0, 0}, -- Black for used clock segments
    clock_dividers = {0.5, 0.5, 0.5}, -- Gray for clock segment dividers
    planned_overlay = {0.5, 0.5, 0.5, 0.8}, -- Semi-transparent gray for planned cards
    positive = {0, 1, 0}, -- Green for positive numbers
    negative = {1, 0, 0}  -- Red for negative numbers
}

-- Shared reference to game state and assets (will be set from main.lua)
local game = nil
local assets = nil
local viewport = nil
local DIRECTION = nil
local predictAliveAndHoldCapacity = nil
local story = require("story")  -- Add the story module requirement
local cards = require("cards")  -- Add the cards module requirement
local gameLogic = require("gameLogic")  -- Add the gameLogic module requirement

-- Hover states for deck/discard UI
local deckHover = false
local discardHover = false

-- UI assets
local dangerImage = nil -- Image for danger tile overlay
local vignetteImage = nil -- Vignette image for bottom right corner
local tlVignetteImage = nil -- Vignette image for top left corner
local trVignetteImage = nil -- Vignette image for top right corner
local blVignetteImage = nil -- Vignette image for bottom left corner
local backgroundMapImage = nil -- Background map image for tiling over game field

-- Initialize the UI module with references to game state and assets
function ui.init(gameState, gameAssets, viewportState, directionEnum, buttonTable)
    game = gameState
    assets = gameAssets
    viewport = viewportState
    DIRECTION = directionEnum
    buttons = buttonTable  -- Assign the passed buttons table
    
    -- Load UI specific assets
    dangerImage = love.graphics.newImage("img/danger.png")
    vignetteImage = love.graphics.newImage("img/ui/BRVignette.png")
    tlVignetteImage = love.graphics.newImage("img/ui/TLVignette.png")
    trVignetteImage = love.graphics.newImage("img/ui/TRVignette.png")
    blVignetteImage = love.graphics.newImage("img/ui/BLVignette.png")
    backgroundMapImage = love.graphics.newImage("img/ui/background_map.png")
    
    -- Set up references to any prediction functions
    predictAliveAndHoldCapacity = _G.predictAliveAndHoldCapacity
    
    -- Initialize the story module
    story.init(game, assets)
end

-- Helper function to draw a tiled background image
function ui.drawTiledBackground(x, y, width, height)
    if not assets.backgroundImage then return end
    
    love.graphics.setColor(1, 1, 1)
    local imgWidth = assets.backgroundImage:getWidth()
    local imgHeight = assets.backgroundImage:getHeight()
    
    -- Calculate how many tiles we need in each direction
    local tilesX = math.ceil(width / imgWidth)
    local tilesY = math.ceil(height / imgHeight)
    
    -- Draw the background tiles
    for tileX = 0, tilesX - 1 do
        for tileY = 0, tilesY - 1 do
            love.graphics.draw(
                assets.backgroundImage,
                x + tileX * imgWidth,
                y + tileY * imgHeight
            )
        end
    end
end

-- Main drawing function
function ui.draw()
    -- Set background color
    love.graphics.setBackgroundColor(unpack(COLORS.background))
    
    -- Draw the field with appropriate biome backgrounds
    ui.drawField()
    
    -- Draw the tiled background map over the game field
    ui.drawTiledGameField()
    
    -- Draw the field grid
    ui.drawFieldGrid()
    
    -- Draw cards placed on the field
    ui.drawFieldCards()
    
    -- Draw danger tile overlays (on top of cards)
    ui.drawDangerTileOverlays()
    
    -- Draw golden border around the play field
    love.graphics.setColor(unpack(COLORS.golden_field_border))
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 0, 40, FIELD_WIDTH, FIELD_HEIGHT - 40)
    love.graphics.setLineWidth(1)
    
    -- Draw vignettes in all four corners of the game field
    ui.drawVignettes()
    
    -- Draw status bar
    ui.drawStatusBar()
    
    -- Draw hand area
    ui.drawHandArea()
    
    -- Draw the card being dragged (on top of everything)
    if game.dragging then
        ui.drawCard(game.dragging, true)
    end
    
    -- DEBUG: Draw card outline to verify grid alignment
    if game.dragging and love.mouse.getY() < FIELD_HEIGHT then
        local gridX, gridY = ui.screenToGrid(love.mouse.getX(), love.mouse.getY())
        local x, y = ui.gridToScreen(gridX, gridY)
        -- Only show outline if not behind status bar
        if x + CARD_WIDTH <= FIELD_WIDTH and x >= 0 and y >= 40 and y <= FIELD_HEIGHT then
            -- Check if placement is valid and show appropriate color
            local isValidPlacement = ui.canPlaceCard(game.dragging.type, gridX, gridY, game.dragging.flipped)
            if isValidPlacement then
                love.graphics.setColor(0, 1, 0, 0.5)  -- Green for valid placement
            else
                love.graphics.setColor(1, 0, 0, 0.5)  -- Red for invalid placement
            end
            love.graphics.rectangle("line", x, y, CARD_WIDTH, CARD_HEIGHT)
        end
    end
    
    -- Draw invalid placement feedback if needed
    if game.invalidPlacement then
        local x, y = ui.gridToScreen(game.invalidPlacement.x, game.invalidPlacement.y)
        love.graphics.setColor(1, 0, 0, game.invalidPlacement.time * 2)  -- Red with fading alpha
        love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT)
    end
    
    -- Draw top brown bar (always on top)
    love.graphics.setColor(unpack(COLORS.top_bar))
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, 40)
    
    -- Draw player information text about card limits
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.setFont(assets.font)

    -- Calculate predicted values for display
    local predictedAliveTiles, predictedHoldCapacity, _ = predictAliveAndHoldCapacity()
    predictedAliveTiles = math.min(predictedAliveTiles, 7)
    local aliveTilesDiff = predictedAliveTiles - math.min(game.shiftStartAliveTilesCount, 7)
    local holdCapacityDiff = predictedHoldCapacity - game.currentHoldCapacity

    -- Format change indicators with colors
    local playChangeText = ""
    if aliveTilesDiff > 0 then
        love.graphics.setColor(unpack(COLORS.positive))
        playChangeText = "(+" .. aliveTilesDiff .. ")"
    elseif aliveTilesDiff < 0 then
        love.graphics.setColor(unpack(COLORS.negative))
        playChangeText = "(" .. aliveTilesDiff .. ")"
    end

    -- Display play count with change indicator
    local playText = string.format("You can play %d/%d", game.playCount, game.maxPlayCards)
    love.graphics.printf(playText, 10, 10, FIELD_WIDTH/2 - 20, "center")
    if playChangeText ~= "" then
        local playTextWidth = assets.font:getWidth(playText)
        local x = 10 + FIELD_WIDTH/4 + playTextWidth/2 + 5
        love.graphics.printf(playChangeText, x, 10, 50, "left")
    end

    -- Format hold change indicator with colors
    local holdChangeText = ""
    love.graphics.setColor(unpack(COLORS.text)) -- Reset color
    if holdCapacityDiff > 0 then
        love.graphics.setColor(unpack(COLORS.positive))
        holdChangeText = "(+" .. holdCapacityDiff .. ")"
    elseif holdCapacityDiff < 0 then
        love.graphics.setColor(unpack(COLORS.negative))
        holdChangeText = "(" .. holdCapacityDiff .. ")"
    end

    -- Display hold count with change indicator
    local holdText = string.format("and hold %d/%d cards", game.holdCount, game.maxHoldCards)
    love.graphics.setColor(unpack(COLORS.text)) -- Reset color
    love.graphics.printf(holdText, FIELD_WIDTH/2, 10, FIELD_WIDTH/2 - 20, "center")
    if holdChangeText ~= "" then
        local holdTextWidth = assets.font:getWidth(holdText)
        local x = FIELD_WIDTH/2 + FIELD_WIDTH/4 + holdTextWidth/2 - 10
        love.graphics.printf(holdChangeText, x, 10, 50, "left")
    end
    
    -- Draw popup for deck or discard if hovering
    if deckHover then
        ui.drawCardDistributionPopup(game.deck.cards, SCREEN_WIDTH - 100, FIELD_HEIGHT - 10)
    elseif discardHover then
        ui.drawCardDistributionPopup(game.discard.cards, SCREEN_WIDTH - 48, FIELD_HEIGHT - 10)
    end
    
    -- Draw help button in top right corner
    ui.drawButton(buttons.help)
    
    -- Draw game over overlay if the game is over
    if game.isGameOver then
        story.drawGameOverOverlay()
    end

    -- Draw day over overlay if the game is over
    if game.isDayOver then
        story.drawStoryOverlay()
    end
    
    -- Draw help menu overlay if visible
    if game.helpMenu.visible then
        ui.drawHelpMenuOverlay()
    end
end

-- Function to draw the hand area
function ui.drawHandArea()
    -- Draw tiled background for hand area
    ui.drawTiledBackground(0, FIELD_HEIGHT, SCREEN_WIDTH, HAND_HEIGHT)
    
    -- Draw deck space
    love.graphics.setColor(1, 1, 1)
    local deckX = SCREEN_WIDTH - 100
    local deckY = FIELD_HEIGHT + 10
    love.graphics.draw(assets.deckImage, deckX, deckY)
    love.graphics.setColor(255, 255, 255)
    love.graphics.setFont(assets.smallFont)
    love.graphics.printf("deck", deckX, deckY + CARD_HEIGHT/2 - 10, CARD_WIDTH, "center")
    love.graphics.printf("x" .. game.deck.count, deckX, deckY + CARD_HEIGHT - 20, CARD_WIDTH, "center")

    -- Draw discard space
    love.graphics.setColor(1, 1, 1)
    local discardX = SCREEN_WIDTH - 48
    local discardY = FIELD_HEIGHT + 10
    love.graphics.draw(assets.discardImage, discardX, discardY)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("dis-", discardX, discardY + CARD_HEIGHT/2 - 20, CARD_WIDTH, "center")
    love.graphics.printf("card", discardX, discardY + CARD_HEIGHT/2, CARD_WIDTH, "center")
    love.graphics.printf("x" .. game.discard.count, discardX, discardY + CARD_HEIGHT - 20, CARD_WIDTH, "center")
    
    -- Draw draw button
    ui.drawButton(buttons.endShift)
    
    -- Add predicted draw information below button
    local predictedAliveTiles, predictedHoldCapacity, dangerTiles = predictAliveAndHoldCapacity()
    local currentDrawAmount = game.calculateDrawAmount(game.shiftStartAliveTilesCount)
    local futureDrawAmount = game.calculateDrawAmount(predictedAliveTiles)
    local drawDifference = futureDrawAmount - currentDrawAmount

    -- Display text about the predicted draw amount - moved under deck display and enlarged
    local infoX = SCREEN_WIDTH - 100 - 40  -- Starting from deck position, extended left
    local infoY = FIELD_HEIGHT + 20 + CARD_HEIGHT + 30  -- Below deck display
    local infoWidth = 130  -- Wider area for text

    -- Use larger font
    love.graphics.setFont(assets.font)
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.printf("You will draw", infoX, infoY, infoWidth, "center")

    -- Draw amount with color-coded difference
    local numberY = infoY + 25
    love.graphics.printf(tostring(futureDrawAmount), infoX + 0, numberY, 30, "right")

    if drawDifference > 0 then
        love.graphics.setColor(unpack(COLORS.positive))
        love.graphics.printf("(+" .. drawDifference .. ")", infoX + 35, numberY, 40, "left")
    elseif drawDifference < 0 then
        love.graphics.setColor(unpack(COLORS.negative))
        love.graphics.printf("(" .. drawDifference .. ")", infoX + 35, numberY, 40, "left")
    end

    -- Add "cards" text after the numbers
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.printf("cards", infoX + 30, numberY, infoWidth, "center")
    
    -- Draw cards in hand (except the one being dragged)
    for i, card in ipairs(game.cards) do
        ui.drawCard(card, card == game.dragging)
    end
end

-- Function to draw the status bar
function ui.drawStatusBar()
    -- Draw tiled background for status bar
    ui.drawTiledBackground(SCREEN_WIDTH - STATUS_BAR_WIDTH, 40, STATUS_BAR_WIDTH, FIELD_HEIGHT - 40)
    
    -- Draw semi-transparent overlay for better readability
    love.graphics.setColor(COLORS.status_bar[1], COLORS.status_bar[2], COLORS.status_bar[3], 0.3)
    love.graphics.rectangle("fill", SCREEN_WIDTH - STATUS_BAR_WIDTH, 40, STATUS_BAR_WIDTH, FIELD_HEIGHT - 40)
    
    -- Draw "FOREMAN DAY X" text
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.setFont(assets.font)
    love.graphics.printf("FOREMAN", SCREEN_WIDTH - STATUS_BAR_WIDTH, 50, STATUS_BAR_WIDTH, "center")
    love.graphics.printf("DAY " .. game.dayClock.day, SCREEN_WIDTH - STATUS_BAR_WIDTH, 70, STATUS_BAR_WIDTH, "center")
    
    -- Draw day clock
    ui.drawDayClock(SCREEN_WIDTH - STATUS_BAR_WIDTH/2, 120, 30)
    
    -- Draw SCORE
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.printf("SCORE", SCREEN_WIDTH - STATUS_BAR_WIDTH, 150, STATUS_BAR_WIDTH, "center")
    
    -- Format the score with leading zeros to 6 digits
    local scoreText = string.format("%06d", game.score)
    love.graphics.printf(scoreText, SCREEN_WIDTH - STATUS_BAR_WIDTH, 170, STATUS_BAR_WIDTH, "center")
    
    -- Get current depth and depth goal
    local currentDepth = calculateCurrentDepth()
    local depthGoal = 0
    
    -- Get depth goal from story for current day
    if story.messages[game.dayClock.day] then
        depthGoal = story.messages[game.dayClock.day].depthgoal or 0
    end
    
    -- Draw DEPTH indicator
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.printf("DEPTH", SCREEN_WIDTH - STATUS_BAR_WIDTH, 200, STATUS_BAR_WIDTH, "center")
    
    -- Color the depth ratio based on progress
    if currentDepth >= depthGoal and depthGoal > 0 then
        -- Goal reached - show in green
        love.graphics.setColor(unpack(COLORS.positive))
    elseif currentDepth >= depthGoal * 0.75 and depthGoal > 0 then
        -- Close to goal - show in yellow
        love.graphics.setColor(1, 1, 0, 1)
    else
        -- Far from goal - show in normal text color
        love.graphics.setColor(unpack(COLORS.text))
    end
    
    -- Draw the depth values
    love.graphics.printf(currentDepth .. "/" .. depthGoal, SCREEN_WIDTH - STATUS_BAR_WIDTH, 220, STATUS_BAR_WIDTH, "center")
    
    -- Draw DANGERS indicator
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.printf("DANGERS", SCREEN_WIDTH - STATUS_BAR_WIDTH, 250, STATUS_BAR_WIDTH, "center")
    
    -- Count the number of danger tiles
    local dangerCount = #game.dangerTiles
    
    -- Color the danger count based on how many there are
    if dangerCount == 0 then
        -- No dangers - show in green
        love.graphics.setColor(unpack(COLORS.positive))
    else
        -- Dangers present - show in red
        love.graphics.setColor(unpack(COLORS.negative))
    end
    
    -- Draw the danger count
    love.graphics.printf(tostring(dangerCount), SCREEN_WIDTH - STATUS_BAR_WIDTH, 270, STATUS_BAR_WIDTH, "center")
end

function ui.drawFieldGrid()    
    -- Calculate visible grid range
    local startCol = math.floor(viewport.offsetX / GRID_CELL_SIZE) - 1
    local endCol = startCol + math.ceil(FIELD_WIDTH / GRID_CELL_SIZE) + 2
    local startRow = math.floor(viewport.offsetY / GRID_CELL_HEIGHT) - 1
    local endRow = startRow + math.ceil(FIELD_HEIGHT / GRID_CELL_HEIGHT) + 2
    
    -- Ensure we're not trying to draw too many cells
    startCol = math.max(-GAME_FIELD_WIDTH_EXTENSION, startCol)  -- Allow grid crosses to extend GAME_FIELD_WIDTH_EXTENSION cells left
    endCol = math.min(GRID_COLS + GAME_FIELD_WIDTH_EXTENSION, endCol)  -- Allow grid crosses to extend GAME_FIELD_WIDTH_EXTENSION cells right
    startRow = math.max(SURFACE_LEVEL, startRow)  -- Only draw grid at or below surface
    endRow = math.min(GRID_ROWS + GAME_FIELD_DEPTH, endRow)  -- Allow for deep scrolling
    
    -- Draw grid cells with + symbols at corners
    for row = startRow, endRow do
        for col = startCol, endCol do
            local x, y = ui.gridToScreen(col, row)
            
            -- Only draw grid points that are within the visible area (not behind status bar)
            if x <= FIELD_WIDTH and x >= 0 and y >= 40 and y <= FIELD_HEIGHT then
                -- Draw + symbol at grid corners
                love.graphics.setColor(unpack(COLORS.grid_symbol))
                love.graphics.setFont(assets.smallFont)
                love.graphics.print("+", x - 4, y - 8)
                
                -- Check if this tile is outside depth limits
                local isOutsideDepth = isOutsideDepthLimits(col, row)
                
                -- Draw overlay for tiles outside depth limits
                if isOutsideDepth and isTileEmpty(col, row) then
                    love.graphics.setColor(unpack(COLORS.planned_overlay))
                    love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT)
                end
                
                -- Highlight "alive" tiles with a subtle glow
                local isAlive = false
                for _, tile in ipairs(game.aliveTiles) do
                    if tile.x == col and tile.y == row then
                        isAlive = true
                        break
                    end
                end
                
                if isAlive then
                    love.graphics.setColor(0, 0.5, 0, 0.2)  -- Subtle green glow
                    love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT)
                end
                
                -- Highlight cell if mouse is over it and a card is being dragged
                if game.dragging and not viewport.dragging then
                    local mouseX, mouseY = love.mouse.getPosition()
                    local gx, gy = ui.screenToGrid(mouseX, mouseY)
                    
                    -- Only highlight cells within visible area
                    if gx == col and gy == row and x + CARD_WIDTH <= FIELD_WIDTH then
                        love.graphics.setColor(0, 1, 0, 0.5)  -- Green for valid placement
                    end
                end
            end
        end
    end
end

-- Draw danger overlays for tiles marked as danger zones
function ui.drawDangerTileOverlays()
    -- Calculate visible grid range
    local startCol = math.floor(viewport.offsetX / GRID_CELL_SIZE) - 1
    local endCol = startCol + math.ceil(FIELD_WIDTH / GRID_CELL_SIZE) + 2
    local startRow = math.floor(viewport.offsetY / GRID_CELL_HEIGHT) - 1
    local endRow = startRow + math.ceil(FIELD_HEIGHT / GRID_CELL_HEIGHT) + 2
    
    -- Ensure we're not trying to draw too many cells
    startCol = math.max(-GAME_FIELD_WIDTH_EXTENSION, startCol)
    endCol = math.min(GRID_COLS + GAME_FIELD_WIDTH_EXTENSION, endCol)
    startRow = math.max(SURFACE_LEVEL, startRow)
    endRow = math.min(GRID_ROWS + GAME_FIELD_DEPTH, endRow)
    
    -- Draw danger overlays for danger tiles
    for _, tile in ipairs(game.dangerTiles) do
        -- Check if tile is within the visible range
        if tile.x >= startCol and tile.x <= endCol and tile.y >= startRow and tile.y <= endRow then
            local x, y = ui.gridToScreen(tile.x, tile.y)
            
            -- Only draw if within the visible area (not behind status bar)
            if x <= FIELD_WIDTH and x >= 0 and y >= 40 and y <= FIELD_HEIGHT then
                -- Use the danger image instead of color overlay
                love.graphics.setColor(1, 1, 1, 0.7) -- Draw at 70% opacity
                love.graphics.draw(dangerImage, x, y, 0, CARD_WIDTH / dangerImage:getWidth(), CARD_HEIGHT / dangerImage:getHeight())
            end
        end
    end
end

function ui.drawFieldCards()
    -- Draw cards that have been placed on the field (permanent cards)
    for pos, cardData in pairs(game.field) do
        local y, x = string.match(pos, "(%d+),([%-%d]+)")  -- Update regex to handle negative numbers
        x, y = tonumber(x), tonumber(y)
        
        -- Check if x and y are valid before attempting to draw
        if x ~= nil and y ~= nil then
            -- Get the top-left corner of the card
            local screenX, screenY = ui.gridToScreen(x, y)
            
            -- Only draw if the card is in view
            if screenX + CARD_WIDTH >= 0 and screenX <= FIELD_WIDTH and
               screenY + CARD_HEIGHT >= 0 and screenY <= FIELD_HEIGHT then
                -- Draw the card
                love.graphics.setColor(1, 1, 1)
                
                -- Handle rotation for flipped cards (180 degrees = pi radians)
                local rotation = cardData.rotation
                if cardData.flipped then
                    rotation = rotation + math.pi
                end
                
                -- Choose the appropriate card image based on the layer (y-coordinate)
                local cardImage
                if y >= DEEP_MINE_LEVEL then
                    -- Deep mine layer (stone)
                    cardImage = assets.stoneCards[cardData.type]
                else
                    -- Surface layer (gryaz)
                    cardImage = assets.gryazCards[cardData.type]
                end
                
                love.graphics.draw(
                    cardImage,
                    screenX + CARD_WIDTH/2, 
                    screenY + CARD_HEIGHT/2, 
                    rotation,  -- rotation in radians
                    1, 1,      -- scale x, scale y
                    CARD_WIDTH/2,  -- origin x (center of card)
                    CARD_HEIGHT/2  -- origin y (center of card)
                )
            end
        else
            -- Log or handle invalid position format
            print("Warning: Invalid card position format in game.field: " .. pos)
        end
    end
    
    -- Draw planned cards with gray overlay
    for pos, cardData in pairs(game.plannedCards) do
        local y, x = string.match(pos, "(%d+),([%-%d]+)")  -- Update regex to handle negative numbers
        x, y = tonumber(x), tonumber(y)
        
        -- Check if x and y are valid before attempting to draw
        if x ~= nil and y ~= nil then
            -- Get the top-left corner of the card
            local screenX, screenY = ui.gridToScreen(x, y)
            
            -- Only draw if the card is in view
            if screenX + CARD_WIDTH >= 0 and screenX <= FIELD_WIDTH and
               screenY + CARD_HEIGHT >= 0 and screenY <= FIELD_HEIGHT then
                -- Draw the card
                love.graphics.setColor(1, 1, 1)
                
                -- Handle rotation for flipped cards (180 degrees = pi radians)
                local rotation = cardData.rotation
                if cardData.flipped then
                    rotation = rotation + math.pi
                end
                
                -- Choose the appropriate card image based on the layer (y-coordinate)
                local cardImage
                if y >= DEEP_MINE_LEVEL then
                    -- Deep mine layer (stone)
                    cardImage = assets.stoneCards[cardData.type]
                else
                    -- Surface layer (gryaz)
                    cardImage = assets.gryazCards[cardData.type]
                end
                
                love.graphics.draw(
                    cardImage,
                    screenX + CARD_WIDTH/2, 
                    screenY + CARD_HEIGHT/2, 
                    rotation,  -- rotation in radians
                    1, 1,      -- scale x, scale y
                    CARD_WIDTH/2,  -- origin x (center of card)
                    CARD_HEIGHT/2  -- origin y (center of card)
                )
                
                -- Draw gray overlay to indicate planned status
                love.graphics.setColor(unpack(COLORS.planned_overlay))
                love.graphics.rectangle("fill", screenX, screenY, CARD_WIDTH, CARD_HEIGHT)
            end
        else
            -- Log or handle invalid position format
            print("Warning: Invalid card position format in game.plannedCards: " .. pos)
        end
    end
end

function ui.drawCard(card)
    -- Draw white border around all cards in hand
    love.graphics.setColor(unpack(COLORS.hand_card_border))
    love.graphics.rectangle("line", card.x - 2, card.y - 2, CARD_WIDTH + 4, CARD_HEIGHT + 4, 2, 2)
    
    -- Draw highlight for held cards (drawn on top of the white border)
    if card.held then
        love.graphics.setColor(unpack(COLORS.hold_border))
        love.graphics.rectangle("line", card.x - 2, card.y - 2, CARD_WIDTH + 4, CARD_HEIGHT + 4, 2, 2)
    end

    love.graphics.setColor(1, 1, 1)
    local rotation = card.flipped and math.pi or 0
    love.graphics.draw(assets.cards[card.type], card.x + CARD_WIDTH / 2, card.y + CARD_HEIGHT / 2, rotation, 1, 1, CARD_WIDTH / 2, CARD_HEIGHT / 2)
end

-- Draw the appropriate background for the visible field area based on depth
function ui.drawField()
    -- Calculate visible grid range
    local startCol = math.floor(viewport.offsetX / GRID_CELL_SIZE) - 1
    local endCol = startCol + math.ceil(FIELD_WIDTH / GRID_CELL_SIZE) + 2
    local startRow = math.floor(viewport.offsetY / GRID_CELL_HEIGHT) - 1
    local endRow = startRow + math.ceil(FIELD_HEIGHT / GRID_CELL_HEIGHT) + 2
    
    -- Ensure we're not trying to draw too many cells
    startCol = math.max(-GAME_FIELD_WIDTH_EXTENSION, startCol)  -- Allow some scrolling left
    endCol = math.min(GRID_COLS + GAME_FIELD_WIDTH_EXTENSION, endCol)  -- Allow some scrolling right
    startRow = math.max(-20, startRow)  -- Allow some scrolling up (20 cells)
    endRow = math.min(GRID_ROWS + GAME_FIELD_DEPTH, endRow)  -- Allow significant scrolling down
    
    -- Draw the background for each visible row section
    for row = startRow, endRow do
        local screenY = GRID_OFFSET_Y + row * GRID_CELL_HEIGHT - viewport.offsetY
        
        -- Set color based on biome depth
        if row < SURFACE_LEVEL then
            love.graphics.setColor(unpack(COLORS.surface))
        elseif row >= DEEP_MINE_LEVEL then
            love.graphics.setColor(unpack(COLORS.deep_mine))
        else
            love.graphics.setColor(unpack(COLORS.background))
        end
        
        -- Draw a row strip
        love.graphics.rectangle("fill", 0, screenY, FIELD_WIDTH, GRID_CELL_HEIGHT + 1)
    end
end

-- Convert grid coordinates to screen position
function ui.gridToScreen(gridX, gridY)
    -- Safety check to prevent nil errors
    if gridX == nil or gridY == nil then
        print("Warning: gridToScreen called with nil parameters")
        return 0, 0 -- Return a default value
    end
    
    return GRID_OFFSET_X + gridX * GRID_CELL_SIZE - viewport.offsetX, 
           GRID_OFFSET_Y + gridY * GRID_CELL_HEIGHT - viewport.offsetY
end

-- Convert screen position to grid coordinates
function ui.screenToGrid(screenX, screenY)
    return math.floor((screenX - GRID_OFFSET_X + viewport.offsetX) / GRID_CELL_SIZE),
           math.floor((screenY - GRID_OFFSET_Y + viewport.offsetY) / GRID_CELL_HEIGHT)
end

-- These are UI helper functions that might be needed
function ui.canPlaceCard(cardType, gridX, gridY, flipped)
    return gameLogic.canPlaceCard(cardType, gridX, gridY, flipped)
end

-- Check for hover over deck and discard piles
function ui.updateHoverStates(mouseX, mouseY)
    local deckX = SCREEN_WIDTH - 100
    local discardX = SCREEN_WIDTH - 48
    local deckY = FIELD_HEIGHT + 10
    
    -- Check for deck hover
    deckHover = mouseX >= deckX and mouseX <= deckX + CARD_WIDTH and
                mouseY >= deckY and mouseY <= deckY + CARD_HEIGHT
    
    -- Check for discard hover
    discardHover = mouseX >= discardX and mouseX <= discardX + CARD_WIDTH and
                  mouseY >= deckY and mouseY <= deckY + CARD_HEIGHT
end

-- Draw popup showing card distribution in deck or discard
function ui.drawCardDistributionPopup(cardList, anchorX, anchorY)
    -- Count occurrences of each card type
    local cardCounts = {}
    local totalCards = 0
    
    -- Initialize counts to zero for all card types
    for cardType, _ in pairs(assets.cards) do
        cardCounts[cardType] = 0
    end
    
    -- Count cards in the provided list
    for _, cardItem in ipairs(cardList) do
        -- If it's a direct card type (as in deck/discard)
        if type(cardItem) == "string" then
            cardCounts[cardItem] = cardCounts[cardItem] + 1
            totalCards = totalCards + 1
        end
    end
    
    -- Define popup dimensions
    local popupWidth = 300
    local cardSpacing = 10
    local cardsPerRow = 3
    local cardDisplayHeight = CARD_HEIGHT * 0.6 -- Show cards at 60% height in the popup
    local cardDisplayWidth = CARD_WIDTH * 0.6
    local rowHeight = cardDisplayHeight + cardSpacing
    
    -- Get ordered card types (preserving original definition order)
    local orderedCardTypes = {}
    
    -- First add single path cards in order
    table.insert(orderedCardTypes, "path_1_1a")
    table.insert(orderedCardTypes, "path_1_1b")
    
    -- Add 2-edge, 1-path cards
    table.insert(orderedCardTypes, "path_2_1a")
    table.insert(orderedCardTypes, "path_2_1b")
    table.insert(orderedCardTypes, "path_2_1c")
    table.insert(orderedCardTypes, "path_2_1d")
    
    -- Add 3-edge, 1-path cards
    table.insert(orderedCardTypes, "path_3_1a")
    table.insert(orderedCardTypes, "path_3_1b")
    
    -- Add 4-edge, 1-path card
    table.insert(orderedCardTypes, "path_4_1")
    
    -- Add 2-edge, 2-path cards
    table.insert(orderedCardTypes, "path_2_2a")
    table.insert(orderedCardTypes, "path_2_2b")
    table.insert(orderedCardTypes, "path_2_2c")
    table.insert(orderedCardTypes, "path_2_2d")
    
    -- Add 3-edge, 3-path cards
    table.insert(orderedCardTypes, "path_3_3a")
    table.insert(orderedCardTypes, "path_3_3b")
    
    -- Add 4-edge, 4-path card
    table.insert(orderedCardTypes, "path_4_4")
    
    -- Add empty card
    table.insert(orderedCardTypes, "empty")
    
    -- Calculate number of rows needed
    local cardTypeCount = #orderedCardTypes
    local numRows = math.ceil(cardTypeCount / cardsPerRow)
    local popupHeight = numRows * rowHeight + 30 -- Add padding
    
    -- Position popup appropriately relative to the anchor point
    -- Ensure it's within the game window
    local popupX = math.max(10, math.min(anchorX - popupWidth / 2, SCREEN_WIDTH - popupWidth - 10))
    
    -- For deck, show popup above the hand area but below the top bar
    local popupY = math.max(50, FIELD_HEIGHT - popupHeight - 10)
    
    -- Ensure it doesn't go off the right side
    if popupX + popupWidth > SCREEN_WIDTH - STATUS_BAR_WIDTH then
        popupX = SCREEN_WIDTH - STATUS_BAR_WIDTH - popupWidth - 5
    end
    
    -- Draw popup background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", popupX, popupY, popupWidth, popupHeight, 8, 8)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle("line", popupX, popupY, popupWidth, popupHeight, 8, 8)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(assets.smallFont)
    local titleText = "Cards: " .. totalCards
    love.graphics.printf(titleText, popupX, popupY + 8, popupWidth, "center")
    
    -- Draw cards in grid layout with consistent order
    for i, cardType in ipairs(orderedCardTypes) do
        local count = cardCounts[cardType] or 0
        local row = math.floor((i-1) / cardsPerRow)
        local col = (i-1) % cardsPerRow
        
        local x = popupX + 20 + col * (cardDisplayWidth + 20)
        local y = popupY + 25 + row * rowHeight
        
        -- Draw card
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            assets.cards[cardType],
            x, y,
            0,  -- rotation
            0.6, 0.6  -- scale to 60% size
        )
        
        -- Grey overlay for cards not in deck/discard
        if count == 0 then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
            love.graphics.rectangle("fill", x, y, cardDisplayWidth, cardDisplayHeight)
        end
        
        -- Draw count text
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(assets.smallFont)
        love.graphics.print("x" .. count, x + cardDisplayWidth + 2, y + cardDisplayHeight / 2 - 6)
    end
end

-- Function to draw the day clock with segments
function ui.drawDayClock(centerX, centerY, radius)
    local totalSegments = game.dayClock.totalSegments
    local remainingSegments = game.dayClock.remainingSegments
    
    -- Draw base clock circle (background)
    love.graphics.setColor(0.3, 0.3, 0.3)  -- Dark gray background
    love.graphics.circle("fill", centerX, centerY, radius)
    
    -- If all segments are used, just return (fully black circle)
    if remainingSegments <= 0 then
        return
    end
    
    -- Calculate angle per segment
    local anglePerSegment = 2 * math.pi / totalSegments
    
    -- Draw the remaining segments
    love.graphics.setColor(unpack(COLORS.clock_face))
    
    -- If all segments remain, draw a full circle
    if remainingSegments == totalSegments then
        love.graphics.circle("fill", centerX, centerY, radius)
    else
        -- We need to draw the remaining segments, skipping the ones we've used
        -- First segment removed should be the 12-3 o'clock position (offset by 1)
        local usedSegments = totalSegments - remainingSegments
        
        -- Draw each segment individually
        for i = 0, totalSegments - 1 do
            -- Check if this segment should be visible or has been used up
            local isUsed = i < usedSegments
            
            if not isUsed then
                -- Draw this segment
                local startAngle = -math.pi/2 + i * anglePerSegment
                ui.drawPieSegment(centerX, centerY, radius, startAngle, startAngle + anglePerSegment)
            end
        end
    end
    
    -- Draw segment divider lines
    love.graphics.setColor(unpack(COLORS.clock_dividers))
    love.graphics.setLineWidth(2)
    
    for i = 0, totalSegments - 1 do
        local angle = -math.pi/2 + i * anglePerSegment
        local x = centerX + radius * math.cos(angle)
        local y = centerY + radius * math.sin(angle)
        love.graphics.line(centerX, centerY, x, y)
    end
    
    -- Draw clock border
    love.graphics.circle("line", centerX, centerY, radius)
    
    -- Reset line width
    love.graphics.setLineWidth(1)
end

-- Helper function to draw a pie segment
function ui.drawPieSegment(centerX, centerY, radius, startAngle, endAngle)
    -- Create a polygon approximating the pie segment
    local segments = 20  -- Number of line segments to use for approximation
    local vertices = {}
    
    -- Add the center point
    table.insert(vertices, centerX)
    table.insert(vertices, centerY)
    
    -- Add points along the arc
    for i = 0, segments do
        local angle = startAngle + (endAngle - startAngle) * (i / segments)
        local x = centerX + radius * math.cos(angle)
        local y = centerY + radius * math.sin(angle)
        table.insert(vertices, x)
        table.insert(vertices, y)
    end
    
    -- Draw the filled polygon
    love.graphics.polygon("fill", vertices)
end

-- Draw help menu overlay that displays the help_menu.png image
function ui.drawHelpMenuOverlay()
    -- Semi-transparent black background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw the help menu image centered on screen
    love.graphics.setColor(1, 1, 1)
    local helpImage = assets.helpMenu
    local imgWidth = helpImage:getWidth()
    local imgHeight = helpImage:getHeight()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Scale image if needed to fit on screen
    local scale = 0.95
    
    -- Draw image centered on screen
    love.graphics.draw(
        helpImage, 
        screenWidth/2, 
        screenHeight/2, 
        0,             -- rotation
        scale, scale,  -- scale
        imgWidth/2,    -- origin x (center of image) 
        imgHeight/2    -- origin y (center of image)
    )
    
    -- Draw close instructions at bottom
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(assets.font)
    local text = "Click anywhere to close"
    local textWidth = assets.font:getWidth(text)
    love.graphics.print(text, screenWidth/2 - textWidth/2, screenHeight - 50)
end

-- Add a new function to render buttons
function ui.drawButton(button)
    -- Set color based on hover state
    if button.isHovered then
        love.graphics.setColor(0.7, 0.7, 1)  -- Light blue when hovering
    else
        love.graphics.setColor(0.5, 0.5, 0.9)  -- Blue normally
    end
    
    -- Draw rounded rectangle for buttons with radius property
    if button.radius then
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, button.radius, button.radius)
    else
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
    end
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(assets.smallFont)
    
    -- Check if it's the help button (center the text)
    if button.text == "?" then
        local textWidth = assets.font:getWidth(button.text)
        local textHeight = assets.font:getHeight()
        love.graphics.setFont(assets.font)
        love.graphics.print(button.text, button.x + button.width/2 - textWidth/2, button.y + button.height/2 - textHeight/2)
    else
        love.graphics.printf(button.text, button.x, button.y + 9, button.width, "center")
    end
end

-- Add a new function to scale coordinates
function ui.scaleCoordinates(x, y)
    local scaleX = SCREEN_WIDTH / 520  -- Assuming 520 is the base width
    local scaleY = SCREEN_HEIGHT / 800  -- Assuming 800 is the base height
    return x * scaleX, y * scaleY
end

-- Function to draw all vignettes in their respective corners
function ui.drawVignettes()
    love.graphics.setColor(1, 1, 1)
    
    -- Draw top left vignette
    if tlVignetteImage then
        love.graphics.draw(tlVignetteImage, 0, 40, 
                         0, -- rotation
                         1, 1) -- scale
    end
    
    -- Draw top right vignette
    if trVignetteImage then
        love.graphics.draw(trVignetteImage, FIELD_WIDTH, 40, 
                         0, -- rotation
                         1, 1, -- scale
                         trVignetteImage:getWidth(), 0) -- origin at top right
    end
    
    -- Draw bottom left vignette
    if blVignetteImage then
        love.graphics.draw(blVignetteImage, 0, FIELD_HEIGHT, 
                         0, -- rotation
                         1, 1, -- scale
                         0, blVignetteImage:getHeight()) -- origin at bottom left
    end
    
    -- Draw bottom right vignette
    if vignetteImage then
        love.graphics.draw(vignetteImage, FIELD_WIDTH, FIELD_HEIGHT, 
                         0, -- rotation
                         1, 1, -- scale
                         vignetteImage:getWidth(), vignetteImage:getHeight()) -- origin at bottom right
    end
end

-- Function to draw a tiled background map over the game field
function ui.drawTiledGameField()
    if not backgroundMapImage then return end
    
    love.graphics.setColor(1, 1, 1, 0.4)  -- Draw with 40% opacity to blend with the biome backgrounds
    
    local imgWidth = backgroundMapImage:getWidth()
    local imgHeight = backgroundMapImage:getHeight()
    
    -- Calculate visible field area
    local fieldStartX = 0
    local fieldStartY = 40 -- Below top bar
    local fieldWidth = FIELD_WIDTH
    local fieldHeight = FIELD_HEIGHT - 40
    
    -- Calculate how many tiles we need in each direction
    local tilesX = math.ceil(fieldWidth / imgWidth) + 1 -- +1 for scrolling
    local tilesY = math.ceil(fieldHeight / imgHeight) + 1 -- +1 for scrolling
    
    -- Calculate offset for scrolling
    local offsetX = -math.floor(viewport.offsetX % imgWidth)
    local offsetY = -math.floor(viewport.offsetY % imgHeight)
    
    -- Draw the background tiles
    for tileX = 0, tilesX - 1 do
        for tileY = 0, tilesY - 1 do
            love.graphics.draw(
                backgroundMapImage,
                fieldStartX + offsetX + tileX * imgWidth,
                fieldStartY + offsetY + tileY * imgHeight
            )
        end
    end
end

-- Return the UI module
return ui 