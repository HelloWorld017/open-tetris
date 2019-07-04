local minos, minos_all, mino_by_name, get_mino = require("./mino")()
local Visualizer = {}
Visualizer.__index = Visualizer

function Visualizer.new(game)
	local self = setmetatable({}, Visualizer)
	self.game = game
	self.render_rect = function() end
	
	self.width = 160
	self.height = 50
	
	self.mino_size = math.floor(self.height * 0.8 / 20)
	
	self.grid_width = 2
	
	self.playfield_width = 10 * self.mino_size
	self.playfield_height = 20 * self.mino_size
	self.playfield_x = math.floor((self.width - self.playfield_width) / 2)
	self.playfield_y = math.floor(self.height * 0.1)
	
	self.holder_mino_size = math.floor(self.mino_size / 2)
	self.holder_width = self.holder_mino_size * 6
	self.holder_gap = math.floor(self.holder_mino_size * 1.5)
	self.holder_stroke = 3
	
	self.hold_x = math.floor(self.playfield_x * 0.9) - self.holder_width
	self.hold_y = self.playfield_y
	
	self.next_x = math.floor(self.playfield_x * 1.1) + self.playfield_width
	self.next_y = self.playfield_y
	
	self.palette = {
		['grey-100'] = {24, 24, 24},
		['grey-200'] = {37, 37, 37},
		['grey-700'] = {180, 180, 180},
		['grey-800'] = {190, 190, 190},
		['grey-850'] = {220, 220, 220},
		['grey-900'] = {241, 241, 241},
		['red-400'] = {255, 82, 82},
		['orange-400'] = {255, 121, 63},
		['yellow-400'] = {246, 185, 59},
		['green-400'] = {120, 224, 143},
		['cyan-400'] = {5, 186, 221},
		['cyan-600'] = {130, 204, 221},
		['blue-400'] = {52, 172, 224},
		['purple-400'] = {112, 111, 211}
	}
	
	self.textures = {}
	self.shapes = {}
	self.offsets = {}
	
	for i, Mino in ipairs(minos_all) do
		self.textures[Mino.name] = self.palette[Mino.color]

		local test_mino = Mino.new(self.game)
		self.shapes[Mino.name] = test_mino.shape
		self.offsets[Mino.name] = {x = test_mino.view_xoffset, y = test_mino.view_yoffset}
	end
	
	return self
end

function Visualizer.draw_rect(self, color, x, y, w, h, color_bg, alpha)
	local alpha_mode = color_bg ~= nil
	local blend_color = color
	
	if alpha_mode then
		local alpha_float = alpha / 255
		
		blend_color = {
			math.floor(color[1] * alpha_float + color_bg[1] * (1 - alpha_float)),
			math.floor(color[2] * alpha_float + color_bg[2] * (1 - alpha_float)),
			math.floor(color[3] * alpha_float + color_bg[3] * (1 - alpha_float))
		}
	end
	
	self:render_rect(
		blend_color, x, y, w, h
	)
end

function Visualizer.draw_playfield_grid(self, grid_halfwidth)
	for x = 1, 9 do
		self:draw_rect(
			self.palette['grey-200'],
			self.playfield_x + x * self.mino_size - grid_halfwidth,
			self.playfield_y,
			grid_halfwidth * 2,
			self.playfield_height
		)
	end
	
	for y = 1, 19 do
		self:draw_rect(
			self.palette['grey-200'],
			self.playfield_x,
			self.playfield_y + y * self.mino_size - grid_halfwidth,
			self.playfield_width,
			grid_halfwidth * 2
		)
	end
end

function Visualizer.draw_playfield_mino(self)
	local playfield = self.game:playfield_dropping()
	local dropping = self.game:curr_piece()
	local ghost_x, ghost_y, ghost_rot = dropping:get_landing_position()
	
	for y = 1, 20 do
		for x = 1, 10 do
			local tile = playfield[y][x]
			local ghost = false
			
			if dropping:is_position_mino_translate(x, y, ghost_x, ghost_y) then
				ghost = true
				
				if tile ~= nil then
					ghost = false
				else
					tile = dropping:get_position_tile_translate(x, y, ghost_x, ghost_y)
				end
			end
			
			if tile ~= nil then
				self:draw_rect(
					self.textures[tile.texture],
					self.playfield_x + self.mino_size * (x - 1),
					self.playfield_y + self.mino_size * (20 - y),
					self.mino_size,
					self.mino_size,
					self.palette['grey-100'],
					ghost and 128 or 255
				)
			end
		end
	end
end

function Visualizer.draw_holder(self, ox, oy, mino)
	self:draw_rect(
		self.palette['grey-200'],
		ox,
		oy,
		self.holder_width,
		self.holder_width
	)
	
	self:draw_rect(
		self.palette['grey-900'],
		ox + self.holder_stroke,
		oy + self.holder_stroke,
		self.holder_width - 2 * self.holder_stroke,
		self.holder_width - 2 * self.holder_stroke
	)
	if mino == nil then return end

	local color = self.textures[mino.name]
	local shape = self.shapes[mino.name]
	
	local start_x = math.floor(
		self.holder_mino_size * (
			(6 - #shape) / 2 + self.offsets[mino.name]['x']
		) + ox
	)
	
	local start_y = math.floor(
		self.holder_mino_size * (
			(6 - #shape) / 2 + self.offsets[mino.name]['y']
		) + oy
	)
	
	for y = 1, #shape do
		for x = 1, #shape do
			if shape[y][x] ~= 0 then
				self:draw_rect(
					color,
					start_x + self.holder_mino_size * (x - 1),
					start_y + self.holder_mino_size * (y - 1),
					self.holder_mino_size,
					self.holder_mino_size
				)
			end
		end
	end
end

function Visualizer.draw_next_hold(self)
	for i, mino in ipairs(self.game.drop:next_n_piece(5)) do
		self:draw_holder(
			self.next_x,
			self.next_y + (self.holder_gap + self.holder_width) * (i - 1),
			mino
		)
	end
	
	self:draw_holder(self.hold_x, self.hold_y, get_mino(self.game.hold.holding_piece))
end

function Visualizer.render(self, redraw_playfield)
	
	if redraw_playfield == nil and true or redraw_playfield then
		self:draw_rect(self.palette['grey-900'], 0, 0, self.width, self.height)
	end
	
	self:draw_rect(
		self.palette['grey-100'],
		self.playfield_x,
		self.playfield_y,
		self.playfield_width,
		self.playfield_height
	)
	
	-- self:draw_playfield_grid(self.grid_width / 2)
	self:draw_playfield_mino()
	self:draw_next_hold()
end

return Visualizer
