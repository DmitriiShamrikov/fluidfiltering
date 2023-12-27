require('debug')
require('ui')

local g_PumpConnectionsCache = {}
local g_Signals = {} -- {group => {{SignalID},{SignalID}}}

CircuitMode =
{
	None = 0,
	EnableDisable = 1,
	SetFilter = 2
}

-- global.pumps - {{entity, CircuitMode}, ...}
-- global.wagons - {{entity, filter (string)}}

function GetSignalGroups()
	if #(g_Signals) == 0 then
		for _, group in pairs(game.item_group_prototypes) do
			local signals = {}
			for _, subgroup in pairs(group.subgroups) do
				local prototypes = game.get_filtered_item_prototypes({{filter = 'subgroup', subgroup = subgroup.name}})
				if #(prototypes) > 0 then
					local subsignals = {}
					for _, proto in pairs(prototypes) do
						if not proto.has_flag('hidden') then
							table.insert(subsignals, {type='item', name=proto.name})
						end
					end
					if #(subsignals) > 0 then
						table.insert(signals, subsignals)
					end
					goto continue
				end
	
				prototypes = game.get_filtered_fluid_prototypes({{filter = 'subgroup', subgroup = subgroup.name}})
				if #(prototypes) > 0 then
					local subsignals = {}
					for _, proto in pairs(prototypes) do
						if not proto.hidden then
							table.insert(subsignals, {type='fluid', name=proto.name})
						end
					end
					if #(subsignals) > 0 then
						table.insert(signals, subsignals)
					end
					goto continue
				end
	
				local subsignals = {}
				for _, vsignal in pairs(game.virtual_signal_prototypes) do
					if vsignal.name ~= 'signal-each' and vsignal.subgroup.name == subgroup.name then
						table.insert(subsignals, {type='virtual', name=vsignal.name, special=vsignal.special})
					end
				end
				if #(subsignals) > 0 then
					table.insert(signals, subsignals)
				end

				::continue::
			end

			if #(signals) > 0 then
				g_Signals[group.name] = signals
			end
		end

	end

	return g_Signals
end

function GetSignalGroup(signalName)
	for groupName, signals in pairs(g_Signals) do
		for _, subgroup in pairs(signals) do
			for _, signal in pairs(subgroup) do
				if signal.name == signalName then
					return groupName
				end
			end
		end
	end
	return nil
end

function IsCircuitNetworkUnlocked(player)
	return player.force.recipes['red-wire'] ~= nil and player.force.recipes['red-wire'].enabled
end

function IsLogisticNetworkUnlocked(player)
	return player.force.recipes['roboport'] ~= nil and player.force.recipes['roboport'].enabled
end

function IsConnectedToCircuitNetwork(entity)
	return entity.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.pump) ~= nil
		or entity.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.pump) ~= nil
end

function IsConnectedToLogisticNetwork(entity)
	local behavior = entity.get_control_behavior()
	return behavior and behavior.connect_to_logistic_network
end

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
	global.pumps = QueryEntities({type='pump'}, function(entity) return {entity, CircuitMode.None} end)
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
	global.pumps[entity.unit_number] = {entity, CircuitMode.None}
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
			global.pumps[event.source.unit_number] = {event.source, CircuitMode.None}
		end
		if global.pumps[event.destination.unit_number] == nil then
			global.pumps[event.destination.unit_number] = {event.destination, CircuitMode.None}
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

function UpdateCircuit(pump, circuitMode)
	if circuitMode == CircuitMode.SetFilter then
		local newFilter = GetFilterFromCircuitNetwork(pump)
		local fb = pump.fluidbox
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

			local openedEntityState = g_OpenedEntities[pump.unit_number]
			if openedEntityState and (openedEntityState.active ~= pump.active or openedEntityState.status ~= pump.status) then
				local event = {
					entity = pump,
					--prevStatus = openedEntityState.status,
					--wasActive = openedEntityState.active,
				}

				script.raise_event(ON_ENTITY_STATE_CHANGED, event)

				openedEntityState.active = pump.active
				openedEntityState.status = pump.status
			end
		end
	end
end

script.on_init(InitGlobal)
script.on_configuration_changed(InitGlobal)

script.on_event(defines.events.on_tick, function(event)
	UpdatePumps()
end)

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

-- filter-pumps with circuits
-- everything is connected to a red wire sending [steam=1]
water: pipe -> filter-pump[None][]      -> pipe | yes
water: pipe -> filter-pump[None][water] -> pipe | yes
water: pipe -> filter-pump[None][steam] -> pipe | no
water: pipe -> filter-pump[steam=1][]      -> pipe | yes
water: pipe -> filter-pump[steam=1][water] -> pipe | yes
water: pipe -> filter-pump[steam=1][steam] -> pipe | no
water: pipe -> filter-pump[steam=2][steam] -> pipe | no
water: pipe -> filter-pump[set][*] -> pipe | no
steam: pipe -> filter-pump[set][*] -> pipe | yes

]]