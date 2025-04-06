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
local GAME_FIELD_WIDTH_EXTENSION = 10
local GAME_FIELD_DEPTH = 100
local SURFACE_LEVEL = 0
local DEEP_MINE_LEVEL = 10

-- Colors
local COLORS = {
    background = {0, 0, 0},        -- Black
    grid_symbol = {0.6, 0.6, 0.6}, -- Light gray for +
    hand_bg = {0.5, 0.3, 0.2},     -- Brown for hand area
    status_bar = {0, 0, 0},        -- Black for status bar
    top_bar = {0.5, 0.3, 0.2},     -- Brown for top bar
    text = {1, 1, 1},              -- White text
    highlight = {0.5, 0.5, 0.7, 0.3}, -- Bluish highlight
    surface = {0.6, 0.4, 0.2},     -- Brown for surface (above ground)
    deep_mine = {0.3, 0.3, 0.35},  -- Grayish for deep mine
    hold_border = {1, 0.8, 0},     -- Gold for held card border
    clock_face = {1, 1, 0},        -- Yellow for clock face
    clock_segment_used = {0, 0, 0}, -- Black for used clock segments
    clock_dividers = {0.5, 0.5, 0.5}, -- Gray for clock segment dividers
    planned_overlay = {0.5, 0.5, 0.5, 0.5} -- Semi-transparent gray for planned cards
}

-- Shared reference to game state and assets (will be set from main.lua)
local game = nil
local assets = nil
local viewport = nil
local DIRECTION = nil

-- Hover states for deck/discard UI
local deckHover = false
local discardHover = false

-- Initialize the UI module with references to game state and assets
function ui.init(gameState, gameAssets, viewportState, directionEnum)
    game = gameState
    assets = gameAssets
    viewport = viewportState
    DIRECTION = directionEnum
end

-- Main drawing function
function ui.draw()
    -- Set background color
    love.graphics.setBackgroundColor(unpack(COLORS.background))
    
    -- Draw the field with appropriate biome backgrounds
    ui.drawField()
    
    -- Draw the field grid
    ui.drawFieldGrid()
    
    -- Draw cards placed on the field
    ui.drawFieldCards()
    
    -- Draw status bar
    ui.drawStatusBar()
    
    -- Draw hand area background
    love.graphics.setColor(unpack(COLORS.hand_bg))
    love.graphics.rectangle("fill", 0, FIELD_HEIGHT, SCREEN_WIDTH, HAND_HEIGHT)
    
    -- Draw deck space
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", SCREEN_WIDTH - 96, FIELD_HEIGHT + 10, CARD_WIDTH, CARD_HEIGHT)
    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(assets.smallFont)
    love.graphics.printf("deck", SCREEN_WIDTH - 96, FIELD_HEIGHT + 10 + CARD_HEIGHT/2 - 10, CARD_WIDTH, "center")
    love.graphics.printf("x" .. game.deck.count, SCREEN_WIDTH - 96, FIELD_HEIGHT + 10 + CARD_HEIGHT - 20, CARD_WIDTH, "center")
    
    -- Draw discard space
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", SCREEN_WIDTH - 48, FIELD_HEIGHT + 10, CARD_WIDTH, CARD_HEIGHT)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("dis-", SCREEN_WIDTH - 48, FIELD_HEIGHT + 10 + CARD_HEIGHT/2 - 20, CARD_WIDTH, "center")
    love.graphics.printf("card", SCREEN_WIDTH - 48, FIELD_HEIGHT + 10 + CARD_HEIGHT/2, CARD_WIDTH, "center")
    love.graphics.printf("x" .. game.discard.count, SCREEN_WIDTH - 48, FIELD_HEIGHT + 10 + CARD_HEIGHT - 20, CARD_WIDTH, "center")
    
    -- Draw draw button
    local drawButtonX = SCREEN_WIDTH - 48
    local drawButtonY = FIELD_HEIGHT + 10 + CARD_HEIGHT + 10
    local drawButtonWidth = CARD_WIDTH
    local drawButtonHeight = 30
    
    if game.drawButtonHover then
        love.graphics.setColor(0.7, 0.7, 1)  -- Light blue when hovering
    else
        love.graphics.setColor(0.5, 0.5, 0.9)  -- Blue normally
    end
    love.graphics.rectangle("fill", drawButtonX, drawButtonY, drawButtonWidth, drawButtonHeight)
    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(assets.smallFont)
    love.graphics.printf("END SHIFT", drawButtonX, drawButtonY + 9, drawButtonWidth, "center")
    
    -- Draw cards in hand (except the one being dragged)
    for i, card in ipairs(game.cards) do
        if card ~= game.dragging then
            ui.drawCard(card)
        end
    end
    
    -- Draw the card being dragged (on top of everything)
    if game.dragging then
        ui.drawCard(game.dragging)
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
    local infoText = string.format("You can play %d/%d cards and hold %d/%d cards", 
                                  game.playCount, game.maxPlayCards,
                                  game.holdCount, game.maxHoldCards)
    love.graphics.printf(infoText, 10, 10, FIELD_WIDTH - 20, "center")
    
    -- Draw popup for deck or discard if hovering
    if deckHover then
        ui.drawCardDistributionPopup(game.deck.cards, SCREEN_WIDTH - 96, FIELD_HEIGHT - 10)
    elseif discardHover then
        ui.drawCardDistributionPopup(game.discard.cards, SCREEN_WIDTH - 48, FIELD_HEIGHT - 10)
    end
