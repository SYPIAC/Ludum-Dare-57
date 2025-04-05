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
local HAND_CARDS_PER_ROW = 5  -- Cards per row in hand
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
    PATH_4_4 = "path_4_4"    -- Four paths
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
    [CARD_TYPES.PATH_4_4] = "path_4_4.png"
}

-- Import UI module
local ui = require("ui")

-- Game state
local game = {
    cards = {},      -- Cards in hand
    dragging = nil,  -- Card being dragged
    field = {},      -- Placed cards on field
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
    drawButtonHover = false,  -- Track if mouse is hovering over draw button
    CARD_PATH_DATA = CARD_PATH_DATA,  -- Make card path data accessible to UI
    canPlaceCard = nil -- Function reference to be set in love.load
}

-- Load assets
local assets = {
    cards = {},  -- Will hold all card images
    font = nil,
    smallFont = nil
}

-- Check if a card can be placed at given grid coordinates
function canPlaceCard(cardType, gridX, gridY, flipped)
    -- First check: is this an "alive" tile?
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
    
    -- Second check: do the edges match with adjacent cards?
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
        local adjacentCardData = game.field[adjacent.y .. "," .. adjacent.x]
        
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
    
    -- Set up the canPlaceCard function reference
    game.canPlaceCard = canPlaceCard
    
    -- Initialize the UI module
    ui.init(game, assets, viewport, DIRECTION)
    
    -- Generate the deck
    generateDeck()
    
    -- Draw initial hand
    drawCardsFromDeck(8)
    
    -- Generate the initial mineshaft structure
    generateInitialMineshaft()
    
    -- Initialize RNG
    love.math.setRandomSeed(os.time())
end

function updateHandPositions()
    local cardSpacingX = CARD_WIDTH + 5
    local handStartX = 16
    local handStartY = SCREEN_HEIGHT - HAND_HEIGHT + 10
    
    for i, card in ipairs(game.cards) do
        local row = math.ceil(i / HAND_CARDS_PER_ROW)
        local col = (i - 1) % HAND_CARDS_PER_ROW + 1
        
        -- Skip deck and discard positions (rightmost two slots in top row)
        if row == 1 and col > 3 then
            col = col + 2  -- Skip positions 4 and 5 in top row
        end
        
        card.x = handStartX + (col - 1) * cardSpacingX
        card.y = handStartY + (row - 1) * (CARD_HEIGHT + 5)
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
    -- Handle card dragging
    if game.dragging then
        game.dragging.x = love.mouse.getX() - CARD_WIDTH / 2
        game.dragging.y = love.mouse.getY() - CARD_HEIGHT / 2
    end
    
    -- Handle viewport dragging
    if viewport.dragging then
        local mouseX, mouseY = love.mouse.getPosition()
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
    local drawButtonX = SCREEN_WIDTH - 48
    local drawButtonY = FIELD_HEIGHT + 10 + CARD_HEIGHT + 10
    local drawButtonWidth = CARD_WIDTH
    local drawButtonHeight = 30
    
    game.drawButtonHover = pointInRect(mx, my, drawButtonX, drawButtonY, drawButtonWidth, drawButtonHeight)
end

function love.mousepressed(x, y, button)
    if button == 1 then  -- Left mouse button
        -- Check if draw button was clicked
        local drawButtonX = SCREEN_WIDTH - 48
        local drawButtonY = FIELD_HEIGHT + 10 + CARD_HEIGHT + 10
        local drawButtonWidth = CARD_WIDTH
        local drawButtonHeight = 30
        
        if pointInRect(x, y, drawButtonX, drawButtonY, drawButtonWidth, drawButtonHeight) then
            -- Discard current hand and draw new cards
            discardHand()
            drawCardsFromDeck()
            return
        end
        
        -- If we're in the field area (not hand)
        if y < FIELD_HEIGHT then
            local gridX, gridY = screenToGrid(x, y)
            
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
            -- In hand area, check for card dragging
            for i, card in ipairs(game.cards) do
                if x >= card.x and x <= card.x + CARD_WIDTH and
                   y >= card.y and y <= card.y + CARD_HEIGHT then
                    game.dragging = card
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

