-- cards.lua
-- Module for handling card types and data

local cards = {}

-- Directions
local DIRECTION = {
    TOP = 1,
    RIGHT = 2,
    BOTTOM = 3,
    LEFT = 4
}

-- Card types
cards.CARD_TYPES = {
    PATH_1_1A = "path_1_1a",
    PATH_1_1B = "path_1_1b",
    PATH_2_1A = "path_2_1a",
    PATH_2_1B = "path_2_1b",
    PATH_2_1C = "path_2_1c",
    PATH_2_1D = "path_2_1d",
    PATH_3_1A = "path_3_1a",
    PATH_3_1B = "path_3_1b",
    PATH_4_1 = "path_4_1",
    PATH_2_2A = "path_2_2a",
    PATH_2_2B = "path_2_2b",
    PATH_2_2C = "path_2_2c",
    PATH_2_2D = "path_2_2d",
    PATH_3_3A = "path_3_3a",
    PATH_3_3B = "path_3_3b",
    PATH_4_4 = "path_4_4",
    EMPTY = "empty"
}

-- Card path data structure
cards.CARD_PATH_DATA = {
    [cards.CARD_TYPES.PATH_1_1A] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.BOTTOM}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_1_1B] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_2_1A] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.TOP, DIRECTION.BOTTOM}},
        flippable = false
    },
    [cards.CARD_TYPES.PATH_2_1B] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT, DIRECTION.RIGHT}},
        flippable = false
    },
    [cards.CARD_TYPES.PATH_2_1C] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.BOTTOM, DIRECTION.RIGHT}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_2_1D] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT, DIRECTION.BOTTOM}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_3_1A] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.TOP, DIRECTION.RIGHT, DIRECTION.BOTTOM}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_3_1B] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.TOP, DIRECTION.RIGHT, DIRECTION.LEFT}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_4_1] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.TOP, DIRECTION.RIGHT, DIRECTION.BOTTOM, DIRECTION.LEFT}},
        flippable = false
    },
    [cards.CARD_TYPES.PATH_2_2A] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.TOP}, {DIRECTION.BOTTOM}},
        flippable = false
    },
    [cards.CARD_TYPES.PATH_2_2B] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT}, {DIRECTION.RIGHT}},
        flippable = false
    },
    [cards.CARD_TYPES.PATH_2_2C] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.RIGHT}, {DIRECTION.BOTTOM}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_2_2D] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.BOTTOM}, {DIRECTION.LEFT}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_3_3A] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = false},
        paths = {{DIRECTION.TOP}, {DIRECTION.RIGHT}, {DIRECTION.BOTTOM}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_3_3B] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.LEFT}, {DIRECTION.TOP}, {DIRECTION.RIGHT}},
        flippable = true
    },
    [cards.CARD_TYPES.PATH_4_4] = {
        edges = {[DIRECTION.TOP] = true, [DIRECTION.RIGHT] = true, [DIRECTION.BOTTOM] = true, [DIRECTION.LEFT] = true},
        paths = {{DIRECTION.TOP}, {DIRECTION.RIGHT}, {DIRECTION.BOTTOM}, {DIRECTION.LEFT}},
        flippable = false
    },
    [cards.CARD_TYPES.EMPTY] = {
        edges = {[DIRECTION.TOP] = false, [DIRECTION.RIGHT] = false, [DIRECTION.BOTTOM] = false, [DIRECTION.LEFT] = false},
        paths = {},
        flippable = false
    }
}

return cards