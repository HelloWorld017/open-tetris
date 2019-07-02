require('/compat')
local Tetris = require('./game')
local Visualizer = require('./visualizer')

local game = Tetris.new()
local vis = Visualizer.new(game)

local keymap = {
	left = game.controller.key_left,
	right = game.controller.key_right,
	x = game.controller.key_spin_cw,
	z = game.controller.key_spin_ccw,
	c = game.controller.key_hold,
	down = game.controller.key_softdrop,
	space = game.controller.key_harddrop
}

function vis.render_rect(vis, color, x, y, w, h)
	love.graphics.setColor({color[1] / 255, color[2] / 255, color[3] / 255})
	love.graphics.rectangle('fill', x, y, w, h)
end

function love.load()
	game:start_game()
end

function love.conf(t)
	t.console = true
end

function love.update(dt)
    game:update()
end

function love.draw()
	vis:render()
end

function love.keypressed(key)
	if keymap[key] ~= nil then
		game.controller:keydown(keymap[key])
	end
end

function love.keyreleased(key)
	if keymap[key] ~= nil then
		game.controller:keyup(keymap[key])
	end
end
