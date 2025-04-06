-- story.lua
-- Module for handling game story and messages

local story = {}

-- Constants for story formatting
local COLORS = {
    title = {0.8, 0.8, 1, 1}, -- Light blue for titles
    text = {1, 1, 1, 1},      -- White for regular text
    continue = {0.8, 0.8, 1, 1}, -- Light blue for continue prompt
    emphasis = {1, 0.8, 0.2, 1} -- Bright gold for bold/emphasized text
}

-- Table of day messages grouped by day
story.messages = {
    [1] = {
        title = "DAY 1",
        mindepth = 0,
        depthgoal = 60,
        shifts = 6,
        content = {
            "FOREMAN",
            "You must dig **60 fathoms** deep",
            "This is less demanding than usual",
            "Take this opportunity to learn",
            "The crews will present their plans. You must choose",
            "An open wall is an opportunity ",
            "An opportunity for the mines to grow. Your cards multiply",
            "An opportunity for the enemy to disrupt our work",
            "More is better. More is worse",
            "There will be **6 shifts**"
        }
    },
    [2] = {
        title = "DAY 2",
        mindepth = 0,
        depthgoal = 100,
        shifts = 6,
        content = {
            "FOREMAN",
            "You must reach **100 fathoms**. Failure is defeat",
            "Make sure the tunnels left unfinished are closed",
            "Lest the unexplored crevices become our downfall",
            "They were marked on your map as a warning",
            "Surround them with stone and more tunnels",
            "There will be **6 shifts** to mend our errors"
        }
    },
    [3] = {
        title = "DAY 3",
        mindepth = 0,
        depthgoal = 140,
        shifts = 6,
        content = {
            "FOREMAN",
            "We aim for **140 fathoms**",
            "Then the depths can truly begin",
            "We must leave the surface soil behind",
            "After today, there will be no more work above 120 fathoms",
            "The rock will resist you. Plan carefully",
            "There will be **6 shifts**"
        }
    },
    [4] = {
        title = "DAY 4",
        mindepth = 120,
        depthgoal = 180,
        shifts = 6,
        content = {
            "FOREMAN",
            "The crews demand **180 fathoms**",
            "Possibilities recede. Regrets mount. You will have less options",
            "There are 5 cards in your deck that do nothing",
            "Build wide and be ready. Tomorrow we complete our work",
            "There will be **6 shifts**"
        }
    },
    [5] = {
        title = "DAY 5",
        mindepth = 160,
        depthgoal = 220,
        shifts = 5,
        content = {
            "FOREMAN",
            "**220 fathoms**",
            "The final push",
            "The heat and the distance prove a problem",
            "Today there will be only **5 shifts**",
            "We will reach the depths or die trying"
        }
    },
    [6] = {
        title = "YOU WIN",
        mindepth = 160,
        depthgoal = 220,
        shifts = 4,
        content = {
            "FOREMAN",
            "You have reached the final depth",
            "You win",
            "The picks break against bedrock below",
            "You can keep going, if you want",
            "But no more rewards await you",
            "Your victory lap",
            "Will have **4 shifts**"
        }
    }
}

-- Variables for storing the game state reference
local game = nil
local assets = nil

-- Initialize the story module
function story.init(gameState, gameAssets)
    game = gameState
    assets = gameAssets
end

