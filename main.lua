function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setNewFont(24)
    love.graphics.print("Hello2 World!", 400, 300, 0, 1, 1, 100, 12)
end

function love.update(dt)
    -- Update game state here
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end 