function love.mousereleased(x, y, button)
    if button == 1 then  -- Left mouse button
        -- Stop viewport dragging
        viewport.dragging = false
        
        -- Handle card placement if dragging a card
        if game.dragging then
            -- Check if card was dropped on the field
            if y < FIELD_HEIGHT then
                -- Convert screen position to grid
                local gridX, gridY = screenToGrid(x, y)
                
                -- Check if this is a valid cell for a card (needs enough space and not behind status bar)
                local screenX, screenY = gridToScreen(gridX, gridY)
                if screenX + CARD_WIDTH <= FIELD_WIDTH and screenX >= 0 and screenY >= 40 and screenY <= FIELD_HEIGHT then
                   
                    -- Check if the card can be placed at this location (connections are valid)
                    if canPlaceCard(game.dragging.type, gridX, gridY, game.dragging.flipped) then
                        -- Place card on field
                        game.field[gridY .. "," .. gridX] = {
                            type = game.dragging.type,
                            flipped = game.dragging.flipped,
                            rotation = 0  -- No rotation for now
                        }
                        
                        -- Remove card from hand
                        for i, card in ipairs(game.cards) do
                            if card == game.dragging then
                                table.remove(game.cards, i)
                                break
                            end
                        end
                        
                        -- Update the alive tiles after placing a card
                        updateAliveTiles()
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
    if key == "escape" then
        love.event.quit()
    end
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
        CARD_TYPES.PATH_2_1A,  -- Straight down
        CARD_TYPES.PATH_2_1C,  -- Curve
        CARD_TYPES.PATH_2_1D,  -- Curve
        CARD_TYPES.PATH_3_1A,  -- T-junction right
        CARD_TYPES.PATH_3_1B,  -- T-junction top
        CARD_TYPES.PATH_4_1  -- Cross junction
    }
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
    
    -- Helper function to check if a tile is empty
    local function isTileEmpty(x, y)
        return game.field[y .. "," .. x] == nil
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
    
    -- For each card on the field, check its open edges
    for pos, cardData in pairs(game.field) do
        local y, x = string.match(pos, "(%d+),(%d+)")
        x, y = tonumber(x), tonumber(y)
        
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
                
                -- Only consider this tile alive if the edge is not a dead end and the adjacent tile is empty
                if not isDeadEnd and isTileEmpty(adj.x, adj.y) then
                    -- And if it's not already in our alive tiles list
                    if not isInAliveTiles(adj.x, adj.y) then
                        -- Add to alive tiles (without grid or field restrictions)
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
    for i = 1, 3 do table.insert(game.deck.cards, CARD_TYPES.PATH_2_1B) end
    for i = 1, 5 do table.insert(game.deck.cards, CARD_TYPES.PATH_2_1C) end
    for i = 1, 5 do table.insert(game.deck.cards, CARD_TYPES.PATH_2_1D) end
    
    -- T-junctions
    for i = 1, 5 do table.insert(game.deck.cards, CARD_TYPES.PATH_3_1A) end
    for i = 1, 5 do table.insert(game.deck.cards, CARD_TYPES.PATH_3_1B) end
    
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
    -- Move all cards from hand to discard pile
    for _, card in ipairs(game.cards) do
        table.insert(game.discard.cards, card.type)
        game.discard.count = game.discard.count + 1
    end
    
    -- Clear the hand
    game.cards = {}
    
    -- If deck is empty but discard has cards, shuffle discard into deck
    if game.deck.count == 0 and game.discard.count > 0 then
        game.deck.cards = game.discard.cards
        game.deck.count = game.discard.count
        game.discard.cards = {}
        game.discard.count = 0
        shuffleDeck()
    end
end

-- Draw cards from the deck to fill the player's hand
function drawCardsFromDeck(numCards)
    -- Default to drawing up to hand capacity if not specified
    numCards = numCards or (HAND_CARDS_PER_ROW * HAND_ROWS - #game.cards)
    
    -- Limit by how many cards are actually available
    numCards = math.min(numCards, game.deck.count)
    
    -- If deck is empty but discard has cards, shuffle discard into deck
    if numCards > 0 and game.deck.count == 0 and game.discard.count > 0 then
        game.deck.cards = game.discard.cards
        game.deck.count = game.discard.count
        game.discard.cards = {}
        game.discard.count = 0
        shuffleDeck()
        
        -- Recalculate how many cards we can draw
        numCards = math.min(numCards, game.deck.count)
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
                flipped = false 
            })
        end
    end
    
    -- Update hand positions
    updateHandPositions()
end

-- Check if point is within rectangle
function pointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end 