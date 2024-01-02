require('constants')

local g_InputEvents = {} -- {player-index => {event-name => last-tick-fired}}
local g_PumpConnectionsCache = {}
local g_FilterPrototypesCache = nil
local g_Signals = {} -- {group => {{SignalID},{SignalID}}}
local g_RecentlyDeletedEntities = {} -- {{MapPosition, CircuitMode, filter (string)}, ...}

-- global.pumps - {unit-number => {entity, CircuitMode, {render-object-id, ...}}, ...} -- contains ALL pumps
-- global.wagons - {unit-number => {entity, filter (string)}} -- contains only wagons with filters
-- global.guiState - {player-index => {entity=entity, entityWindow={}, signalWindow={}}}
-- global.openedEntities = {} -- {entity-id => {players={player-index, ...}, active=bool, status=int}}

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

function IsFilterEntity(entity)
	if g_FilterPrototypesCache == nil then
		g_FilterPrototypesCache = {}
		local techProto = game.technology_prototypes[DUMMY_TECH_NAME]
		if techProto then
			for _, effect in pairs(techProto.effects) do
				local itemProto = game.item_prototypes[effect.item]
				if itemProto and itemProto.place_result then
					g_FilterPrototypesCache[itemProto.place_result.name] = true
				end
			end
		end
	end
	return g_FilterPrototypesCache[entity.name] ~= nil
end

function IsGhost(entity)
	return entity.type == 'entity-ghost'
end

function IsPump(entity)
	return entity.type == 'pump'
end

function IsGhostPump(entity)
	return entity.type == 'entity-ghost' and entity.ghost_type == 'pump'
end

function IsFilterPump(entity)
	return IsPump(entity) and IsFilterEntity(entity)
end

function IsFluidWagon(entity)
	return entity.type == 'fluid-wagon'
end

function IsFilterFluidWagon(entity)
	return IsFluidWagon(entity) and IsFilterEntity(entity)
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
	global.pumps = QueryEntities({type='pump'}, function(entity) return {entity, CircuitMode.None, {}} end)
end

function InitGlobal()
	if global.pumps == nil then
		PopulatePumps()
	end

	if global.wagons == nil then
		global.wagons = {}
	end

	if global.guiState == nil then
		global.guiState = {}
	end

	if global.openedEntities == nil then
		global.openedEntities = {}
	end
end

function OnEntityBuilt(event)
	-- This is a really hacky way to determine if a ghost or entiy was placed by undo rather than a newly built one
	-- I don't track 'undo' input because Undo can be performed via a button from GUI
	-- Unfortunately, this doesn't work when the game is paused in editor, because tick counter is not increased
	local placedByPlayer = event.name == defines.events.on_built_entity
	local placedByDying = event.name == defines.events.on_post_entity_died
	local clickedToBuild = placedByPlayer and (g_InputEvents[event.player_index][BUILD_GHOST_INPUT_EVENT] == event.tick or g_InputEvents[event.player_index][BUILD_INPUT_EVENT] == event.tick)
	local placedByUndo = placedByPlayer and not clickedToBuild
	local historyEntry = (placedByUndo or placedByDying) and PopRecentlyDeletedEntry(event.created_entity.position) or nil
	local tags = event.created_entity.tags or event.tags or {}
	if historyEntry then
		tags['filter'] = historyEntry.filter
		tags['circuit_mode'] = historyEntry.circuitMode
	end

	if IsGhost(event.created_entity) then
		event.created_entity.tags = tags
		local filter = tags['filter']
		if filter and IsGhostPump(event.created_entity) then
			AddFilterIcon(event.created_entity, filter)
		end
	else
		if IsPump(event.created_entity) then
			RegisterPump(event.created_entity)
			if IsFilterPump(event.created_entity) then
				local filter = tags['filter']
				if filter then
					SetPumpFilter(event.created_entity, filter)
				else
					-- when entity is revived filter is not passed through ghost tags, but restored by fluidbox directly
					UpdateFilterIcon(event.created_entity)
				end

				local circuitMode = tags['circuit_mode']
				if circuitMode then
					global.pumps[event.created_entity.unit_number][2] = circuitMode
				end
			end
		elseif IsFilterFluidWagon(event.created_entity) then
			local filter = tags['filter']
			if filter then
				global.wagons[event.created_entity.unit_number] = {event.created_entity, filter}
				script.register_on_entity_destroyed(event.created_entity)
			end
		end
	end
