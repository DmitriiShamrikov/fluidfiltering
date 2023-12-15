require('debug')
require('ui')

-- Unfortunately pumping from a fluid wagon doesn't seem working through fluidboxes
-- therefore fluidbox filter on a pump doesn't stop a pump to pump a wrong fluid from a wagon
-- As a workaround I run through all pumps and disable them if there is a fluid wagon
-- with a wrong fluid in front of them
-- Apart from that pumps have LuaGenericOnOffControlBehavior (which can't be changed)
-- that doesn't support filters like LuaInserterControlBehavior, so again, I have to manually
-- check every frame if a signal has changed and set corresponsing filter
local PUMP_WAGON_CHECK_PERIOD = 1

local g_SelectedEntity = nil
local g_PumpConnectionsCache = {}

-- global.pumps - array of entries, each entry is a pair of entity and a bool signifying if the pump should set the filter from circuit network
-- global.wagons - array of entries, each entry is a pair of entity and a filter (string)

function QueryEntities(filter, fn)
	local surfaces = {}
	for _, player in ipairs(game.connected_players) do
		if player ~= nil and player.surface ~= nil then
			surfaces[player.surface] = true
		end
	end

	local result = {}
	for surface, _ in pairs(surfaces) do
		local entities = surface.find_entities_filtered{area=nil, name=filter.name, type=filter.type}
		for _, entity in ipairs(entities) do
			result[entity.unit_number] = fn and fn(entity) or entity
		end
	end

	return result
end

function PopulatePumps()
	global.pumps = QueryEntities({type='pump'}, function(entity) return {entity, false} end)
end

function InitGlobal()
	if global.pumps == nil then
		PopulatePumps()
	end

	if global.wagons == nil then
		global.wagons = {}
	end
end

function OnEntityBuilt(event)
	RegisterPump(event.created_entity)
	if event.tags then
		local filter = event.tags['filter']
		if filter then
			event.created_entity.fluidbox.set_filter(1, {name=filter, force=true})

			local player = game.get_player(event.player_index)
			if player ~= nil then
				player.print('Setting filter for entity ' .. event.created_entity.unit_number .. ': ' .. filter)
			end
		end
	end
end

function RegisterPump(entity)
	global.pumps[entity.unit_number] = {entity, false}
	script.register_on_entity_destroyed(entity)
end

function UnregisterEntity(uid)
	global.wagons[uid] = nil
	global.pumps[uid] = nil
	g_PumpConnectionsCache[uid] = nil
end

function OnSettingsPasted(event)
	if event.source.type == 'pump' and event.destination.name == 'filter-pump' then
		-- that shouldn't noramlly happen, just being extra careful
		if global.pumps[event.source.unit_number] == nil then
			global.pumps[event.source.unit_number] = {event.source, false}
		end
		if global.pumps[event.destination.unit_number] == nil then
			global.pumps[event.destination.unit_number] = {event.destination, false}
		end

		local filter = event.source.fluidbox.get_filter(1)
		if filter then
			filter.force = true
		end
		event.destination.fluidbox.set_filter(1, filter)
	elseif event.source.type == 'fluid-wagon' and event.destination.name == 'filter-fluid-wagon' then
		local filter = global.wagons[event.source.unit_number] and global.wagons[event.source.unit_number][2] or nil
		if filter == nil then
			global.wagons[event.destination.unit_number] = nil
		else
			global.wagons[event.destination.unit_number] = {event.destination, filter}
			script.register_on_entity_destroyed(event.destination)

			local wagonFluid = event.destination.fluidbox[1]
			if wagonFluid ~= nil and wagonFluid.amount > 0 and wagonFluid.name ~= filter then
				event.destination.fluidbox[1] = nil
			end
		end
	end
end

function OnBlueprintSelected(event)
	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	local bp = nil
	if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == 'blueprint' then
		bp = player.cursor_stack -- this is for Ctrl+C
	elseif player.blueprint_to_setup and player.blueprint_to_setup.valid_for_read then
		bp = player.blueprint_to_setup -- this is for Create Blueprint button
	end

	-- we can handle both cases here because entities can't be added in blueprint configuration window

	for bpIndex, entity in ipairs(event.mapping.get()) do
		if global.pumps[entity.unit_number] ~= nil then
			local filter = entity.fluidbox.get_filter(1)
			if filter then
				bp.set_blueprint_entity_tag(bpIndex, 'filter', filter.name)
			end
		end
	end
end

------ Update -----

function Contains(bbox, pos)
	local topLeft = bbox.left_top or bbox[1]
	local bottomRight = bbox.right_bottom or bbox[2]
	topLeft = {topLeft.x or topLeft[1], topLeft.y or topLeft[2]}
	bottomRight = {bottomRight.x or bottomRight[1], bottomRight.y or bottomRight[2]}
	pos = {pos.x or pos[1], pos.y or pos[2]}
	return pos[1] >= topLeft[1] and pos[1] <= bottomRight[1] and
			pos[2] >= topLeft[2] and pos[2] <= bottomRight[2]
end

function GetInputPosition(entity)
	if g_PumpConnectionsCache[entity.unit_number] == nil or g_PumpConnectionsCache[entity.unit_number][1] == nil then
		local offset = nil
		for _, connection in ipairs(entity.prototype.fluidbox_prototypes[1].pipe_connections) do
			if connection.type == 'input' then
				local dirIdx = entity.direction / 2 + 1
				offset = connection.positions[dirIdx]
				break
			end
		end

		local pos = entity.position
		pos = {(pos[1] or pos.x) + (offset[1] or offset.x), (pos[2] or pos.y) + (offset[2] or offset.y)}

		g_PumpConnectionsCache[entity.unit_number] = {}
		if Contains(entity.pump_rail_target.bounding_box, pos) then
			g_PumpConnectionsCache[entity.unit_number][1] = pos
		else
			g_PumpConnectionsCache[entity.unit_number][1] = {}
		end
	end
	return g_PumpConnectionsCache[entity.unit_number][1]
end

function GetOutputPosition(entity)
	if g_PumpConnectionsCache[entity.unit_number] == nil or g_PumpConnectionsCache[entity.unit_number][2] == nil then
		local offset = nil
		for _, connection in ipairs(entity.prototype.fluidbox_prototypes[1].pipe_connections) do
			if connection.type == 'output' then
				local dirIdx = entity.direction / 2 + 1
				offset = connection.positions[dirIdx]
				break
			end
		end

		local pos = entity.position
		pos = {(pos[1] or pos.x) + (offset[1] or offset.x), (pos[2] or pos.y) + (offset[2] or offset.y)}

		g_PumpConnectionsCache[entity.unit_number] = {}
		if Contains(entity.pump_rail_target.bounding_box, pos) then
			g_PumpConnectionsCache[entity.unit_number][2] = pos
		else
			g_PumpConnectionsCache[entity.unit_number][2] = {}
		end
	end
	return g_PumpConnectionsCache[entity.unit_number][2]
end

function ShouldEnablePump(pump)
	local railTarget = pump.pump_rail_target
	if railTarget == nil then
		g_PumpConnectionsCache[pump.unit_number] = nil
		return true
	end

	local pumpFbox = pump.fluidbox
	local pumpFilter = pumpFbox.get_filter(1)
	if pumpFilter ~= nil then
		local inputPos = GetInputPosition(pump)
		if next(inputPos) ~= nil then
			local wagons = railTarget.surface.find_entities_filtered{area=railTarget.bounding_box, type='fluid-wagon'}
			-- normally there should be only 1 wagon
			for _, wagon in ipairs(wagons) do
				local wagonFluid = wagon.fluidbox[1]
				if wagonFluid ~= nil and wagonFluid.amount > 0 and wagonFluid.name ~= pumpFilter.name then
					return false
				end
			end
		end
	end

	local pumpFluid = #(pumpFbox) > 0 and pumpFbox[1] ~=nil and pumpFbox[1].amount > 0 and pumpFbox[1].name or nil
	if pumpFluid ~= nil then
		local outputPos = GetOutputPosition(pump)
		if next(outputPos) ~= nil then
			local wagons = railTarget.surface.find_entities_filtered{area=railTarget.bounding_box, type='fluid-wagon'}
			-- normally there should be only 1 wagon
			for _, wagon in ipairs(wagons) do
				local wagonEntry = global.wagons[wagon.unit_number]
				local wagonFilter = wagonEntry and wagonEntry[2] or nil
				if wagonFilter ~= nil and wagonFilter ~= pumpFluid then
					return false
				end
			end
		end
	end

	return true
end

function FindASignal(network)
	if network and network.signals then
		for i = 1, #(network.signals) do
			if network.signals[i].count > 0 and network.signals[i].signal.type == 'fluid' then
				return network.signals[i].signal.name
			end
		end
	end
	return nil
end

function GetFilterFromCircuitNetwork(pump)
	local network = pump.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.pump)
	local signal = FindASignal(network)
	if signal ~= nil then
		return signal
	end

	network = pump.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.pump)
	signal = FindASignal(network)
	return signal