-- Function to process text with bold formatting (**text**)
function story.processFormattedText(text, x, y, width, alignment)
    -- Ensure text is a string
    text = tostring(text or "")
    
    -- Check if text contains any bold markers
    if not text:find("%*%*") then
        -- If no bold markers, just draw normally
        love.graphics.setColor(unpack(COLORS.text))
        love.graphics.printf(text, x, y, width, alignment)
        return assets.font:getHeight()
    end
    
    -- Draw the base text with ** removed
    local plainText = text:gsub("%*%*", "")
    love.graphics.setColor(unpack(COLORS.text))
    love.graphics.printf(plainText, x, y, width, alignment)
    
    -- Try to find a bold segment - we'll handle just one per line for simplicity
    local start = text:find("%*%*")
    if start then
        local finish = text:find("%*%*", start + 2)
        if finish then
            -- We found a pair of ** markers
            local beforeText = text:sub(1, start - 1)
            local boldText = text:sub(start + 2, finish - 1)
            
            -- Calculate the X position based on alignment
            local baseX = x
            local beforeWidth = assets.font:getWidth(beforeText)
            
            if alignment == "center" then
                local fullTextWidth = assets.font:getWidth(plainText)
                baseX = x + (width - fullTextWidth) / 2
            elseif alignment == "right" then
                local fullTextWidth = assets.font:getWidth(plainText)
                baseX = x + width - fullTextWidth
            end
            
            -- Draw the bold text over the plain text
            love.graphics.setColor(unpack(COLORS.emphasis))
            love.graphics.print(boldText, baseX + beforeWidth, y)
        end
    end
    
    -- Return the height of the text for positioning
    return assets.font:getHeight()
end

-- Show story screen for the current day
function story.showDayStory(day)
    if not story.messages[day] then
        return false -- No story for this day
    end
    
    -- Get the story content for this day
    local dayStory = story.messages[day]
    
    -- Play sound effect for story
    playDayStartSound()
    
    -- Set the game state to show the day overlay
    game.isDayOver = true
    game.dayOverReason = {
        title = dayStory.title,
        content = dayStory.content
    }
    
    return true
end

-- Show a custom story screen with the provided text
function story.showStoryScreen(title, content)
    -- Play sound effect for story
    playDayStartSound()
    
    game.isDayOver = true
    game.dayOverReason = {
        title = title,
        content = {content}
    }
    -- Set day to 0 for story mode
    game.dayClock.day = 0
end