end

function RegisterPump(entity)
	global.pumps[entity.unit_number] = {entity, CircuitMode.None, {}}
	script.register_on_entity_destroyed(entity)
end

function UnregisterEntity(uid)
	global.wagons[uid] = nil
	global.pumps[uid] = nil
	g_PumpConnectionsCache[uid] = nil
end

function OnSettingsPasted(event)
	-- we can copy settings from a normal pump (wagon) to a filter pump (wagon) - it will just clear the filter
	if IsPump(event.source) and IsFilterPump(event.destination) then
		-- that shouldn't noramlly happen, just being extra careful
		if global.pumps[event.source.unit_number] == nil then
			global.pumps[event.source.unit_number] = {event.source, CircuitMode.None, {}}
		end
		if global.pumps[event.destination.unit_number] == nil then
			global.pumps[event.destination.unit_number] = {event.destination, CircuitMode.None, {}}
		end

		local circuitMode = global.pumps[event.source.unit_number][2]
		if not IsFilterPump(event.source) and IsConnectedToCircuitNetwork(event.source) then
			circuitMode = CircuitMode.EnableDisable
		end
		global.pumps[event.destination.unit_number][2] = circuitMode

		local filter = event.source.fluidbox.get_filter(1)
		SetPumpFilter(event.destination, filter and filter.name or nil)
	elseif IsFluidWagon(event.source.type) and IsFilterFluidWagon(event.destination) then
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
			local circuitMode = global.pumps[entity.unit_number][2]
			bp.set_blueprint_entity_tag(bpIndex, 'circuit_mode', circuitMode)
			local filter = entity.fluidbox.get_filter(1)
			if filter then
				bp.set_blueprint_entity_tag(bpIndex, 'filter', filter.name)
			end
		elseif global.wagons[entity.unit_number] ~= nil then
			local filter = global.wagons[entity.unit_number][2]
			bp.set_blueprint_entity_tag(bpIndex, 'filter', filter)
		end
	end
end

function AddToRecentlyDeleted(entity)
	if #(g_RecentlyDeletedEntities) == MAX_DELETED_ENTITIES then
		table.remove(g_RecentlyDeletedEntities, 1)
	end

	local entry = {pos=entity.position}
	if IsFilterPump(entity) then
		entry.circuitMode = global.pumps[entity.unit_number][2]
		local filter = entity.fluidbox.get_filter(1)
		entry.filter = filter and filter.name or nil
	elseif IsFilterFluidWagon(entity) then
		local wagon = global.wagons[entity.unit_number]
		entry.filter = wagon and wagon[2] or nil
	-- ghosts
	elseif entity.tags then
		entry.circuitMode = entity.tags['circuit_mode']
		entry.filter = entity.tags['filter']
	end

	table.insert(g_RecentlyDeletedEntities, entry)
end

function PopRecentlyDeletedEntry(pos)
	for i = #(g_RecentlyDeletedEntities), 1, -1 do
		local entry = g_RecentlyDeletedEntities[i]
		if math.abs(entry.pos.x - pos.x) < 0.001 and math.abs(entry.pos.y - pos.y) < 0.001 then
			for j = #(g_RecentlyDeletedEntities), i, -1 do
				table.remove(g_RecentlyDeletedEntities, j)
			end
			return entry
		end
	end
	return nil
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

function AddFilterIcon(entity, fluid)
	return {
		rendering.draw_sprite{sprite='utility/entity_info_dark_background', x_scale=0.5, y_scale=0.5, target=entity, surface=entity.surface, only_in_alt_mode=true},
		rendering.draw_sprite{sprite='fluid/' .. fluid, x_scale=0.47, y_scale=0.47, target=entity, surface=entity.surface, only_in_alt_mode=true}
	}
end

function UpdateFilterIcon(pump)
	local filter = pump.fluidbox.get_filter(1)
	local fluid = filter and filter.name or nil
	if fluid then
		local ids = global.pumps[pump.unit_number][3]
		if #(ids) > 0 then
			local sprite = 'fluid/' .. fluid
			if rendering.get_sprite(ids[2]) ~= sprite then
				rendering.destroy(ids[2])
				ids[2] = rendering.draw_sprite{sprite='fluid/' .. fluid, x_scale=0.47, y_scale=0.47, target=pump, surface=pump.surface, only_in_alt_mode=true}
			end
		else
			global.pumps[pump.unit_number][3] = AddFilterIcon(pump, fluid)
		end
	else
		for _, id in pairs(global.pumps[pump.unit_number][3]) do
			rendering.destroy(id)
		end
		global.pumps[pump.unit_number][3] = {}
	end
