local minos, minos_all, mino_by_name, get_mino = require("./mino")()
local MinoGarbage = mino_by_name["garbage"]

local EventEmitter = require("./events")
local Utils = require("./utils")


local default_configuration = {
    drop = {
        normal = {
            frame = 32,
            amount = 1
        },

        soft = {
            frame = 2,
            amount = 1
        }
    },

    lock = 30,

    das = {
        start = 12,
        period = 2
    }
}

local Controller = {}
Controller.__index = Controller

function Controller.new(game)
	local self = setmetatable({
		key_left = 'left',
		key_right = 'right',
		key_spin_cw = 'spin_cw',
		key_spin_ccw = 'spin_ccw',
		key_hold = 'hold',
		key_harddrop = 'harddrop',
		key_softdrop = 'softdrop',

		keys = {'left', 'right', 'spin_cw', 'spin_ccw', 'hold', 'harddrop', 'softdrop'}
	}, Controller)
	
	self.game = game
	self.pressed_keys = {}
	self.tick = 0
	return self
end

function Controller.keydown(self, key_name)
	if key_name == self.key_hold then
		self.game.hold:hold()

	elseif key_name == self.key_spin_ccw then
		self.game:curr_piece():rotate_left()
	
	elseif key_name == self.key_spin_cw then
		self.game:curr_piece():rotate_right()
	
	elseif key_name == self.key_harddrop then
		self.game:curr_piece():harddrop()
	
	elseif key_name == self.key_left then
		self.game:curr_piece():move_left()
	
	elseif key_name == self.key_right then
		self.game:curr_piece():move_right()
	end
	
	self.pressed_keys[key_name] = {true, self.tick}
	self.game:emit('keydown', {key_name = key_name})
end

function Controller.keyup(self, key_name)
	self.pressed_keys[key_name] = {false}
end

function Controller.update(self)
	self.tick = self.tick + 1
	
	for i, key in ipairs({self.key_left, self.key_right}) do
		if self.pressed_keys[key] ~= nil and self.pressed_keys[key][1] then
			elapsed_delay = self.tick - self.pressed_keys[key][2]
			
			if elapsed_delay >= self.game.configuration['das']['start'] and
				elapsed_delay % self.game.configuration['das']['period'] == 0 then
				
				if key == self.key_left then
					self.game:curr_piece():move_left()
				
				elseif key == self.key_right then
					self.game:curr_piece():move_right()
				end
			end
		end
	end
end

function Controller.is_pressed(self, key)
	return self.pressed_keys[key] ~= nil and self.pressed_keys[key][1]
end


local Drop = {}
Drop.__index = Drop

function Drop.new(game)
	local self = setmetatable({}, Drop)
	
	self.game = game
	self.dropping_piece = nil
	self.drop_tick = 0
	self.current_bag = nil
	self.next_bag = {}
	self:create_bag()
	self:create_bag()
	
	return self
end

function Drop.create_bag(self)
	self.current_bag = self.next_bag
	self.next_bag = Utils.shuffle(Utils.shallowcopy(minos))
end


function Drop.new_piece(self, piece_type, broadcast)
	local NewPiece = nil
	
	if piece_type ~= nil then
		NewPiece = get_mino(piece_type)
	else
		NewPiece = table.remove(self.current_bag, 1)
	end
	
	local piece = NewPiece.new(self.game)
	
	if #self.current_bag == 0 then
		self:create_bag()
	end
	
	if not piece:is_placeable() then
		self.game:game_over()
	end
	
	self.dropping_piece = piece
	
	if broadcast ~= false then
		self.game:emit('drop', piece)
	end
end

function Drop.update(self)
	self.dropping_piece:update()
	self.drop_tick = self.drop_tick + 1
	
	local key = 'normal'
	
	if self.game.controller:is_pressed(self.game.controller.key_softdrop) then
		key = 'soft'
	end
	
	if self.drop_tick > self.game.configuration['drop'][key]['frame'] then
		self.dropping_piece:drop(self.game.configuration['drop'][key]['amount'])
		self.drop_tick = 0
	end
	
end