-- Draw the day or story overlay
function story.drawStoryOverlay()
    -- Semi-transparent black overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local textH = assets.font:getHeight()
    
    -- Check if this is day 0 (intro story mode) or a regular day story
    if game.dayClock.day == 0 then
        -- Story title
        love.graphics.setColor(unpack(COLORS.title))
        love.graphics.setFont(assets.font)
        local titleText = game.dayOverReason.title or "STORY"
        local titleWidth = assets.font:getWidth(titleText)
        
        -- Draw title centered on screen
        love.graphics.print(titleText, screenWidth/2 - titleWidth/2, screenHeight/3 - textH/2)
        
        -- Story text - use the dayOverReason.content for story content
        
        local contentY = screenHeight/2 - textH/2
        local textWidth = screenWidth  -- Use full screen width
        
        -- Draw each line of story content
        if type(game.dayOverReason.content) == "table" then
            for i, line in ipairs(game.dayOverReason.content) do
                story.processFormattedText(line, 0, contentY, textWidth, "center")
                contentY = contentY + textH + 5
            end
        else
            -- Fallback for string content
            love.graphics.setColor(unpack(COLORS.text))
            -- Ensure the content is a string
            local content = tostring(game.dayOverReason.content or "")
            love.graphics.printf(content, 0, contentY, textWidth, "center")
        end
        
        -- Continue instructions
        love.graphics.setColor(unpack(COLORS.continue))
        local continueText = "Click anywhere to begin"
        local continueWidth = assets.font:getWidth(continueText)
        
        -- Draw continue text at bottom
        love.graphics.print(continueText, screenWidth/2 - continueWidth/2, screenHeight*2/3 + textH)
    else
        -- Day story display
        if type(game.dayOverReason) == "string" then
            -- Legacy support for string dayOverReason
            love.graphics.setColor(unpack(COLORS.title))
            love.graphics.setFont(assets.font)
            local text = "DAY " .. game.dayClock.day
            local textWidth = assets.font:getWidth(text)
            
            -- Draw day title
            love.graphics.print(text, screenWidth/2 - textWidth/2, screenHeight/3 - textH/2)
            
            -- Draw reason text
            love.graphics.setColor(unpack(COLORS.text))
            -- Ensure reason text is a string
            local reasonText = tostring(game.dayOverReason or "")
            love.graphics.printf(reasonText, 0, screenHeight/2 - textH/2, screenWidth, "center")
        else
            -- Structured story content
            -- Draw day title
            love.graphics.setColor(unpack(COLORS.title))
            love.graphics.setFont(assets.font)
            local title = game.dayOverReason.title or ("DAY " .. game.dayClock.day)
            local titleWidth = assets.font:getWidth(title)
            love.graphics.print(title, screenWidth/2 - titleWidth/2, screenHeight/4 - textH)
            
            -- Draw content with formatted text - with more vertical spacing
            local contentY = screenHeight/3
            local lineSpacing = textH * 1.5 -- Increased spacing between lines
            local textWidth = screenWidth  -- Use full screen width
            
            if type(game.dayOverReason.content) == "table" then
                for i, line in ipairs(game.dayOverReason.content) do
                    -- Skip empty lines
                    if line and line ~= "" then
                        -- Make the first line (FOREMAN) stand out in a different color
                        if i == 1 and line == "FOREMAN" then
                            love.graphics.setColor(unpack(COLORS.emphasis))
                            love.graphics.setFont(assets.font)
                            local fWidth = assets.font:getWidth(line)
                            love.graphics.print(line, screenWidth/2 - fWidth/2, contentY)
                        else
                            story.processFormattedText(line, 0, contentY, textWidth, "center")
                        end
                        contentY = contentY + lineSpacing
                    end
                end
                
                -- Check if this is the victory screen (day 6)
                if title == "YOU WIN" or (game.dayClock and game.dayClock.day == 6) then
                    -- Draw the final score with emphasis
                    contentY = contentY + lineSpacing
                    love.graphics.setColor(unpack(COLORS.emphasis))
                    local scoreText = "FINAL SCORE: " .. string.format("%06d", game.score)
                    local scoreWidth = assets.font:getWidth(scoreText)
                    love.graphics.print(scoreText, screenWidth/2 - scoreWidth/2, contentY)
                end
            else
                -- Fallback for string content
                love.graphics.setColor(unpack(COLORS.text))
                -- Ensure the content is a string
                local content = tostring(game.dayOverReason.content or "")
                love.graphics.printf(content, 0, contentY, textWidth, "center")
            end
        end
        
        -- Continue instructions
        love.graphics.setColor(unpack(COLORS.continue))
        local continueText = "Click anywhere to continue"
        local continueWidth = assets.font:getWidth(continueText)
        
        -- Draw continue text at bottom
        love.graphics.print(continueText, screenWidth/2 - continueWidth/2, screenHeight*3/4 + textH)
    end
end

-- Function to draw game over overlay
function story.drawGameOverOverlay()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Semi-transparent black overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Game over text
    love.graphics.setColor(1, 0, 0)
    love.graphics.setFont(assets.font)
    local text = "GAME OVER"
    local textWidth = assets.font:getWidth(text)
    local textHeight = assets.font:getHeight()
    
    -- Draw text centered on screen
    love.graphics.print(text, screenWidth/2 - textWidth/2, screenHeight/3 - textHeight/2)
    
    -- Game over reason text
    love.graphics.setColor(1, 1, 1)
    local reasonText = game.gameOverReason or "Danger tiles remained at the end of the day"
    local reasonWidth = assets.font:getWidth(reasonText)
    
    -- Draw reason text below game over text
    love.graphics.print(reasonText, screenWidth/2 - reasonWidth/2, screenHeight/2 - textHeight/2)
    
    -- Restart instructions
    love.graphics.setColor(0.8, 0.8, 1)
    local restartText = "Refresh the page to restart"
    local restartWidth = assets.font:getWidth(restartText)
    
    -- Draw restart text below info text
    love.graphics.print(restartText, screenWidth/2 - restartWidth/2, screenHeight/2 + textHeight*2)
end

return story 