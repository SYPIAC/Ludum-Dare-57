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

-- Game state
local game = {
    cards = {},      -- Cards in hand
    dragging = nil,  -- Card being dragged
    field = {},      -- Placed cards on field
    deck = {         -- Deck of cards
        count = 24,  -- Number of cards in deck
    },
    discard = {      -- Discard pile
        count = 0,   -- Number of cards in discard
    },
    invalidPlacement = nil  -- Tracks invalid placement feedback
}

-- Load assets
local assets = {
    cards = {},  -- Will hold all card images
    font = nil,
    smallFont = nil
}

-- Check if a card can be placed at given grid coordinates
function canPlaceCard(cardType, gridX, gridY, flipped)
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
            
            -- Check if the edges match (both open or both closed)
            -- If one has a path and the other doesn't, they're incompatible
            if cardData.edges[adjacent.opposite] ~= adjacentCard.edges[adjacent.direction] then
                return false
            end
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
    
    -- Initialize hand with some cards for testing (different tunnel types)
    table.insert(game.cards, { id = 1, x = 0, y = 0, type = CARD_TYPES.PATH_1_1A, flipped = false })
    table.insert(game.cards, { id = 2, x = 0, y = 0, type = CARD_TYPES.PATH_1_1B, flipped = false })
    table.insert(game.cards, { id = 3, x = 0, y = 0, type = CARD_TYPES.PATH_2_1A, flipped = false })
    table.insert(game.cards, { id = 4, x = 0, y = 0, type = CARD_TYPES.PATH_2_1B, flipped = false })
    table.insert(game.cards, { id = 5, x = 0, y = 0, type = CARD_TYPES.PATH_3_1A, flipped = false })
    table.insert(game.cards, { id = 6, x = 0, y = 0, type = CARD_TYPES.PATH_3_1B, flipped = false })
    table.insert(game.cards, { id = 7, x = 0, y = 0, type = CARD_TYPES.PATH_4_1, flipped = false })
    table.insert(game.cards, { id = 8, x = 0, y = 0, type = CARD_TYPES.PATH_4_4, flipped = false })
    
    -- Calculate initial positions for cards in hand
    updateHandPositions()
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
    return GRID_OFFSET_X + gridX * GRID_CELL_SIZE, 
           GRID_OFFSET_Y + gridY * GRID_CELL_HEIGHT
end

-- Convert screen position to grid coordinates
function screenToGrid(screenX, screenY)
    return math.floor((screenX - GRID_OFFSET_X) / GRID_CELL_SIZE),
           math.floor((screenY - GRID_OFFSET_Y) / GRID_CELL_HEIGHT)
end

function love.update(dt)
    -- Handle card dragging
    if game.dragging then
        game.dragging.x = love.mouse.getX() - CARD_WIDTH / 2
        game.dragging.y = love.mouse.getY() - CARD_HEIGHT / 2
    end
    
    -- Update invalid placement feedback timer
    if game.invalidPlacement then
        game.invalidPlacement.time = game.invalidPlacement.time - dt
        if game.invalidPlacement.time <= 0 then
            game.invalidPlacement = nil
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then  -- Left mouse button
        -- Check if we clicked on a card in hand
        for i, card in ipairs(game.cards) do
            if x >= card.x and x <= card.x + CARD_WIDTH and
               y >= card.y and y <= card.y + CARD_HEIGHT then
                game.dragging = card
                break
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
    if button == 1 and game.dragging then
        -- Check if card was dropped on the field
        if y < FIELD_HEIGHT then
            -- Convert screen position to grid
            local gridX, gridY = screenToGrid(x, y)
            
            -- Check if this is a valid cell for a card (needs enough space and not behind status bar)
            local screenX, screenY = gridToScreen(gridX, gridY)
            if gridX >= 0 and gridX < GRID_COLS-1 and gridY >= 0 and gridY < GRID_ROWS-1 and
               screenX + CARD_WIDTH <= FIELD_WIDTH then
               
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
                else
                    -- Card connections don't match - provide visual feedback
                    -- We'll rely on the visual state in the draw function
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

