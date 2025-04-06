-- Constants
local SCREEN_WIDTH = 520
local SCREEN_HEIGHT = 800
local CARD_WIDTH = 48
local CARD_HEIGHT = 96
local GRID_CELL_SIZE = CARD_WIDTH  -- Horizontal spacing between grid points
local GRID_CELL_HEIGHT = CARD_HEIGHT  -- Vertical spacing between grid points (same as card height)
local GRID_OFFSET_X = 24  -- Center the grid in the play area
local GRID_OFFSET_Y = 40  -- Add some space at the top
local GRID_COLS = 10  -- Number of grid cells horizontally
local GRID_ROWS = 7  -- Number of grid cells vertically (reduced to account for full card height)
local HAND_HEIGHT = 200  -- Height of the hand area
local HAND_CARDS_PER_ROW = 6  -- Cards per row in hand
local HAND_ROWS = 2  -- Number of rows in hand
local FIELD_HEIGHT = SCREEN_HEIGHT - HAND_HEIGHT
local STATUS_BAR_WIDTH = 120  -- Width of the status bar on the right
local FIELD_WIDTH = SCREEN_WIDTH - STATUS_BAR_WIDTH  -- Visible field width

-- Game field boundaries (defines the playable mine area)
local GAME_FIELD_WIDTH_EXTENSION = 10  -- How many cells the playable field extends beyond center (each side)
local GAME_FIELD_DEPTH = 100   -- Maximum mining depth in cells

-- Biome boundaries
local SURFACE_LEVEL = 0  -- y < SURFACE_LEVEL: surface (brown, no grid)
local DEEP_MINE_LEVEL = 10  -- y >= DEEP_MINE_LEVEL: deep mine (gray)

-- Game rules
local MAX_PLAY_CARDS = 5  -- Maximum number of cards a player can play in a round

-- Viewport/scrolling
local viewport = {
    offsetX = 0,
    offsetY = 0,
    dragging = false,
    lastMouseX = 0,
    lastMouseY = 0
}

-- Directions
local DIRECTION = {
    TOP = 1,
    RIGHT = 2,
    BOTTOM = 3,
    LEFT = 4
}

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
}

-- Card types
local CARD_TYPES = {
    -- 1 Edge, 1 Path
    PATH_1_1A = "path_1_1a", -- Path bottom
    PATH_1_1B = "path_1_1b", -- Paths left
    
    -- 2 Edges, 1 Path
    PATH_2_1A = "path_2_1a", -- Vertical path
    PATH_2_1B = "path_2_1b", -- Horizontal path
    PATH_2_1C = "path_2_1c", -- Curved path (bottom to right)
    PATH_2_1D = "path_2_1d", -- Curved path (left to bottom)
    
    -- 3 Edges, 1 Path
    PATH_3_1A = "path_3_1a", -- T-junction right
    PATH_3_1B = "path_3_1b", -- T-junction top
    
    -- 4 Edges, 1 Path
    PATH_4_1 = "path_4_1",   -- Cross junction
    
    -- 2 Edges, 2 Paths
    PATH_2_2A = "path_2_2a", -- Two paths vertical
    PATH_2_2B = "path_2_2b", -- Two paths horizontal
    PATH_2_2C = "path_2_2c", -- Two paths, bottom and right
    PATH_2_2D = "path_2_2d", -- Two paths, left and bottom
    
    -- 3 Edges, 3 Paths
    PATH_3_3A = "path_3_3a", -- Three paths top right bottom
    PATH_3_3B = "path_3_3b", -- Three paths left top right
    
    -- 4 Edges, 4 Paths
    PATH_4_4 = "path_4_4",   -- Four paths
    
    -- Empty card (no paths)
    EMPTY = "empty"           -- Card with no paths
}

-- Card path data structure 
-- edges: which edges have paths (top, right, bottom, left)
-- paths: arrays describing which edges are connected (by path IDs)
local CARD_PATH_DATA = {
    [CARD_TYPES.PATH_1_1A] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.BOTTOM}}, -- Dead end at bottom
        flippable = true -- Dead end paths are flippable (bottom ↔ top)
    },
    [CARD_TYPES.PATH_1_1B] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT}}, -- Dead end at left
        flippable = true -- Dead end paths are flippable (left ↔ right)
    },
    [CARD_TYPES.PATH_2_1A] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.TOP, DIRECTION.BOTTOM}}, -- Straight vertical path
        flippable = false -- Vertical paths look the same when flipped
    },
    [CARD_TYPES.PATH_2_1B] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT, DIRECTION.RIGHT}}, -- Straight horizontal path
        flippable = false -- Horizontal paths look the same when flipped
    },
    [CARD_TYPES.PATH_2_1C] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.BOTTOM, DIRECTION.RIGHT}}, -- Curve bottom to right
        flippable = true -- Curves are flippable (bottom-right ↔ top-left)
    },
    [CARD_TYPES.PATH_2_1D] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT, DIRECTION.BOTTOM}}, -- Curve left to bottom
        flippable = true -- Curves are flippable (left-bottom ↔ right-top)
    },
    [CARD_TYPES.PATH_3_1A] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.TOP, DIRECTION.RIGHT, DIRECTION.BOTTOM}}, -- T-junction right
        flippable = true -- T-junctions can be flipped
    },
    [CARD_TYPES.PATH_3_1B] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.TOP, DIRECTION.RIGHT, DIRECTION.LEFT}}, -- T-junction top
        flippable = true -- T-junctions can be flipped
    },
    [CARD_TYPES.PATH_4_1] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.TOP, DIRECTION.RIGHT, DIRECTION.BOTTOM, DIRECTION.LEFT}}, -- Cross junction
        flippable = false -- Cross junctions look the same when flipped
    },
    [CARD_TYPES.PATH_2_2A] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.TOP}, {DIRECTION.BOTTOM}}, -- Two separate vertical dead ends
        flippable = false -- Looks the same when flipped
    },
    [CARD_TYPES.PATH_2_2B] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT}, {DIRECTION.RIGHT}}, -- Two separate horizontal dead ends
        flippable = false -- Looks the same when flipped
    },
    [CARD_TYPES.PATH_2_2C] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.RIGHT}, {DIRECTION.BOTTOM}}, -- Two separate dead ends (right and bottom)
        flippable = true -- Can be flipped to get top-left configuration
    },
    [CARD_TYPES.PATH_2_2D] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.BOTTOM}, {DIRECTION.LEFT}}, -- Two separate dead ends (bottom and left)
        flippable = true -- Can be flipped to get top-right configuration
    },
    [CARD_TYPES.PATH_3_3A] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.TOP}, {DIRECTION.RIGHT}, {DIRECTION.BOTTOM}}, -- Three separate dead ends
        flippable = true -- Can be flipped to get left-top-right configuration
    },
    [CARD_TYPES.PATH_3_3B] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT}, {DIRECTION.TOP}, {DIRECTION.RIGHT}}, -- Three separate dead ends
        flippable = true -- Can be flipped to get left-bottom-right configuration
    },
    [CARD_TYPES.PATH_4_4] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.TOP}, {DIRECTION.RIGHT}, {DIRECTION.BOTTOM}, {DIRECTION.LEFT}}, -- Four separate dead ends
        flippable = false -- Looks the same when flipped
    },
    [CARD_TYPES.EMPTY] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = false},
        paths = {}, -- No paths
        flippable = false -- Empty card looks the same when flipped
    }
}

-- Card images mapping
local CARD_IMAGES = {
    [CARD_TYPES.PATH_1_1A] = "path_1_1a.png",
    [CARD_TYPES.PATH_1_1B] = "path_1_1b.png",
    [CARD_TYPES.PATH_2_1A] = "path_2_1a.png",
    [CARD_TYPES.PATH_2_1B] = "path_2_1b.png",
    [CARD_TYPES.PATH_2_1C] = "path_2_1c.png",
    [CARD_TYPES.PATH_2_1D] = "path_2_1d.png",
    [CARD_TYPES.PATH_3_1A] = "path_3_1a.png",
    [CARD_TYPES.PATH_3_1B] = "path_3_1b.png",
    [CARD_TYPES.PATH_4_1] = "path_4_1.png",
    [CARD_TYPES.PATH_2_2A] = "path_2_2a.png",
    [CARD_TYPES.PATH_2_2B] = "path_2_2b.png",
    [CARD_TYPES.PATH_2_2C] = "path_2_2c.png",
    [CARD_TYPES.PATH_2_2D] = "path_2_2d.png",
    [CARD_TYPES.PATH_3_3A] = "path_3_3a.png",
    [CARD_TYPES.PATH_3_3B] = "path_3_3b.png",
    [CARD_TYPES.PATH_4_4] = "path_4_4.png",
    [CARD_TYPES.EMPTY] = "empty.png"
}

