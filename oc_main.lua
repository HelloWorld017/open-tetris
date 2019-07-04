local component = require('component')
local event = require('event')

local Tetris = require('./game')
local Visualizer = require('./visualizer')

local OpenTetris = {}

function OpenTetris.init()
	OpenTetris.keymap = {
		[0xCB] = 'left',
		[0xCD] = 'right',
		[0x2D] = 'spin_cw',
		[0x2C] = 'spin_ccw',
		[0x2E] = 'hold',
		[0xD0] = 'softdrop',
		[0x39] = 'harddrop'
	}
	OpenTetris.init_screen()
	OpenTetris.init_input()
	OpenTetris.phase = 'pregame'
	OpenTetris.running = true
end

function OpenTetris.init_screen()
	local screen = component.list("screen", true)()
	local gpu = screen and component.list("gpu", true)()

	if not gpu then
		return
	end

	gpu = component.proxy(gpu)

	if not gpu.getScreen() then
		gpu.bind(screen)
	end

	w, h = gpu.maxResolution()
	gpu.setResolution(w, h)
	
	OpenTetris.render_rect = function(vis, color, x, y, w, h)
		color_code = color[1] * 256 * 256 + color[2] * 256 + color[3]
		
		gpu.setBackground(color_code)
		gpu.fill(x, y, w, h, ' ')
	end
	
	OpenTetris.width = w
	OpenTetris.height = h
end

function OpenTetris.init_input()
	OpenTetris.handler = {}
	OpenTetris.handler.key_down = function(name, addr, keychar, keycode)
		if OpenTetris.keymap[keycode] ~= nil and OpenTetris.phase == 'ingame' then
			OpenTetris.game.controller:keydown(OpenTetris.keymap[keycode])
		elseif OpenTetris.phase == 'pregame' and keycode == 0x1C then
			OpenTetris.start_game()
		end
	end
	
	OpenTetris.handler.key_up = function(name, addr, keychar, keycode)
		if OpenTetris.keymap[keycode] ~= nil and OpenTetris.phase == 'ingame' then
			OpenTetris.game.controller:keyup(OpenTetris.keymap[keycode])
		end
	end
	
	OpenTetris.handler.handle = function(eventID, ...)
		if eventID and eventID ~= 'handle' and OpenTetris.handler[eventID] then
			OpenTetris.handler[eventID](eventID, ...)
		end
	end
end

function OpenTetris.start_game()
	OpenTetris.game = Tetris.new('Player 1', {
		drop = {
			normal = {
				frame = 5,
				amount = 1
			},

			soft = {
				frame = 1,
				amount = 3
			}
		},

		lock = 5,

		das = {
			start = 2,
			period = 1,
			amount = 3
		}
	})
	OpenTetris.vis = Visualizer.new(OpenTetris.game)
	OpenTetris.vis.render_rect = OpenTetris.render_rect
	OpenTetris.vis.width = w
	OpenTetris.vis.height = h
	
	OpenTetris.phase = 'ingame'
	OpenTetris.game:start_game()
	OpenTetris.game:on('gameover', function()
		OpenTetris.phase = 'postgame'
	end)
end

function OpenTetris.update()
	if OpenTetris.phase == 'ingame' then
		OpenTetris.game:update()
		OpenTetris.vis:render(false)
	end
end

function OpenTetris.loop()
	second_per_frame = 1 / 30
	OpenTetris.timer = event.timer(second_per_frame, OpenTetris.update, math.huge)
end

OpenTetris.init()
OpenTetris.start_game()
OpenTetris.vis:render()
OpenTetris.loop()

while OpenTetris.running do
	OpenTetris.handler.handle(event.pull())
end