end

-- Function to draw the status bar
function ui.drawStatusBar()
    -- Draw status bar on the right
    love.graphics.setColor(unpack(COLORS.status_bar))
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
    love.graphics.printf("SCORE", SCREEN_WIDTH - STATUS_BAR_WIDTH, 170, STATUS_BAR_WIDTH, "center")
    love.graphics.printf("000000", SCREEN_WIDTH - STATUS_BAR_WIDTH, 190, STATUS_BAR_WIDTH, "center")
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
                        love.graphics.setColor(unpack(COLORS.highlight))
                        love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT)
                    end
                end
            end
        end
    end
end

function ui.drawFieldCards()
    -- Draw cards that have been placed on the field (permanent cards)
    for pos, cardData in pairs(game.field) do
        local y, x = string.match(pos, "(%d+),(%d+)")
        x, y = tonumber(x), tonumber(y)
        
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
            
            love.graphics.draw(
                assets.cards[cardData.type], 
                screenX + CARD_WIDTH/2, 
                screenY + CARD_HEIGHT/2, 
                rotation,  -- rotation in radians
                1, 1,      -- scale x, scale y
                CARD_WIDTH/2,  -- origin x (center of card)
                CARD_HEIGHT/2  -- origin y (center of card)
            )
        end
    end
    
    -- Draw planned cards with gray overlay
    for pos, cardData in pairs(game.plannedCards) do
        local y, x = string.match(pos, "(%d+),(%d+)")
        x, y = tonumber(x), tonumber(y)
        
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
            
            love.graphics.draw(
                assets.cards[cardData.type], 
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
    end
end

function ui.drawCard(card)
    -- Draw highlight for held cards
    if card.held then
        love.graphics.setColor(unpack(COLORS.hold_border))
        -- Draw a slightly larger rectangle for the border
        love.graphics.rectangle("line", card.x - 2, card.y - 2, CARD_WIDTH + 4, CARD_HEIGHT + 4, 2, 2)
    end
    
    love.graphics.setColor(1, 1, 1)
    
    -- Handle flipped cards (180 degree rotation)
    if card.flipped then
        love.graphics.draw(
            assets.cards[card.type], 
            card.x + CARD_WIDTH/2, 
            card.y + CARD_HEIGHT/2,
            math.pi,  -- 180 degrees in radians
            1, 1,     -- scale x, scale y
            CARD_WIDTH/2,  -- origin x (center of card)
            CARD_HEIGHT/2  -- origin y (center of card)
        )
    else
        love.graphics.draw(assets.cards[card.type], card.x, card.y)
    end
    
    -- For flippable cards, show a small indicator that they can be flipped
    if game.CARD_PATH_DATA[card.type].flippable then
        love.graphics.setColor(1, 1, 0, 0.7)  -- Transparent yellow
        love.graphics.circle("fill", card.x + CARD_WIDTH - 5, card.y + 5, 3)
    end
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
    return game.canPlaceCard(cardType, gridX, gridY, flipped)
end

-- Check for hover over deck and discard piles
function ui.updateHoverStates(mouseX, mouseY)
    local deckX = SCREEN_WIDTH - 96
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

-- Return the UI module
return ui 