-- Import UI module
local ui = require("ui")
local story = require("story") -- Add the story module import

-- Game state
local game = {
    cards = {},      -- Current cards in player's hand
    dragging = nil,  -- Currently dragged card
    field = {},      -- Cards permanently placed on the field
    plannedCards = {}, -- Cards marked as planned but not yet built
    deck = {         -- Deck of cards
        cards = {},  -- Actual card types in the deck
        count = 0,   -- Number of cards in deck
    },
    discard = {      -- Discard pile
        cards = {},  -- Actual card types in the discard pile
        count = 0,   -- Number of cards in discard
    },
    invalidPlacement = nil,  -- Tracks invalid placement feedback
    aliveTiles = {},   -- List of coordinates for "alive" tiles (reachable empty tiles)
    holdTiles = {},    -- List of coordinates for tiles adjacent to alive tiles (used for hold capacity)
    dangerTiles = {},  -- List of coordinates for tiles marked as danger zones
    shiftStartAliveTilesCount = 0, -- Number of alive tiles at the start of the shift
    currentHoldCapacity = 0,       -- Current hold capacity (based on connections to alive tiles)
    drawButtonHover = false,  -- Track if mouse is hovering over draw button
    CARD_PATH_DATA = CARD_PATH_DATA,  -- Make card path data accessible to UI
    canPlaceCard = nil, -- Function reference to be set in love.load
    holdCount = 0,   -- Number of cards currently on hold
    playCount = 0,   -- Number of cards played in the current round
    maxHoldCards = MAX_HOLD_CARDS,  -- Maximum number of cards that can be held
    maxPlayCards = MAX_PLAY_CARDS,   -- Maximum number of cards that can be played
    score = 0,       -- Player's score (100 points per tile placed)
    dayClock = {     -- Day clock state
        totalSegments = 6,      -- Total number of segments in the day (4, 5, or 6)
        remainingSegments = 6,  -- Number of segments remaining in the day
        day = 1                 -- Current day
    },
    isGameOver = false,  -- Flag to track if the game is over
    isDayOver = false,   -- Flag to track if a day has ended due to running out of cards
    isInitialStory = true,  -- Flag to track if we're showing the initial story for a day
    helpMenu = {        -- Help menu state
        visible = false,     -- Is the help menu currently visible
        buttonHover = false, -- Is mouse hovering over help button
        showAfterStory = true  -- Flag to show help menu after initial story
    },
    
    -- Function to calculate how many cards to draw based on alive tiles
    calculateDrawAmount = function(aliveTilesCount)
        return math.min(12, 1 + aliveTilesCount)
    end
}

-- Function called when the game is over
function game.over(reason)
    game.isGameOver = true
    game.isInitialStory = false  -- Set to false because game is over
    print("GAME OVER: " .. (reason or "Unknown reason"))
end

-- Game assets
local assets = {
    cards = {},      -- Card images
    font = nil,      -- Main font
    smallFont = nil, -- Small font for UI elements
    sounds = {       -- Sound effects
        dayStart = nil, -- Sound to play when day starts
        dig1 = nil,     -- Sound for digging 1
        dig2 = nil,     -- Sound for digging 2
        dig3 = nil,     -- Sound for digging 3
        shiftEnd1 = nil, -- Sound for end of shift 1
        shiftEnd2 = nil  -- Sound for end of shift 2
    },
    helpMenu = nil   -- Help menu image
}

-- Check if a card can be placed at given grid coordinates
function canPlaceCard(cardType, gridX, gridY, flipped)
    -- First check: is this position outside the depth limits?
    if isOutsideDepthLimits(gridX, gridY) then
        return false
    end
    
    -- Second check: is this an "alive" tile?
    local isAlive = false
    for _, tile in ipairs(game.aliveTiles) do
        if tile.x == gridX and tile.y == gridY then
            isAlive = true
            break
        end
    end
    
    if not isAlive then
        return false
    end
    
    -- Third check: do the edges match with adjacent cards (both permanent and planned)?
    local cardData = flipped and getFlippedCardData(cardType, true) or CARD_PATH_DATA[cardType]
    
    -- Check each adjacent cell for compatibility
    local adjacentCells = {
        top = {x = gridX, y = gridY - 1, direction = DIRECTION.BOTTOM, opposite = DIRECTION.TOP},
        right = {x = gridX + 1, y = gridY, direction = DIRECTION.LEFT, opposite = DIRECTION.RIGHT},
        bottom = {x = gridX, y = gridY + 1, direction = DIRECTION.TOP, opposite = DIRECTION.BOTTOM},
        left = {x = gridX - 1, y = gridY, direction = DIRECTION.RIGHT, opposite = DIRECTION.LEFT},
    }
    
    -- For each adjacent cell, check if its matching edge is compatible
    for position, adjacent in pairs(adjacentCells) do
        local adjacentPos = adjacent.y .. "," .. adjacent.x
        local adjacentCardData = game.field[adjacentPos] or game.plannedCards[adjacentPos]
        
        -- If there's a card adjacent, check edge compatibility
        if adjacentCardData then
            local adjacentCard = adjacentCardData.flipped and 
                                 getFlippedCardData(adjacentCardData.type, true) or 
                                 CARD_PATH_DATA[adjacentCardData.type]
            
            -- First, check if both edges have openings or both are closed
            if cardData.edges[adjacent.opposite] ~= adjacentCard.edges[adjacent.direction] then
                return false
            end
            
            -- If both edges have openings, they're compatible
            -- We don't need the complex path checking as all edges that have openings
            -- are valid connections in this game. Dead ends and paths can connect together.
        end
    end
    
    return true
end

-- Get the flipped version of a card type (rotated 180 degrees)
function getFlippedCardData(cardType, isFlipped)
    local data = CARD_PATH_DATA[cardType]
    
    -- If not flippable or not flipped, return original data
    if not data.flippable or not isFlipped then
        return data
    end
    
    -- Create flipped version (180 degree rotation)
    local flippedData = {
        edges = {},
        paths = {}
    }
    
    -- Flip edges (TOP ↔ BOTTOM, LEFT ↔ RIGHT)
    flippedData.edges[DIRECTION.TOP] = data.edges[DIRECTION.BOTTOM]
    flippedData.edges[DIRECTION.RIGHT] = data.edges[DIRECTION.LEFT]
    flippedData.edges[DIRECTION.BOTTOM] = data.edges[DIRECTION.TOP]
    flippedData.edges[DIRECTION.LEFT] = data.edges[DIRECTION.RIGHT]
    
    -- Flip paths
    for i, path in ipairs(data.paths) do
        flippedData.paths[i] = {}
        for j, dir in ipairs(path) do
            -- Flip direction (TOP ↔ BOTTOM, LEFT ↔ RIGHT)
            if dir == DIRECTION.TOP then
                flippedData.paths[i][j] = DIRECTION.BOTTOM
            elseif dir == DIRECTION.RIGHT then
                flippedData.paths[i][j] = DIRECTION.LEFT
            elseif dir == DIRECTION.BOTTOM then
                flippedData.paths[i][j] = DIRECTION.TOP
            elseif dir == DIRECTION.LEFT then
                flippedData.paths[i][j] = DIRECTION.RIGHT
            end
        end
    end
    
    return flippedData
end

