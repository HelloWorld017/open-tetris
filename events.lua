local EventEmitter = {}
EventEmitter.__index = EventEmitter

function EventEmitter.new(base)
	base = base or {}
	
	local self = setmetatable(base, EventEmitter)
	self._events = {}
	
	return self
end

function EventEmitter.on(self, event_name, callback)
	if self._events[event_name] == nil then
		self._events[event_name] = {}
	end
	
	table.insert(self._events[event_name], callback)
end

function EventEmitter.emit(self, event_name, payload)
	if self._events[event_name] == nil then
		return
	end
	
	for i, callback in ipairs(self._events[event_name]) do
		callback(payload)
	end
end

return EventEmitter