end

function UpdateCircuit(pump, circuitFilterEnabled)
	local fb = pump.fluidbox
	if circuitFilterEnabled then
		local newFilter = GetFilterFromCircuitNetwork(pump)
		local filter = fb.get_filter(1)
		if newFilter == nil and filter ~= nil then
			fb.set_filter(1, nil)
		elseif newFilter ~= nil and (filter == nil or filter.name ~= newFilter) then
			fb.set_filter(1, {name=newFilter, force=true})
		end
	end
end

function UpdateState(pump)
	local enable = ShouldEnablePump(pump)
	if enable ~= pump.active then
		pump.active = enable
		game.print((enable and 'Enabling' or 'Disabling') .. ' pump ' .. pump.unit_number)
	end
end

function UpdatePumps()
	for uid, entry in pairs(global.pumps) do
		if entry == nil or entry[1] == nil or not entry[1].valid then
			global.pumps[uid] = nil
		else
			local pump = entry[1]
			UpdateCircuit(pump, entry[2])
			UpdateState(pump)
		end
	end
end

script.on_init(InitGlobal)
script.on_configuration_changed(InitGlobal)

script.on_nth_tick(PUMP_WAGON_CHECK_PERIOD, UpdatePumps)

local entityFilters = {{filter='type', type='pump'}}
script.on_event(defines.events.on_built_entity, OnEntityBuilt, entityFilters)
script.on_event(defines.events.on_robot_built_entity, OnEntityBuilt, entityFilters)