function love.load()
    -- Load fonts
    assets.font = love.graphics.newFont(16)
    assets.smallFont = love.graphics.newFont(12)
    
    -- Load card images
    for type, filename in pairs(CARD_IMAGES) do
        assets.cards[type] = love.graphics.newImage("img/" .. filename)
    end
    
    -- Load help menu image
    assets.helpMenu = love.graphics.newImage("img/help_menu.png")
    
    -- Load sound effects
    assets.sounds.dayStart = love.audio.newSource("sounds/foreman.wav", "static")
    -- Set initial volume to very high (values > 1.0 are allowed and make it louder)
    assets.sounds.dayStart:setVolume(2.0)
    
    -- Load dig sounds
    assets.sounds.dig1 = love.audio.newSource("sounds/dig.wav", "static")
    assets.sounds.dig2 = love.audio.newSource("sounds/dig2.wav", "static")
    assets.sounds.dig3 = love.audio.newSource("sounds/dig3.wav", "static")
    assets.sounds.dig1:setVolume(1.5)
    assets.sounds.dig2:setVolume(1.5)
    assets.sounds.dig3:setVolume(1.5)
    
    -- Load shift end sounds
    assets.sounds.shiftEnd1 = love.audio.newSource("sounds/shift_end1.wav", "static")
    assets.sounds.shiftEnd2 = love.audio.newSource("sounds/shift_end2.wav", "static")
    assets.sounds.shiftEnd1:setVolume(1.5)
    assets.sounds.shiftEnd2:setVolume(1.5)
    
    -- Set up the canPlaceCard function reference
    game.canPlaceCard = canPlaceCard
    
    -- Initialize the UI module
    ui.init(game, assets, viewport, DIRECTION)
    
    -- Generate the deck
    generateDeck()
    
    -- Generate the initial mineshaft structure
    generateInitialMineshaft()
    
    -- Initialize RNG
    love.math.setRandomSeed(os.time())
    
    -- Initialize the day clock
    local day1Shifts = story.messages[1] and story.messages[1].shifts or 6
    setDayClockSegments(day1Shifts)  -- Use shifts from day 1 story or default to 6
    
    -- Initialize tracking values for alive tiles and hold capacity
    game.shiftStartAliveTilesCount = #game.aliveTiles
    game.currentHoldCapacity = calculateCurrentHoldCapacity()
    game.maxPlayCards = math.min(game.shiftStartAliveTilesCount,7) -- Maximum cards playable this shift
    game.maxHoldCards = game.currentHoldCapacity  -- Hold limit is based only on connections to alive tiles
    
    -- Don't initialize danger tiles at the start - let them be set at the end of the first day
    
    -- Draw initial hand (held cards are 0 at the beginning)
    local initialCards = game.calculateDrawAmount(game.shiftStartAliveTilesCount)
    drawCardsFromDeck(initialCards)
    
    -- Show the story screen at the start of the game
    story.showDayStory(1)
end

function updateHandPositions()
    local cardSpacingX = CARD_WIDTH + 5
    local handStartX = 16
    local handStartY = SCREEN_HEIGHT - HAND_HEIGHT + 0
    
    for i, card in ipairs(game.cards) do
        local row = math.ceil(i / HAND_CARDS_PER_ROW)
        local col = (i - 1) % HAND_CARDS_PER_ROW + 1
        
        card.x = handStartX + (col - 1) * cardSpacingX
        card.y = handStartY + (row - 1) * (CARD_HEIGHT + 5)
        
        -- Lift held cards up by 8 pixels
        if card.held then
            card.y = card.y - 4
        end
    end
end

-- Convert grid coordinates to screen position
function gridToScreen(gridX, gridY)
    return GRID_OFFSET_X + gridX * GRID_CELL_SIZE - viewport.offsetX, 
           GRID_OFFSET_Y + gridY * GRID_CELL_HEIGHT - viewport.offsetY
end

-- Convert screen position to grid coordinates
function screenToGrid(screenX, screenY)
    return math.floor((screenX - GRID_OFFSET_X + viewport.offsetX) / GRID_CELL_SIZE),
           math.floor((screenY - GRID_OFFSET_Y + viewport.offsetY) / GRID_CELL_HEIGHT)
end

function love.update(dt)
    -- Don't update when game is over or day over screen is showing
    if game.isGameOver or game.isDayOver then
        return
    end
    
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Update ui hover states
    ui.updateHoverStates(mouseX, mouseY)
    
    -- Update help button hover state
    ui.updateHelpButtonHover(mouseX, mouseY)
    
    -- Handle card dragging
    if game.dragging then
        game.dragging.x = love.mouse.getX() - CARD_WIDTH / 2
        game.dragging.y = love.mouse.getY() - CARD_HEIGHT / 2
    end
    
    -- Handle viewport dragging
    if viewport.dragging then
        local dx = mouseX - viewport.lastMouseX
        local dy = mouseY - viewport.lastMouseY
        
        -- Only scroll field area, not hand area
        if love.mouse.getY() < FIELD_HEIGHT then
            viewport.offsetX = viewport.offsetX - dx
            viewport.offsetY = viewport.offsetY - dy
            
            -- Restrict horizontal scrolling to +/-VIEWPORT_MAX_HORIZONTAL cells
            local maxHorizontalOffset = GAME_FIELD_WIDTH_EXTENSION * GRID_CELL_SIZE
            viewport.offsetX = math.max(-maxHorizontalOffset, math.min(maxHorizontalOffset, viewport.offsetX))
            
            -- Restrict vertical scrolling to prevent seeing too far above surface
            viewport.offsetY = math.max(-GRID_OFFSET_Y, viewport.offsetY)
        end
        
        viewport.lastMouseX = mouseX
        viewport.lastMouseY = mouseY
    end
    
    -- Update invalid placement feedback timer
    if game.invalidPlacement then
        game.invalidPlacement.time = game.invalidPlacement.time - dt
        if game.invalidPlacement.time <= 0 then
            game.invalidPlacement = nil
        end
    end
    
    -- Check if mouse is hovering over draw button
    local mx, my = love.mouse.getPosition()
    local drawButtonX = SCREEN_WIDTH - 96
    local drawButtonY = FIELD_HEIGHT + 10 + CARD_HEIGHT + 10
    local drawButtonWidth = CARD_WIDTH * 2
    local drawButtonHeight = 30
    
    game.drawButtonHover = pointInRect(mx, my, drawButtonX, drawButtonY, drawButtonWidth, drawButtonHeight)
end

-- Mouse pressed callback
function love.mousepressed(x, y, button)
    -- Don't process clicks when game is over
    if game.isGameOver then
        return
    end
    
    -- Handle click when day over screen is showing
    if game.isDayOver then
        if button == 1 then -- Left mouse button
            handleDayOverClick()
        end
        return
    end
    
    -- Check if help menu is visible
    if game.helpMenu.visible then
        if button == 1 then -- Left mouse button
            game.helpMenu.visible = false -- Close help menu
        end
        return
    end
    
    -- Check if help button was clicked
    if game.helpMenu.buttonHover and button == 1 then
        game.helpMenu.visible = true
        return
    end
    
    if button == 1 then  -- Left mouse button
        -- Check if draw button was clicked
        local drawButtonX = SCREEN_WIDTH - 48
        local drawButtonY = FIELD_HEIGHT + 10 + CARD_HEIGHT + 10
        local drawButtonWidth = CARD_WIDTH
        local drawButtonHeight = 30
        
        if pointInRect(x, y, drawButtonX, drawButtonY, drawButtonWidth, drawButtonHeight) then
            -- End Shift: Build all planned cards and advance the day clock
            endShift()
            return
        end
        
        -- If we're in the field area (not hand)
        if y < FIELD_HEIGHT then
            local gridX, gridY = screenToGrid(x, y)
            local position = gridY .. "," .. gridX
            
            -- Check if we clicked on a planned card
            if game.plannedCards[position] then
                -- Start dragging a planned card back to hand
                local cardType = game.plannedCards[position].type
                local flipped = game.plannedCards[position].flipped
                
                -- Create a temporary drag object for this card
                game.dragging = {
                    type = cardType,
                    flipped = flipped,
                    x = x - CARD_WIDTH / 2,
                    y = y - CARD_HEIGHT / 2,
                    isPlanned = true,
                    plannedPosition = position
                }
                
                -- Don't remove from plannedCards yet, we'll do that if it's successfully returned to hand
                return
            end
            
            -- Check if we clicked on a card in hand
            local cardClicked = false
            for i, card in ipairs(game.cards) do
                if x >= card.x and x <= card.x + CARD_WIDTH and
                   y >= card.y and y <= card.y + CARD_HEIGHT then
                    game.dragging = card
                    cardClicked = true
                    break
                end
            end
            
            -- If not dragging a card, start viewport dragging
            if not cardClicked and not game.dragging then
                viewport.dragging = true
                viewport.lastMouseX = x
                viewport.lastMouseY = y
            end
        else
            -- In hand area, check for card dragging or toggle hold state
            local cardClicked = false
            for i, card in ipairs(game.cards) do
                if x >= card.x and x <= card.x + CARD_WIDTH and
                   y >= card.y and y <= card.y + CARD_HEIGHT then
                    -- Track initial click position to determine if this is a drag or a click
                    card.clickX = x
                    card.clickY = y
                    game.dragging = card
                    cardClicked = true
                    break
                end
            end
        end
    elseif button == 2 then  -- Right mouse button
        -- Check if we clicked on a card in hand to flip it
        for i, card in ipairs(game.cards) do
            if x >= card.x and x <= card.x + CARD_WIDTH and
               y >= card.y and y <= card.y + CARD_HEIGHT then
                -- Only flip if card is flippable
                if CARD_PATH_DATA[card.type].flippable then
                    card.flipped = not card.flipped
                end
                break
            end
        end
    end
end