function Drop.next_n_piece(self, n)
	local amount = math.min(7, n)
	local slice = {table.unpack(self.current_bag, 1, math.min(#self.current_bag, amount))}
	
	local left_amount = amount - #slice
	for i, value in ipairs({table.unpack(self.next_bag, 1, left_amount)}) do
		table.insert(slice, value)
	end
	
	return slice
end


local Hold = {}
Hold.__index = Hold

function Hold.new(game)
	local self = setmetatable({}, Hold)
	self.game = game
	self.holding_piece = nil
	self.is_last_hold = false
	
	self.game:on('drop', function(payload) self:on_drop() end)
	
	return self
end

function Hold.hold(self)
	if self.is_last_hold then
		return
	end
	
	local original_holding = self.holding_piece
	self.holding_piece = self.game:curr_piece().name
	self.game:drop_piece(original_holding, false)
	
	self.is_last_hold = true
end

function Hold.on_drop(self)
	self.is_last_hold = false
end


local ScoreCalc = {
	line_clear_text = {'Single', 'Double', 'Triple', 'Tetris'},
	combo_damage = {0, 1, 1, 2, 2, 3, 3, 4, 4, 4}
}
ScoreCalc.__index = ScoreCalc

function ScoreCalc.new(game)
	local self = setmetatable({}, ScoreCalc)
	self.game = game
	self.b2b = false
	self.combo = 0
	
	return self
end

function ScoreCalc.calc_score(self, clear_target)
	local damage = 0
	local text = {}
	local piece = self.game:curr_piece()
	local last_b2b = self.b2b
	local clear_y = {}
	
	for y, row in ipairs(clear_target) do
		table.insert(clear_y, y)
	end
	
	self.b2b = false

	-- T-Spin
	local is_tspin = false
	local is_mini = true
	
	if piece.last_successful_movement == 'rotate' and piece.name == 't' then
		local center_x = piece.x + 1
		local center_y = piece.y - 1
		
		local corners = 0
		
		for dx = 0, 1 do
			for dy = 0, 1 do
				local diagonal_x = center_x + (2 * dx - 1)
				local diagonal_y = center_y + (2 * dy - 1)
				
				if self.game:is_filled(diagonal_x, diagonal_y) then
					corners = corners + 1
				end
			end
		end
		
		if corners >= 3 then
			is_tspin = true
			local lri = piece.last_rotation_info
			
			if lri[2] == -2 and lri[1] ~= 0 then
				is_mini = false
			end
			
			local rotation_vector = piece.rotation_to_vector[piece.rotation]
			local normal_vector = {rotation_vector[2], rotation_vector[1]}
			local rotate_center = {center_x + rotation_vector[1], center_y + rotation_vector[2]}
			
			local diag1 = {rotate_center[1] + normal_vector[1], rotate_center[2] + normal_vector[2]}
			local diag2 = {rotate_center[1] + normal_vector[1] * -1, rotate_center[2] + normal_vector[2] * -1}
			
			if self.game:is_filled(diag1[1], diag1[2]) and self.game:is_filled(diag2[1], diag2[1]) then
				is_mini = false
			end
			
			table.insert(text, 'T-Spin')
			
			if not is_mini then
				damage = 1 + #clear_target + damage
			
			else
				table.insert(text, 'Mini')
			end
			
			if #clear_target > 0 then
				self.b2b = true
			end
		end
	end
	
	-- Default damage
	
	if #clear_target > 0 then
		if #clear_target < 4 then
			damage = damage + #clear_target - 1
		else
			damage = damage + 4
			self.b2b = true
		end
		
		table.insert(text, self.line_clear_text[#clear_target])
	end
	
	-- Perfect Clear
	
	local is_perfect = true
	for y = 1,40 do
		if not is_perfect then
			break
		end
		
		if not Utils.includes(clear_y, y) then
			for x = 1, 10 do
				if self.game.playfield[y][x] ~= nil then
					is_perfect = false
					break
				end
			end
		end
	end
	
	if is_perfect then
		table.insert(text, "Perfect Clear")
	end

	-- Back to Back
	
	local is_b2b = false
	
	if last_b2b and #clear_target > 0 then
		table.insert(text, "Back-to-Back")
		damage = damage + 1
		is_b2b = true
	end
	
	-- Combo Damage
	
	if self.combo > 0 and #clear_target > 0 then
		if self.combo <= 10 then
			damage = damage + self.combo_damage[self.combo]
		
		else
			damage = damage + 5

		end
		
		table.insert(text, tostring(self.combo) .. " Ren")
	end
	
	if #clear_target > 0 then
		self.combo = self.combo + 1
	else
		self.combo = 0
	end
	
	if is_perfect then
		damage = 10
	end
	
	return damage,  text, {
		['tspin'] = is_tspin and not is_mini,
		['tspin-mini'] = is_tspin and is_mini,
		['back-to-back'] = is_b2b,
		['perfect'] = is_perfect,
		['tetris'] = #clear_target == 4,
		['ren'] = self.combo,
		['clear'] = #clear_target
	}
end


local Tetris = setmetatable({}, {__index = EventEmitter})
Tetris.__index = Tetris

function Tetris.new(name, configuration)
	local self = setmetatable(EventEmitter.new(), Tetris)
	self.name = name or 'Player 1'
	self.configuration = configuration or default_configuration
	self.controller = Controller.new(self)
	self.drop = Drop.new(self)
	self.hold = Hold.new(self)
	self.calc = ScoreCalc.new(self)
	self.last_clear = {}
	self.opponent = nil
	self.garbage_amount = 0
	self.finished = false
	
	self.playfield = {}
	for y = 1, 40 do
		self.playfield[y] = Tetris.empty_row()
	end
	
	return self
end

function Tetris.empty_row()
	return {nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}
end

function Tetris.start_game(self)
	self:drop_piece()
end

function Tetris.curr_piece(self)
	return self.drop.dropping_piece
end

function Tetris.playfield_dropping(self)
	local playfield = {}
	
	for y = 1, 40 do
		playfield[y] = Utils.shallowcopy(self.playfield[y])
	end
	
	local mino = self:curr_piece()
	local shape = mino:rotation_shape()
	
	for dy = 0, mino:size() - 1 do
		for dx = 0, mino:size() - 1 do
			if shape[dy + 1][dx + 1] ~= 0 then
				playfield[mino.y - dy][mino.x + dx] = mino:get_tile(shape[dy + 1][dx + 1])
			end
		end
	end
	
	return playfield
end

function Tetris.is_filled(self, x, y)
	if x < 1 or x > 10 then
		return true
	end
	
	if y < 1 or y > 40 then
		return true
	end
	
	return self.playfield[y][x] ~= nil
end

function Tetris.update(self)
	if self.finished then
		return
	end
	
	self.drop:update()
	self.controller:update()
end

function Tetris.drop_piece(self, ...)
	self.drop:new_piece(...)
end

function Tetris.on_locked(self)
	local mino = self:curr_piece()
	
	for y = 0, mino:size() - 1 do
		for x = 0, mino:size() - 1 do
			tile_id = mino:rotation_shape()[y + 1][x + 1]
			
			if tile_id ~= 0 then
				self.playfield[mino.y - y][mino.x + x] = mino:get_tile(tile_id)
			end
		end
	end
	
	local clear_target = {}
	
	for y = 1, 40 do
		local clear = true
		
		for x = 1, 10 do
			if self.playfield[y][x] == nil then
				clear = false
				break
			end
		end
		
		if clear then
			table.insert(clear_target, {y, self.playfield[y]})
		end
	end
	
	local score, last_clear, clear_data = self.calc:calc_score(clear_target)
	self.last_clear = last_clear
	
	local index_accumulator = 0
	
	for i, clear_row in ipairs(clear_target) do
		table.remove(self.playfield, clear_row[1] - index_accumulator)
		
		-- as clear_target is sorted
		index_accumulator = index_accumulator + 1
	end
	
	for j = 1, 40 - #self.playfield do
		table.insert(self.playfield, self.empty_row())
	end
	
	self:drop_piece()
	self:emit('clear', {score, last_clear, clear_data})
	
	if self.opponent ~= nil then
		self.garbage_amount = self.garbage_amount - score
		if self.garbage_amount < 0 then
			self.opponent:after_fill_garbage(-self.garbage_amount)
			self.garbage_amount = 0
		end
		
		self:fill_garbage()
	end
end

function Tetris.game_over(self)
	self:emit('gameover')
	self.finished = true
end

function Tetris.connect_opponent(self, game)
	self.opponent = game
end

function Tetris.after_fill_garbage(self, garbage_amount)
	self.garbage_amount = self.garbage_amount + garbage_amount
end

function Tetris.fill_garbage(self)
	local garbage_lines = {}
	
	for i = 1, self.garbage_amount do
		local t = MinoGarbage.new(self):get_tile(1)
		table.insert(garbage_lines, Utils.shuffle({t, t, t, t, t, t, t, t, t, nil}))
	end
	
	local cutting_line = 40 - self.garbage_amount
	local rest_lines = {table.unpack(self.playfield, cutting_line + 1)}
	local new_playfield = garbage_lines
	
	for y = 1, cutting_line do
		new_playfield[#new_playfield + y] = self.playfield[y]
	end
	
	self.playfield = new_playfield
	
	for i, row in ipairs(rest_lines) do
		for j, mino in ipairs(row) do
			if mino ~= nil then
				self:game_over()
			end
		end
	end
end

return Tetris