script.on_event(defines.events.on_entity_destroyed, function(event)
	if event.unit_number ~= nil then
		UnregisterEntity(event.unit_number)
	end
end)

script.on_event(defines.events.on_player_rotated_entity, function(event)
	g_PumpConnectionsCache[event.entity.unit_number] = nil
end)

script.on_event(defines.events.on_entity_settings_pasted, OnSettingsPasted)
script.on_event(defines.events.on_player_setup_blueprint, OnBlueprintSelected)

--[[

tests:

-- vanilla stuff
water: pipe -> pump               -> pipe        | yes
water: pipe -> pump               -> fluid-wagon | yes
water: fluid-wagon -> pump        -> pipe        | yes

-- filter-pump with vanilla stuff
water: pipe -> filter-pump[water] -> pipe        | yes
steam: pipe -> filter-pump[water] -> pipe        | no
water: pipe -> filter-pump[]      -> pipe        | yes
steam: pipe -> filter-pump[]      -> pipe        | yes
water: tank -> filter-pump[water] -> pipe        | yes
steam: tank -> filter-pump[water] -> pipe        | no
water: pipe -> filter-pump[water] -> tank        | yes
steam: pipe -> filter-pump[water] -> tank        | no

-- filter-pump with vanilla wagons 
water: fluid-wagon -> filter-pump[water] -> pipe | yes
steam: fluid-wagon -> filter-pump[water] -> pipe | no
water: fluid-wagon -> filter-pump[]      -> pipe | yes
steam: fluid-wagon -> filter-pump[]      -> pipe | yes
water: pipe -> filter-pump[water] -> fluid-wagon | yes
steam: pipe -> filter-pump[water] -> fluid-wagon | no
water: pipe -> filter-pump[]      -> fluid-wagon | yes
steam: pipe -> filter-pump[]      -> fluid-wagon | yes

-- filter-fluid-wagon with vanilla stuff
water: pipe -> pump -> filter-fluid-wagon[]      | yes
water: pipe -> pump -> filter-fluid-wagon[water] | yes
steam: pipe -> pump -> filter-fluid-wagon[water] | no
water: filter-fluid-wagon[] -> pump -> pipe      | yes
water: filter-fluid-wagon[water] -> pump -> pipe | yes

-- filter-pumps with filter-fluid-wagons
water: filter-fluid-wagon[]      -> filter-pump[water] -> pipe | yes
steam: filter-fluid-wagon[]      -> filter-pump[water] -> pipe | no
water: filter-fluid-wagon[]      -> filter-pump[]      -> pipe | yes
steam: filter-fluid-wagon[]      -> filter-pump[]      -> pipe | yes
water: filter-fluid-wagon[water] -> filter-pump[water] -> pipe | yes
steam: filter-fluid-wagon[steam] -> filter-pump[water] -> pipe | no
water: filter-fluid-wagon[water] -> filter-pump[]      -> pipe | yes
steam: filter-fluid-wagon[steam] -> filter-pump[]      -> pipe | yes

]]