-- Mouse released callback
function love.mousereleased(x, y, button)
    -- Don't process when game is over or day over screen is showing
    if game.isGameOver or game.isDayOver or game.helpMenu.visible then
        return
    end
    
    if button == 1 then  -- Left mouse button
        -- Stop viewport dragging
        viewport.dragging = false
        
        -- Handle card placement if dragging a card
        if game.dragging then
            -- Special handling for planned cards being returned to hand
            if game.dragging.isPlanned then
                -- If released in the hand area or in an invalid field position, return to hand
                local returnToHand = y >= FIELD_HEIGHT  -- If in hand area
                
                if not returnToHand and y < FIELD_HEIGHT then
                    -- Check if this is a valid field position
                    local gridX, gridY = screenToGrid(x, y)
                    local screenX, screenY = gridToScreen(gridX, gridY)
                    
                    -- Check if out of bounds or over UI
                    if screenX + CARD_WIDTH > FIELD_WIDTH or screenX < 0 or 
                       screenY < 40 or screenY > FIELD_HEIGHT then
                        returnToHand = true
                    else
                        -- Check if card can be placed here (if it's a different location)
                        local newPosition = gridY .. "," .. gridX
                        if newPosition ~= game.dragging.plannedPosition and
                           not canPlaceCard(game.dragging.type, gridX, gridY, game.dragging.flipped) then
                            returnToHand = true
                        else
                            -- If it's a different but valid location, update the planned card position
                            if newPosition ~= game.dragging.plannedPosition then
                                -- Store the card data
                                local cardData = game.plannedCards[game.dragging.plannedPosition]
                                -- Remove from old position
                                game.plannedCards[game.dragging.plannedPosition] = nil
                                -- Add to new position
                                game.plannedCards[newPosition] = cardData
                                
                                -- Get original position coordinates for alive tiles update
                                local gridY, gridX = string.match(game.dragging.plannedPosition, "(%d+),([%-%d]+)")
                                gridX, gridY = tonumber(gridX), tonumber(gridY)
                                
                                -- Add the tile back to alive tiles
                                if gridX ~= nil and gridY ~= nil then
                                    addToAliveTiles(gridX, gridY)
                                else
                                    print("Warning: Invalid position format when returning to hand: " .. game.dragging.plannedPosition)
                                end
                            end
                        end
                    end
                end
                
                if returnToHand then
                    -- Add the card back to hand
                    table.insert(game.cards, {
                        id = love.math.random(1000),
                        x = 0,
                        y = 0,
                        type = game.dragging.type,
                        flipped = game.dragging.flipped,
                        held = false
                    })
                    
                    -- Get original position coordinates for alive tiles update
                    local gridY, gridX = string.match(game.dragging.plannedPosition, "(%d+),([%-%d]+)")
                    gridX, gridY = tonumber(gridX), tonumber(gridY)
                    
                    -- Remove from planned cards
                    game.plannedCards[game.dragging.plannedPosition] = nil
                    
                    -- Add the tile back to alive tiles
                    if gridX ~= nil and gridY ~= nil then
                        addToAliveTiles(gridX, gridY)
                    else
                        print("Warning: Invalid position format when returning to hand: " .. game.dragging.plannedPosition)
                    end
                    
                    -- Decrement play count
                    game.playCount = game.playCount - 1
                    
                    -- Update hand positions
                    updateHandPositions()
                end
                
                -- Reset dragging
                game.dragging = nil
                return
            end
            
            -- Check if this was a click (minimal movement) or a drag
            local wasDragged = false
            if game.dragging.clickX and game.dragging.clickY then
                local dx = x - game.dragging.clickX
                local dy = y - game.dragging.clickY
                wasDragged = math.abs(dx) > 5 or math.abs(dy) > 5
                
                -- Clear click tracking
                game.dragging.clickX = nil
                game.dragging.clickY = nil
            end
            
            -- If it was a click in the hand area, toggle hold state
            if not wasDragged and y >= FIELD_HEIGHT then
                -- Toggle hold state only if not exceeding max hold cards
                if not game.dragging.held and game.holdCount < game.maxHoldCards then
                    game.dragging.held = true
                    game.holdCount = game.holdCount + 1
                elseif game.dragging.held then
                    game.dragging.held = false
                    game.holdCount = game.holdCount - 1
                end
                
                -- Keep dragging as nil to indicate no movement
                game.dragging = nil
                updateHandPositions()
                return
            end
            
            -- Check if card was dropped on the field
            if y < FIELD_HEIGHT then
                -- Convert screen position to grid
                local gridX, gridY = screenToGrid(x, y)
                
                -- Check if this is a valid cell for a card (needs enough space and not behind status bar)
                local screenX, screenY = gridToScreen(gridX, gridY)
                if screenX + CARD_WIDTH <= FIELD_WIDTH and screenX >= 0 and screenY >= 40 and screenY <= FIELD_HEIGHT then
                   
                    -- Check if the card can be placed at this location (connections are valid)
                    if canPlaceCard(game.dragging.type, gridX, gridY, game.dragging.flipped) then
                        -- If the card was held, decrement hold count
                        if game.dragging.held then
                            game.holdCount = game.holdCount - 1
                        end
                        
                        -- Place card in plannedCards instead of directly on field
                        game.plannedCards[gridY .. "," .. gridX] = {
                            type = game.dragging.type,
                            flipped = game.dragging.flipped,
                            rotation = 0  -- No rotation for now
                        }
                        
                        -- Play a random dig sound when planning a card
                        playDigSound()
                        
                        -- Increment play count
                        game.playCount = game.playCount + 1
                        
                        -- Remove card from hand
                        for i, card in ipairs(game.cards) do
                            if card == game.dragging then
                                table.remove(game.cards, i)
                                break
                            end
                        end
                        
                        -- Remove the tile from alive tiles (since a planned card is occupying it)
                        removeFromAliveTiles(gridX, gridY)
                    else
                        -- Card connections don't match or not an alive tile
                        -- provide visual feedback
                        game.invalidPlacement = {
                            x = gridX,
                            y = gridY,
                            time = 0.5  -- Display feedback for half a second
                        }
                    end
                end
            end
            
            -- Reset dragging state and update hand positions
            game.dragging = nil
            updateHandPositions()
        end
    end
end

function love.draw()
    -- Call the UI module's draw function
    ui.draw()
end

function love.keypressed(key)
    if key == "d" then
        -- Debug key to test advancing the day clock
        advanceDayClock()
    elseif key == "e" and game.isDayOver == false and game.isGameOver == false then
        endShift()
    end
end

-- End the current shift, build all planned cards, and advance the day
function endShift()
    -- If the game is over, don't allow further shifts
    if game.isGameOver then
        return
    end
    
    -- Play a random shift end sound
    playShiftEndSound()
    
    -- Count the number of planned cards for scoring
    local cardsBuilt = 0
    
    -- First, build all planned cards (move them to the field)
    for pos, cardData in pairs(game.plannedCards) do
        -- Add to permanent field
        game.field[pos] = cardData
        cardsBuilt = cardsBuilt + 1
    end
    
    -- Award 100 points per card built
    game.score = game.score + (cardsBuilt * 100)
    
    -- Clear the planned cards
    game.plannedCards = {}
    
    -- Reset play count
    game.playCount = 0
    
    -- Update alive tiles list
    updateAliveTiles()
    
    -- Check if there are no more alive tiles (game over condition)
    if #game.aliveTiles == 0 then
        game.isGameOver = true
        game.gameOverReason = "No more playable spaces available"
        return
    end
    
    -- Advance the day clock
    advanceDayClock()
    
    -- Update the current hold capacity
    game.currentHoldCapacity = calculateCurrentHoldCapacity()
    game.maxHoldCards = game.currentHoldCapacity
    
    -- Set the maximum playable cards for this shift
    game.shiftStartAliveTilesCount = #game.aliveTiles
    game.maxPlayCards = math.min(game.shiftStartAliveTilesCount, 7)
    
    -- Discard non-held cards before drawing new ones
    discardHand()
    
    -- Draw new cards for this shift
    local drawAmount = game.calculateDrawAmount(#game.aliveTiles)
    
    -- Only end the day if we have absolutely no cards available
    if drawAmount <= 0 or #game.deck.cards == 0 then
        game.endDay("Run out of cards")
        return
    end
    
    -- Draw the cards
    drawCardsFromDeck(drawAmount)

    
    -- Update the hand positions
    updateHandPositions()
    
    -- No more cards held
    unholdAllCards();
    
end

-- Generate the initial mineshaft structure
function generateInitialMineshaft()
    -- Clear the field
    game.field = {}
    
    -- Center column position
    local centerX = math.floor(GRID_COLS / 2 - 1)
    
    -- First tile: Straight vertical path at the top
    game.field["0," .. centerX] = {
        type = CARD_TYPES.PATH_2_1A,
        flipped = false,
        rotation = 0
    }
    
    -- Second tile: Random connector that goes down (with possible branches)
    local secondTileOptions = {
        CARD_TYPES.PATH_2_1A,  -- Straight down
        CARD_TYPES.PATH_3_1A,  -- T-junction right
        CARD_TYPES.PATH_4_1    -- Cross junction
    }
    local secondTileType = secondTileOptions[love.math.random(1, #secondTileOptions)]

    game.field["1," .. centerX] = {
        type = secondTileType,
        flipped = false,
        rotation = 0
    }
    
    
    -- Third tile: Random tile that connects to the top and isn't too dead endy
    local thirdTileOptions = {
        CARD_TYPES.PATH_3_1A,  -- T-junction right
        CARD_TYPES.PATH_3_1B,  -- T-junction top
        CARD_TYPES.PATH_4_1  -- Cross junction
    }
    -- If the second tile is straight, we should branch out at the end
    if secondTileType ~= CARD_TYPES.PATH_2_1A then
        table.insert(thirdTileOptions, CARD_TYPES.PATH_2_1A)
        table.insert(thirdTileOptions, CARD_TYPES.PATH_2_1C)
        table.insert(thirdTileOptions, CARD_TYPES.PATH_2_1D)
    end

    local thirdTileType = thirdTileOptions[love.math.random(1, #thirdTileOptions)]
    local flip = false
    if(thirdTileType == CARD_TYPES.PATH_2_1C or thirdTileType == CARD_TYPES.PATH_2_1D) then
    flip = true
    end
    game.field["2," .. centerX] = {
        type = thirdTileType,
        flipped = flip,
        rotation = 0
    }
    
    -- Update alive tiles after placing the initial structure
    updateAliveTiles()
end

-- Update the list of "alive" tiles (empty tiles reachable from the mineshaft)
function updateAliveTiles()
    -- Clear the current list
    game.aliveTiles = {}
    
    -- Center column position (same as used in generateInitialMineshaft)
    local centerX = math.floor(GRID_COLS / 2 - 1)
    
    -- Helper function to check if a tile is empty
    local function isTileEmpty(x, y)
        local pos = y .. "," .. x
        return game.field[pos] == nil and game.plannedCards[pos] == nil
    end
    
    -- Helper function to check if a specific coordinate is already in alive tiles
    local function isInAliveTiles(x, y)
        for _, tile in ipairs(game.aliveTiles) do
            if tile.x == x and tile.y == y then
                return true
            end
        end
        return false
    end
    
    -- Helper function to check if a position is within valid game boundaries
    local function isWithinBoundaries(x, y)
        -- Check horizontal boundaries
        if x < -GAME_FIELD_WIDTH_EXTENSION or x >= GRID_COLS + GAME_FIELD_WIDTH_EXTENSION then
            return false
        end
        
        -- Check vertical boundaries - prevent tiles above the surface (y < 0)
        if y < 0 or y >= GRID_ROWS + GAME_FIELD_DEPTH then
            return false
        end
        
        -- Get current day's depth goal and minimum depth
        local depthGoal = 0
        local minDepth = 0
        
        if story.messages[game.dayClock.day] then
            depthGoal = story.messages[game.dayClock.day].depthgoal or 0
            minDepth = story.messages[game.dayClock.day].mindepth or 0
        end
        
        -- Convert depths to Y coordinates (depth/10)
        local maxY = math.ceil(depthGoal / 10) + 2  -- Allow digging 20 meters (2 tiles) below the depth goal
        local minY = math.floor(minDepth / 10)      -- Don't allow digging above the minimum depth
        
        -- Check depth limits - but only if we have a valid depth goal
        if depthGoal > 0 then
            -- Prevent tiles below maximum allowed depth
            if y > maxY then
                return false
            end
            
            -- Prevent tiles above minimum required depth
            if minDepth > 0 and y < minY then
                return false
            end
        end
        
        return true
    end
    
    -- First check all permanent cards on the field
    for pos, cardData in pairs(game.field) do
        local y, x = string.match(pos, "(%d+),([%-%d]+)")
        x, y = tonumber(x), tonumber(y)
        
        -- Skip invalid coordinates
        if x == nil or y == nil then
            print("Warning: Invalid position format in updateAliveTiles (field): " .. pos)
        end
        
        -- Get the card data with flip state considered
        local pathData = cardData.flipped and 
                         getFlippedCardData(cardData.type, true) or 
                         CARD_PATH_DATA[cardData.type]
        
        -- Check each direction for open paths
        local adjacentPositions = {
            {dir = DIRECTION.TOP, x = x, y = y - 1},
            {dir = DIRECTION.RIGHT, x = x + 1, y = y},
            {dir = DIRECTION.BOTTOM, x = x, y = y + 1},
            {dir = DIRECTION.LEFT, x = x - 1, y = y}
        }
        
        for _, adj in ipairs(adjacentPositions) do
            -- First check if the edge has a path
            if pathData.edges[adj.dir] then
                -- Check if this edge is part of a dead end (single-direction path)
                local isDeadEnd = true
                
                -- Find which path this edge belongs to
                for _, path in ipairs(pathData.paths) do
                    -- Check if this path contains our direction
                    local containsDir = false
                    for _, dir in ipairs(path) do
                        if dir == adj.dir then
                            containsDir = true
                            break
                        end
                    end
                    
                    -- If this path contains our direction and has multiple connections, it's not a dead end
                    if containsDir and #path > 1 then
                        isDeadEnd = false
                        break
                    end
                end
                
                -- Only consider this tile alive if:
                -- 1. The edge is not a dead end
                -- 2. The adjacent tile is empty
                -- 3. The adjacent tile is not the mineshaft entrance (0, centerX)
                -- 4. The adjacent tile is within game boundaries
                if not isDeadEnd and isTileEmpty(adj.x, adj.y) and 
                   not (adj.y == 0 and adj.x == centerX) and 
                   isWithinBoundaries(adj.x, adj.y) then
                    -- And if it's not already in our alive tiles list
                    if not isInAliveTiles(adj.x, adj.y) then
                        -- Add to alive tiles
                        table.insert(game.aliveTiles, {x = adj.x, y = adj.y})
                    end
                end
            end
        end
    end
    
    -- Then check all planned cards (for additional alive tiles)
    for pos, cardData in pairs(game.plannedCards) do
        local y, x = string.match(pos, "(%d+),([%-%d]+)")
        x, y = tonumber(x), tonumber(y)
        
        -- Skip invalid coordinates
        if x == nil or y == nil then
            print("Warning: Invalid position format in updateAliveTiles (plannedCards): " .. pos)
        end
        
        -- Get the card data with flip state considered
        local pathData = cardData.flipped and 
                         getFlippedCardData(cardData.type, true) or 
                         CARD_PATH_DATA[cardData.type]
        
        -- Check each direction for open paths
        local adjacentPositions = {
            {dir = DIRECTION.TOP, x = x, y = y - 1},
            {dir = DIRECTION.RIGHT, x = x + 1, y = y},
            {dir = DIRECTION.BOTTOM, x = x, y = y + 1},
            {dir = DIRECTION.LEFT, x = x - 1, y = y}
        }
        
        for _, adj in ipairs(adjacentPositions) do
            -- First check if the edge has a path
            if pathData.edges[adj.dir] then
                -- Check if this edge is part of a dead end (single-direction path)
                local isDeadEnd = true
                
                -- Find which path this edge belongs to
                for _, path in ipairs(pathData.paths) do
                    -- Check if this path contains our direction
                    local containsDir = false
                    for _, dir in ipairs(path) do
                        if dir == adj.dir then
                            containsDir = true
                            break
                        end
                    end
                    
                    -- If this path contains our direction and has multiple connections, it's not a dead end
                    if containsDir and #path > 1 then
                        isDeadEnd = false
                        break
                    end
                end
                
                -- Only consider this tile alive if:
                -- 1. The edge is not a dead end
                -- 2. The adjacent tile is empty
                -- 3. The adjacent tile is not the mineshaft entrance (0, centerX)
                -- 4. The adjacent tile is within game boundaries
                if not isDeadEnd and isTileEmpty(adj.x, adj.y) and 
                   not (adj.y == 0 and adj.x == centerX) and
                   isWithinBoundaries(adj.x, adj.y) then
                    -- And if it's not already in our alive tiles list
                    if not isInAliveTiles(adj.x, adj.y) then
                        -- Add to alive tiles
                        table.insert(game.aliveTiles, {x = adj.x, y = adj.y})
                    end
                end
            end
        end
    end
end

-- Generate the deck of cards according to specified quantities
function generateDeck()
    -- Clear the deck
    game.deck.cards = {}
    
    -- Add cards according to specified quantities
    -- Dead ends
    table.insert(game.deck.cards, CARD_TYPES.PATH_1_1A)
    table.insert(game.deck.cards, CARD_TYPES.PATH_1_1B)
    
    -- Straight and curve paths
    for i = 1, 4 do table.insert(game.deck.cards, CARD_TYPES.PATH_2_1A) end
    for i = 1, 4 do table.insert(game.deck.cards, CARD_TYPES.PATH_2_1B) end
    for i = 1, 5 do table.insert(game.deck.cards, CARD_TYPES.PATH_2_1C) end
    for i = 1, 5 do table.insert(game.deck.cards, CARD_TYPES.PATH_2_1D) end
    
    -- T-junctions
    for i = 1, 4 do table.insert(game.deck.cards, CARD_TYPES.PATH_3_1A) end
    for i = 1, 4 do table.insert(game.deck.cards, CARD_TYPES.PATH_3_1B) end
    
    -- Cross junction
    for i = 1, 5 do table.insert(game.deck.cards, CARD_TYPES.PATH_4_1) end
    
    -- Special cards (one of each)
    table.insert(game.deck.cards, CARD_TYPES.PATH_2_2A)
    table.insert(game.deck.cards, CARD_TYPES.PATH_2_2B)
    table.insert(game.deck.cards, CARD_TYPES.PATH_2_2C)
    table.insert(game.deck.cards, CARD_TYPES.PATH_2_2D)
    
    table.insert(game.deck.cards, CARD_TYPES.PATH_3_3A)
    table.insert(game.deck.cards, CARD_TYPES.PATH_3_3B)
    
    table.insert(game.deck.cards, CARD_TYPES.PATH_4_4)
    
    -- Add empty cards on day 4 and beyond
    if game.dayClock and game.dayClock.day >= 4 then
        -- Add 5 empty cards to the deck to increase difficulty
        for i = 1, 5 do 
            table.insert(game.deck.cards, CARD_TYPES.EMPTY) 
        end
        print("Added 5 empty cards to the deck on day " .. game.dayClock.day)
    end
    
    -- Update the count
    game.deck.count = #game.deck.cards
    
    -- Shuffle the deck
    shuffleDeck()
end

-- Shuffle the deck of cards
function shuffleDeck()
    -- Fisher-Yates shuffle algorithm
    for i = #game.deck.cards, 2, -1 do
        local j = love.math.random(i)
        game.deck.cards[i], game.deck.cards[j] = game.deck.cards[j], game.deck.cards[i]
    end
end

-- Discard all cards from hand
function discardHand()
    -- Move all non-held cards from hand to discard pile
    local i = 1
    while i <= #game.cards do
        local card = game.cards[i]
        if not card.held then
            table.insert(game.discard.cards, card.type)
            game.discard.count = game.discard.count + 1
            table.remove(game.cards, i)
        else
            i = i + 1
        end
    end
    
    -- Reset play count for the new round
    game.playCount = 0
    
    -- Only end the day if the deck is completely empty
    if game.deck.count == 0 and game.discard.count > 0 then
        game.endDay("Run out of cards")
    end
    
    -- Update hand positions after removing cards
    updateHandPositions()
end

-- Function to reset all cards' held status
function unholdAllCards()
    -- Reset the hold count
    game.holdCount = 0
    
    -- Set all cards to unheld
    for _, card in ipairs(game.cards) do
        card.held = false
    end
    
    -- Update hand positions
    updateHandPositions()
end

-- Draw cards from the deck to fill the player's hand
function drawCardsFromDeck(numCards)
    -- Default to drawing up to hand capacity if not specified
    local handCapacity = HAND_CARDS_PER_ROW * HAND_ROWS
    numCards = numCards or (handCapacity - #game.cards)
    
    -- Limit by how many cards are actually available
    numCards = math.min(numCards, game.deck.count)
    
    -- Only end the day if we have absolutely no cards to draw
    if game.deck.count == 0 and game.discard.count > 0 then
        game.endDay("Run out of cards")
        return 0
    end
    
    -- Draw cards from the deck to the hand
    for i = 1, numCards do
        if #game.deck.cards > 0 then
            local cardType = table.remove(game.deck.cards, 1)
            game.deck.count = game.deck.count - 1
            
            -- Add card to hand
            table.insert(game.cards, { 
                id = love.math.random(1000),  -- Generate a unique ID 
                x = 0, 
                y = 0, 
                type = cardType, 
                flipped = false,
                held = false
            })
        end
    end
    
    -- Update hand positions
    updateHandPositions()
    
    return numCards
end

-- Check if point is within rectangle
function pointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

-- Functions for manipulating the day clock
function setDayClockSegments(numSegments)
    -- Validate and set the number of segments (4, 5, or 6 are valid)
    if numSegments >= 4 and numSegments <= 6 then
        game.dayClock.totalSegments = numSegments
        game.dayClock.remainingSegments = numSegments
        return true
    end
    return false
end

function advanceDayClock()
    -- Remove one segment from the clock
    if game.dayClock.remainingSegments > 0 then
        game.dayClock.remainingSegments = game.dayClock.remainingSegments - 1
        
        -- If we've reached the end of the day, set day over state and prepare for next day
        if game.dayClock.remainingSegments == 0 then
            -- Before preparing for the next day, check if there are any danger tiles remaining
            -- Only check for game over condition after the first day
            if game.dayClock.day > 1 and #game.dangerTiles > 0 then
                game.over("Danger tiles remain at the end of the day")
                return false
            end
            
            -- End the day with reason
            game.endDay("Used all shifts for the day")
            
            return true  -- Return true to indicate a day change
        end
    end
    return false  -- Return false to indicate no day change
end

function resetDayClock()
    -- Reset the clock to full segments without changing the day
    game.dayClock.remainingSegments = game.dayClock.totalSegments
end

function getDayClockState()
    -- Return a copy of the current day clock state
    return {
        totalSegments = game.dayClock.totalSegments,
        remainingSegments = game.dayClock.remainingSegments,
        day = game.dayClock.day
    }
end

-- Helper function to add a specific tile to alive tiles if it meets criteria
function addToAliveTiles(x, y)
    -- Check if this position should be an alive tile
    local isAlive = false
    
    -- Check adjacent cells for any cards with open edges facing this position
    local adjacentPositions = {
        {x = x, y = y - 1, direction = DIRECTION.BOTTOM, opposite = DIRECTION.TOP},
        {x = x + 1, y = y, direction = DIRECTION.LEFT, opposite = DIRECTION.RIGHT},
        {x = x, y = y + 1, direction = DIRECTION.TOP, opposite = DIRECTION.BOTTOM},
        {x = x - 1, y = y, direction = DIRECTION.RIGHT, opposite = DIRECTION.LEFT}
    }
    
    for _, adj in ipairs(adjacentPositions) do
        local adjPos = adj.y .. "," .. adj.x
        local adjCard = game.field[adjPos] or game.plannedCards[adjPos]
        
        if adjCard then
            local adjCardData = adjCard.flipped and 
                               getFlippedCardData(adjCard.type, true) or 
                               CARD_PATH_DATA[adjCard.type]
                               
            -- If this adjacent card has an edge facing our position, this position is alive
            if adjCardData.edges[adj.direction] then
                isAlive = true
                break
            end
        end
    end
    
    -- If this position is already in the field or planned cards, it's not alive
    local pos = y .. "," .. x
    if game.field[pos] or game.plannedCards[pos] then
        isAlive = false
    end
    
    -- If it should be alive and isn't already in the list, add it
    if isAlive then
        local alreadyInList = false
        for _, tile in ipairs(game.aliveTiles) do
            if tile.x == x and tile.y == y then
                alreadyInList = true
                break
            end
        end
        
        if not alreadyInList then
            table.insert(game.aliveTiles, {x = x, y = y})
        end
    end
end

-- Helper function to remove a specific tile from alive tiles
function removeFromAliveTiles(x, y)
    -- Find and remove the tile from alive tiles if it exists
    for i, tile in ipairs(game.aliveTiles) do
        if tile.x == x and tile.y == y then
            table.remove(game.aliveTiles, i)
            break
        end
    end
end

-- Calculates the current hold capacity based on the field
function calculateCurrentHoldCapacity()
    local holdCapacity = 0
    
    -- Clear the previous hold tiles
    game.holdTiles = {}
    
    -- Create a map of current hold tiles for quicker lookups
    local currentHoldTilesMap = {}
    
    -- Identify all tiles adjacent to alive tiles
    local tilesAdjacentToAlive = {}
    
    -- Check each alive tile
    for _, aliveTile in ipairs(game.aliveTiles) do
        -- Check all adjacent positions to this alive tile
        local adjacentPositions = {
            {x = aliveTile.x, y = aliveTile.y - 1, dir = DIRECTION.TOP, opposite = DIRECTION.BOTTOM}, -- top
            {x = aliveTile.x + 1, y = aliveTile.y, dir = DIRECTION.RIGHT, opposite = DIRECTION.LEFT}, -- right
            {x = aliveTile.x, y = aliveTile.y + 1, dir = DIRECTION.BOTTOM, opposite = DIRECTION.TOP}, -- bottom
            {x = aliveTile.x - 1, y = aliveTile.y, dir = DIRECTION.LEFT, opposite = DIRECTION.RIGHT}  -- left
        }
        
        -- Check each adjacent position
        for _, adj in ipairs(adjacentPositions) do
            local pos = adj.y .. "," .. adj.x
            
            -- If there's a card at this position and we haven't counted it yet
            -- Skip the entrance tiles (y <= 2) as they shouldn't contribute to hold capacity
            if game.field[pos] and not tilesAdjacentToAlive[pos] and adj.y > 0 then
                -- Get the card data to check if it has a path connection to this alive tile
                local cardData = game.field[pos]
                local pathData = cardData.flipped and 
                                getFlippedCardData(cardData.type, true) or 
                                CARD_PATH_DATA[cardData.type]
                
                -- Only count if the card has a path in the direction of the alive tile
                if pathData.edges[adj.opposite] then
                    -- Mark this position as adjacent to an alive tile
                    tilesAdjacentToAlive[pos] = true
                    -- Each such tile contributes 1 to hold capacity
                    holdCapacity = holdCapacity + 1
                    
                    -- Add to the holdTiles list for visualization
                    table.insert(game.holdTiles, {x = adj.x, y = adj.y})
                    
                    -- Record this hold tile in our map
                    currentHoldTilesMap[adj.x .. "," .. adj.y] = true
                end
            end
        end
    end
    
    -- Remove danger status from tiles that are no longer hold tiles
    local i = 1
    while i <= #game.dangerTiles do
        local dangerTile = game.dangerTiles[i]
        local tileKey = dangerTile.x .. "," .. dangerTile.y
        
        if not currentHoldTilesMap[tileKey] then
            -- This tile is no longer a hold tile, remove it from danger tiles
            table.remove(game.dangerTiles, i)
        else
            i = i + 1
        end
    end
    
    return math.max(holdCapacity - 1, 0)
end

-- Function to predict alive tiles and hold capacity based on planned cards
function predictAliveAndHoldCapacity()
    -- Create a temporary copy of the field with planned cards included
    local tempField = {}
    
    -- Copy all existing field cards
    for pos, cardData in pairs(game.field) do
        tempField[pos] = {
            type = cardData.type,
            flipped = cardData.flipped,
            rotation = cardData.rotation
        }
    end
    
    -- Add all planned cards
    for pos, cardData in pairs(game.plannedCards) do
        tempField[pos] = {
            type = cardData.type,
            flipped = cardData.flipped,
            rotation = cardData.rotation
        }
    end
    
    -- Temporary storage for predicted alive tiles
    local predictedAliveTiles = {}
    
    -- Helper function to check if a tile is empty in the temporary field
    local function isTileEmpty(x, y)
        local pos = y .. "," .. x
        return tempField[pos] == nil
    end
    
    -- Helper function to check if a specific coordinate is already in alive tiles
    local function isInAliveTiles(x, y)
        for _, tile in ipairs(predictedAliveTiles) do
            if tile.x == x and tile.y == y then
                return true
            end
        end
        return false
    end
    
    -- Helper function to check if a position is within valid game boundaries
    local function isWithinBoundaries(x, y)
        -- Check horizontal boundaries
        if x < -GAME_FIELD_WIDTH_EXTENSION or x >= GRID_COLS + GAME_FIELD_WIDTH_EXTENSION then
            return false
        end
        
        -- Check vertical boundaries - prevent tiles above the surface (y < 0)
        if y < 0 or y >= GRID_ROWS + GAME_FIELD_DEPTH then
            return false
        end
        
        -- Get current day's depth goal and minimum depth
        local depthGoal = 0
        local minDepth = 0
        
        if story.messages[game.dayClock.day] then
            depthGoal = story.messages[game.dayClock.day].depthgoal or 0
            minDepth = story.messages[game.dayClock.day].mindepth or 0
        end
        
        -- Convert depths to Y coordinates (depth/10)
        local maxY = math.ceil(depthGoal / 10) + 2  -- Allow digging 20 meters (2 tiles) below the depth goal
        local minY = math.floor(minDepth / 10)      -- Don't allow digging above the minimum depth
        
        -- Check depth limits - but only if we have a valid depth goal
        if depthGoal > 0 then
            -- Prevent tiles below maximum allowed depth
            if y > maxY then
                return false
            end
            
            -- Prevent tiles above minimum required depth
            if minDepth > 0 and y < minY then
                return false
            end
        end
        
        return true
    end
    
    -- Calculate alive tiles using the temporary field
    for pos, cardData in pairs(tempField) do
        local y, x = string.match(pos, "(%d+),([%-%d]+)")
        x, y = tonumber(x), tonumber(y)
        
        -- Skip invalid coordinates
        if x == nil or y == nil then
            print("Warning: Invalid position format in predictAliveAndHoldCapacity: " .. pos)
        end
        
        -- Get the card data with flip state considered
        local pathData = cardData.flipped and 
                         getFlippedCardData(cardData.type, true) or 
                         CARD_PATH_DATA[cardData.type]
        
        -- Check each direction for open paths
        local adjacentPositions = {
            {dir = DIRECTION.TOP, x = x, y = y - 1},
            {dir = DIRECTION.RIGHT, x = x + 1, y = y},
            {dir = DIRECTION.BOTTOM, x = x, y = y + 1},
            {dir = DIRECTION.LEFT, x = x - 1, y = y}
        }
        
        for _, adj in ipairs(adjacentPositions) do
            -- First check if the edge has a path
            if pathData.edges[adj.dir] then
                -- Check if this edge is part of a dead end (single-direction path)
                local isDeadEnd = true
                
                -- Find which path this edge belongs to
                for _, path in ipairs(pathData.paths) do
                    -- Check if this path contains our direction
                    local containsDir = false
                    for _, dir in ipairs(path) do
                        if dir == adj.dir then
                            containsDir = true
                            break
                        end
                    end
                    
                    -- If this path contains our direction and has multiple connections, it's not a dead end
                    if containsDir and #path > 1 then
                        isDeadEnd = false
                        break
                    end
                end
                
                -- Only consider this tile alive if:
                -- 1. The edge is not a dead end
                -- 2. The adjacent tile is empty
                -- 3. The adjacent tile is not the mineshaft entrance (0, centerX)
                -- 4. The adjacent tile is within game boundaries
                if not isDeadEnd and isTileEmpty(adj.x, adj.y) and 
                   not (adj.y == 0 and adj.x == centerX) and
                   isWithinBoundaries(adj.x, adj.y) then
                    -- And if it's not already in our alive tiles list
                    if not isInAliveTiles(adj.x, adj.y) then
                        -- Add to predicted alive tiles
                        table.insert(predictedAliveTiles, {x = adj.x, y = adj.y})
                    end
                end
            end
        end
    end
    
    -- Calculate predicted hold capacity using the same method as calculateCurrentHoldCapacity
    -- but with the predicted alive tiles
    local predictedHoldCapacity = 0
    local futureHoldTiles = {} -- Temporary storage for hold tiles (for UI overlay)
    local tilesAdjacentToAlive = {}
    
    -- Check each alive tile's neighbors
    for _, aliveTile in ipairs(predictedAliveTiles) do
        -- Check all adjacent positions to this alive tile
        local adjacentPositions = {
            {x = aliveTile.x, y = aliveTile.y - 1, dir = DIRECTION.TOP, opposite = DIRECTION.BOTTOM}, -- top
            {x = aliveTile.x + 1, y = aliveTile.y, dir = DIRECTION.RIGHT, opposite = DIRECTION.LEFT}, -- right
            {x = aliveTile.x, y = aliveTile.y + 1, dir = DIRECTION.BOTTOM, opposite = DIRECTION.TOP}, -- bottom
            {x = aliveTile.x - 1, y = aliveTile.y, dir = DIRECTION.LEFT, opposite = DIRECTION.RIGHT}  -- left
        }
        
        -- Check each adjacent position
        for _, adj in ipairs(adjacentPositions) do
            local pos = adj.y .. "," .. adj.x
            
            -- If there's a card at this position and we haven't counted it yet
            -- Skip the entrance tiles (y <= 0) as they shouldn't contribute to hold capacity
            if tempField[pos] and not tilesAdjacentToAlive[pos] and adj.y > 0 and isWithinBoundaries(adj.x, adj.y) then
                -- Get the card data to check if it has a path connection to this alive tile
                local cardData = tempField[pos]
                local pathData = cardData.flipped and 
                                getFlippedCardData(cardData.type, true) or 
                                CARD_PATH_DATA[cardData.type]
                
                -- Only count if the card has a path in the direction of the alive tile
                if pathData.edges[adj.opposite] then
                    -- Mark this position as adjacent to an alive tile
                    tilesAdjacentToAlive[pos] = true
                    -- Each such tile contributes 1 to hold capacity
                    predictedHoldCapacity = predictedHoldCapacity + 1
                    
                    -- Add to future hold tiles for visualization
                    table.insert(futureHoldTiles, {x = adj.x, y = adj.y})
                end
            end
        end
    end
    
    return #predictedAliveTiles, math.max(predictedHoldCapacity - 1, 0), futureHoldTiles
end

-- Set danger tiles at the end of a day based on current hold tiles
function setDangerTiles()
    -- Clear previous danger tiles
    game.dangerTiles = {}
    
    -- Convert all current hold tiles to danger tiles
    for _, tile in ipairs(game.holdTiles) do
        table.insert(game.dangerTiles, {x = tile.x, y = tile.y})
    end
end

-- Function to end a day due to running out of cards
function game.endDay(reason)
    game.isDayOver = true
    game.isInitialStory = false  -- Set to false because this is the end of a day
    print("DAY OVER: " .. (reason or "Run out of cards"))
    game.dayOverReason = reason or "Run out of cards"
end

-- Function to start a new day
function startNewDay()
    print("Starting day " .. game.dayClock.day)
    
    -- Update the day clock for the new day
    if game.dayClock.day > 1 then -- Skip for first day which is set in love.load
        -- Get shifts from story module for the current day
        local dayStory = story.messages[game.dayClock.day]
        if dayStory and dayStory.shifts then
            -- Use the shifts value from the story module
            setDayClockSegments(dayStory.shifts)
        else
            -- Default is 6 segments if not specified
            setDayClockSegments(6)
        end
    end
    
    -- Recalculate alive tiles to respect the new day's depth limits
    updateAliveTiles()
    
    -- Update maximum cards playable and holdable with the new alive tiles
    game.shiftStartAliveTilesCount = #game.aliveTiles
    game.currentHoldCapacity = calculateCurrentHoldCapacity()
    game.maxPlayCards = math.min(game.shiftStartAliveTilesCount, 7)
    game.maxHoldCards = game.currentHoldCapacity
    
    -- Set isInitialStory flag to true when starting a new day
    game.isInitialStory = true
    
    -- Show story for this day
    story.showDayStory(game.dayClock.day)
end

-- Function to play the day start sound
function _G.playDayStartSound()
    -- Stop the sound if it's already playing
    assets.sounds.dayStart:stop()
    -- Set volume to very high (values > 1.0 are allowed and make it louder)
    assets.sounds.dayStart:setVolume(2.0)
    -- Play the sound from the beginning
    assets.sounds.dayStart:play()
end

-- Function to handle a click on the day over screen
function handleDayOverClick()
    -- Check if this is day 0 (story screen)
    if game.dayClock.day == 0 then
        -- Start the first day
        game.isDayOver = false
        game.dayClock.day = 1
        game.dayClock.segmentsUsed = 0
    
    -- Show the day 1 story
        startNewDay()
    else
        -- If this is day 1 and the initial story, set up the help menu to be shown after
        if game.dayClock.day == 1 and game.isInitialStory then
            game.helpMenu.visible = true
            game.helpMenu.showAfterStory = false  -- Only show once
        end
        
        -- If this is the initial story for the day, just start playing
        if game.isInitialStory then
            game.isDayOver = false
            game.isInitialStory = false
            return
        end

        -- Otherwise, it's the end of the day - prepare for the next
        game.isDayOver = false
        
        -- Check if the depth goal was reached (only for end of day, not initial story)
        local currentDepth = calculateCurrentDepth()
        local depthGoal = 0
        
        -- Get depth goal from story for current day
        if story.messages[game.dayClock.day] then
            depthGoal = story.messages[game.dayClock.day].depthgoal or 0
        end
        
        if depthGoal > 0 and currentDepth < depthGoal then
            game.isGameOver = true
            game.gameOverReason = "Failed to reach the depth goal of " .. depthGoal .. " fathoms"
        return
    end
    
    -- Check if game over (any danger tiles remaining)
        if #game.dangerTiles > 0 then
            game.isGameOver = true
            game.gameOverReason = "Danger tiles remained at the end of the day"
            return
        end

        -- Process dangerous spaces
        processEndOfDay()
        
        -- Increment day
        game.dayClock.day = game.dayClock.day + 1
        game.dayClock.segmentsUsed = 0

        -- Start the new day
        startNewDay()
    end
end

-- Function to process the end of day logic
function processEndOfDay()
    -- Clear any remaining cards from discard and hand
    game.discard.cards = {}
    game.discard.count = 0
    game.cards = {} -- Clear hand
    game.holdCount = 0
    
    -- Regenerate the deck for the new day
    generateDeck()
    setDangerTiles()

    
    -- Recalculate alive tiles
    updateAliveTiles()
    
    -- Update maximum cards playable and holdable
    game.shiftStartAliveTilesCount = #game.aliveTiles
    game.currentHoldCapacity = calculateCurrentHoldCapacity()
    game.maxPlayCards = math.min(game.shiftStartAliveTilesCount,7)
    game.maxHoldCards = game.currentHoldCapacity
    
    -- Draw cards for the new day
    local initialCards = game.calculateDrawAmount(game.shiftStartAliveTilesCount)
    drawCardsFromDeck(initialCards)
end

-- Function to play random dig sound when planning a card
function _G.playDigSound()
    -- Pick a random dig sound (1-3)
    local randomSound = love.math.random(1, 3)
    local sound = assets.sounds["dig" .. randomSound]
    
    -- Stop any previously playing dig sound
    sound:stop()
    -- Play the sound
    sound:play()
end

-- Function to play random shift end sound
function _G.playShiftEndSound()
    -- Pick a random shift end sound (1-2)
    local randomSound = love.math.random(1, 2)
    local sound = assets.sounds["shiftEnd" .. randomSound]
    
    -- Stop any previously playing shift end sound
    sound:stop()
    -- Play the sound
    sound:play()
end

-- Function to calculate the current depth of the mine
function calculateCurrentDepth()
    -- Start with the initial depth of 30 (from the starter mine)
    local maxY = 3  -- Y position 3 = 30 fathoms
    
    -- Check all cards in the field to find the deepest one
    for pos, _ in pairs(game.field) do
        local y, x = string.match(pos, "(%d+),([%-%d]+)")
        y = tonumber(y)
        
        if y and y > maxY then
            maxY = y
        end
    end
    
    -- Also check planned cards
    for pos, _ in pairs(game.plannedCards) do
        local y, x = string.match(pos, "(%d+),([%-%d]+)")
        y = tonumber(y)
        
        if y and y > maxY then
            maxY = y
        end
    end
    
    -- Convert Y position to depth (10 * Y)
    return maxY * 10
end

-- Helper function to check if a position is outside the game's depth limits
function isOutsideDepthLimits(x, y)
    -- Get current day's depth goal and minimum depth
    local depthGoal = 220
    local minDepth = 120
    
    if story.messages[game.dayClock.day] then
        depthGoal = story.messages[game.dayClock.day].depthgoal
        minDepth = story.messages[game.dayClock.day].mindepth
    end
    
    -- Convert depths to Y coordinates (depth/10)
        local maxY = math.ceil(depthGoal / 10) + 2  -- Allow digging 20 meters (2 tiles) below the depth goal
    local minY = math.floor(minDepth / 10)      -- Don't allow digging above the minimum depth
    
    -- Check depth limits - but only if we have a valid depth goal
    if depthGoal > 0 then
        -- Tile is too deep
        if y > maxY then
            return true
        end
        
        -- Tile is too shallow
        if minDepth > 0 and y < minY then
            return true
        end
    end
    
    return false
end

-- Helper function to check if a position is within valid game boundaries
function isWithinBoundaries(x, y)
    -- Check horizontal boundaries
    if x < -GAME_FIELD_WIDTH_EXTENSION or x >= GRID_COLS + GAME_FIELD_WIDTH_EXTENSION then
        return false
    end
    
    -- Check vertical boundaries - prevent tiles above the surface (y < 0)
    if y < 0 or y >= GRID_ROWS + GAME_FIELD_DEPTH then
        return false
    end
    
    -- Check depth limits
    if isOutsideDepthLimits(x, y) then
        return false
    end
    
    return true
end

-- Global helper function to check if a tile is empty
function isTileEmpty(x, y)
    local pos = y .. "," .. x
    return game.field[pos] == nil and game.plannedCards[pos] == nil
end