function love.draw()
    -- Set background color
    love.graphics.setBackgroundColor(unpack(COLORS.background))
    
    -- Draw top brown bar
    love.graphics.setColor(unpack(COLORS.top_bar))
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, 40)
    
    -- Draw the field grid
    drawFieldGrid()
    
    -- Draw cards placed on the field
    drawFieldCards()
    
    -- Draw status bar
    drawStatusBar()
    
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
    
    -- Draw cards in hand (except the one being dragged)
    for i, card in ipairs(game.cards) do
        if card ~= game.dragging then
            drawCard(card)
        end
    end
    
    -- Draw the card being dragged (on top of everything)
    if game.dragging then
        drawCard(game.dragging)
    end
    
    -- DEBUG: Draw card outline to verify grid alignment
    if game.dragging and love.mouse.getY() < FIELD_HEIGHT then
        local gridX, gridY = screenToGrid(love.mouse.getX(), love.mouse.getY())
        if gridX >= 0 and gridX < GRID_COLS-1 and gridY >= 0 and gridY < GRID_ROWS-1 then
            local x, y = gridToScreen(gridX, gridY)
            -- Only show outline if not behind status bar
            if x + CARD_WIDTH <= FIELD_WIDTH then
                -- Check if placement is valid and show appropriate color
                local isValidPlacement = canPlaceCard(game.dragging.type, gridX, gridY, game.dragging.flipped)
                if isValidPlacement then
                    love.graphics.setColor(0, 1, 0, 0.5)  -- Green for valid placement
                else
                    love.graphics.setColor(1, 0, 0, 0.5)  -- Red for invalid placement
                end
                love.graphics.rectangle("line", x, y, CARD_WIDTH, CARD_HEIGHT)
            end
        end
    end
    
    -- Draw invalid placement feedback if needed
    if game.invalidPlacement then
        local x, y = gridToScreen(game.invalidPlacement.x, game.invalidPlacement.y)
        love.graphics.setColor(1, 0, 0, game.invalidPlacement.time * 2)  -- Red with fading alpha
        love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT)
    end
end

-- Function to draw the status bar
function drawStatusBar()
    -- Draw status bar on the right
    love.graphics.setColor(unpack(COLORS.status_bar))
    love.graphics.rectangle("fill", SCREEN_WIDTH - STATUS_BAR_WIDTH, 40, STATUS_BAR_WIDTH, FIELD_HEIGHT - 40)
    
    -- Draw "FOREMAN DAY 1" text
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.setFont(assets.font)
    love.graphics.printf("FOREMAN", SCREEN_WIDTH - STATUS_BAR_WIDTH, 50, STATUS_BAR_WIDTH, "center")
    love.graphics.printf("DAY 1", SCREEN_WIDTH - STATUS_BAR_WIDTH, 70, STATUS_BAR_WIDTH, "center")
    
    -- Draw clock
    love.graphics.setColor(1, 1, 0)  -- Yellow
    love.graphics.circle("fill", SCREEN_WIDTH - STATUS_BAR_WIDTH/2, 120, 30)
    
    -- Draw SCORE
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.printf("SCORE", SCREEN_WIDTH - STATUS_BAR_WIDTH, 170, STATUS_BAR_WIDTH, "center")
    love.graphics.printf("000000", SCREEN_WIDTH - STATUS_BAR_WIDTH, 190, STATUS_BAR_WIDTH, "center")
end

function drawFieldGrid()    
    -- Draw grid cells with + symbols at corners
    for row = 0, GRID_ROWS do
        for col = 0, GRID_COLS do
            local x, y = gridToScreen(col, row)
            
            -- Only draw grid points that are within the visible area (not behind status bar)
            if x <= FIELD_WIDTH then
                -- Draw + symbol at grid corners
                love.graphics.setColor(unpack(COLORS.grid_symbol))
                love.graphics.setFont(assets.smallFont)
                love.graphics.print("+", x - 4, y - 8)
                
                -- Highlight cell if mouse is over it and a card is being dragged
                if game.dragging and col < GRID_COLS-1 and row < GRID_ROWS-1 then
                    local mouseX, mouseY = love.mouse.getPosition()
                    local gx, gy = screenToGrid(mouseX, mouseY)
                    
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

function drawFieldCards()
    -- Draw cards that have been placed on the field
    for pos, cardData in pairs(game.field) do
        local y, x = string.match(pos, "(%d+),(%d+)")
        x, y = tonumber(x), tonumber(y)
        
        -- Get the top-left corner of the card
        local screenX, screenY = gridToScreen(x, y)
        
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

function drawCard(card)
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
    if CARD_PATH_DATA[card.type].flippable then
        love.graphics.setColor(1, 1, 0, 0.7)  -- Transparent yellow
        love.graphics.circle("fill", card.x + CARD_WIDTH - 5, card.y + 5, 3)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end 