end

function SetPumpFilter(pump, fluid)
	local fb = pump.fluidbox
	local filter = fb.get_filter(1)
	local currentFluid = filter and filter.name or nil
	if currentFluid ~= fluid then
		if fluid == nil then
			fb.set_filter(1, nil)
		else
			fb.set_filter(1, {name=fluid, force=true})
		end
		UpdateFilterIcon(pump)
	end
end

function UpdateCircuit(pump, circuitMode)
	if circuitMode == CircuitMode.SetFilter then
		local newFilter = GetFilterFromCircuitNetwork(pump)
		SetPumpFilter(pump, newFilter)
	end
end

function UpdateState(pump)
	local enable = ShouldEnablePump(pump)
	if enable ~= pump.active then
		pump.active = enable
		--game.print((enable and 'Enabling' or 'Disabling') .. ' pump ' .. pump.unit_number)
	end
end

function UpdatePumps()
	for uid, entry in pairs(global.pumps) do
		if entry == nil or entry[1] == nil or not entry[1].valid then
			global.pumps[uid] = nil
		else
			local pump = entry[1]
			UpdateCircuit(pump, entry[2])
			if not pump.to_be_deconstructed() then
				UpdateState(pump)
			end

			local openedEntityState = global.openedEntities[pump.unit_number]
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

local entityFilters = {{filter='type', type='pump'}, {filter='type', type='fluid-wagon'}, {filter='ghost_type', type='pump'}, {filter='ghost_type', type='fluid-wagon'}}
script.on_event(defines.events.on_built_entity, OnEntityBuilt, entityFilters)
script.on_event(defines.events.on_robot_built_entity, OnEntityBuilt, entityFilters)
script.on_event(defines.events.script_raised_built, function(event)
	local ev = {created_entity=event.entity, tick=event.tick, name=event.name}
	OnEntityBuilt(ev)
end, entityFilters)

script.on_event(defines.events.on_post_entity_died, function(event)
	if event.ghost and IsFilterPump(event.prototype) then
		local ev = {created_entity=event.ghost, tick=event.tick, name=event.name}
		OnEntityBuilt(ev)
	end
end, {{filter='type', type='pump'}})

script.on_event(defines.events.on_entity_destroyed, function(event)
	if event.unit_number then
		UnregisterEntity(event.unit_number)
		script.raise_event(ON_ENTITY_DESTROYED_CUSTOM, event)
	end
end)

script.on_event(defines.events.script_raised_destroy, function(event)
	if event.entity.unit_number then
		UnregisterEntity(event.entity.unit_number)
		local ev = {unit_number=event.entity.unit_number}
		script.raise_event(ON_ENTITY_DESTROYED_CUSTOM, ev)
	end
end, entityFilters)

script.on_event(defines.events.on_player_mined_entity, function(event)
	AddToRecentlyDeleted(event.entity)
end, entityFilters)

script.on_event(defines.events.on_pre_ghost_deconstructed, function(event)
	AddToRecentlyDeleted(event.ghost)
end, entityFilters)

script.on_event(defines.events.on_robot_mined_entity, function(event)
	AddToRecentlyDeleted(event.entity)
end, entityFilters)

entityFilters = {{filter='type', type='pump'}, {filter='type', type='fluid-wagon'}}
script.on_event(defines.events.on_entity_died, function(event)
	AddToRecentlyDeleted(event.entity)
end, entityFilters)

script.on_event(defines.events.on_player_rotated_entity, function(event)
	g_PumpConnectionsCache[event.entity.unit_number] = nil
end)

script.on_event(defines.events.on_entity_settings_pasted, OnSettingsPasted)
script.on_event(defines.events.on_player_setup_blueprint, OnBlueprintSelected)

script.on_event(BUILD_INPUT_EVENT, function(event)
	g_InputEvents[event.player_index] = g_InputEvents[event.player_index] or {}
	g_InputEvents[event.player_index][BUILD_INPUT_EVENT] = event.tick
end)

script.on_event(BUILD_GHOST_INPUT_EVENT, function(event)
	g_InputEvents[event.player_index] = g_InputEvents[event.player_index] or {}
	g_InputEvents[event.player_index][BUILD_GHOST_INPUT_EVENT] = event.tick
end)
