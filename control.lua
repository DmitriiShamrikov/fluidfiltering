local FRAME_NAME = 'ui-liquid-filter-ui'
local CHOOSE_BUTTON_NAME = 'ui-liquid-filter-chooser'
-- Unfortunately pumping from a fluid wagon doesn't seem working through fluidboxes
-- therefore fluidbox filter on a pump doesn't work in this case. As a workaround
-- I run through all pumps and disable them if there is a fluid wagon with a wrong fluid in front of them
-- Can I check that not every frame?
local PUMP_WAGON_CHECK_PERIOD = 1

local g_SelectedEntity = nil
local g_InputPositionCache = {}

function InitGlobal()
	if global.pumps == nil then
		Populate()
	end
end

function OpenFilterBox(playerIndex, entity)
	local player = game.get_player(playerIndex)
	if player == nil then
		return
	end
	
	local filterFrame = player.gui.relative[FRAME_NAME]
	if filterFrame == nil then
		local anchor = {
			gui = defines.relative_gui_type.entity_with_energy_source_gui,
			position = defines.relative_gui_position.bottom,
			name = 'filter-pump'
		}
		filterFrame = player.gui.relative.add{type='frame', name=FRAME_NAME, caption='Filter', anchor=anchor}
		filterFrame.add{type='choose-elem-button', name=CHOOSE_BUTTON_NAME, elem_type='fluid'}
	end

	local filter = entity.fluidbox.get_filter(1)
	filterFrame[CHOOSE_BUTTON_NAME].elem_value = filter and filter.name or nil

	g_SelectedEntity = entity
end

function SetFilter(playerIndex, fluid)
	if fluid == nil then
		g_SelectedEntity.fluidbox.set_filter(1, nil)
	else
		g_SelectedEntity.fluidbox.set_filter(1, {name=fluid, force=true})
	end

	local player = game.get_player(playerIndex)
	if player ~= nil then
		player.print('Setting filter for the entity ' .. g_SelectedEntity.unit_number .. ': ' .. (fluid or 'none'))
	end
end

function RegisterPump(entity)
	global.pumps[entity.unit_number] = entity
	script.register_on_entity_destroyed(entity)
end

function UnregisterPump(uid)
	global.pumps[uid] = nil
	g_InputPositionCache[uid] = nil
end

function GetInputPosition(entity)
	if g_InputPositionCache[entity.unit_number] == nil then
		local offset = nil
		for i, connection in ipairs(entity.prototype.fluidbox_prototypes[1].pipe_connections) do
			if connection.type == 'input' then
				local dirIdx = entity.direction / 2 + 1
				offset = connection.positions[dirIdx]
				break
			end
		end

		local pos = entity.position
		pos = {(pos[1] or pos.x) + (offset[1] or offset.x), (pos[2] or pos.y) + (offset[2] or offset.y)}
		g_InputPositionCache[entity.unit_number] = pos
	end
	return g_InputPositionCache[entity.unit_number]
end

function ShouldEnablePump(pump)
	if pump.pump_rail_target == nil then
		return true
	end

	local pumpFbox = pump.fluidbox
	local pumpFilter = pumpFbox.get_filter(1)
	if pumpFilter == nil then
		return true
	end

	local inputPos = GetInputPosition(pump)
	local wagons = pump.pump_rail_target.surface.find_entities_filtered{area={inputPos, inputPos}, type='fluid-wagon'}
	-- normally there should be only 1 wagon
	for i, wagon in ipairs(wagons) do
		local wagonFluid = wagon.fluidbox[1]
		if wagonFluid ~= nil and wagonFluid.amount > 0 and wagonFluid.name ~= pumpFilter.name then
			return false
		end
	end

	return true
end

function VerifyPumps()
	for uid, pump in pairs(global.pumps) do
		if pump == nil or not pump.valid then
			global.pumps[uid] = nil
		else
			local enable = ShouldEnablePump(pump)
			if enable ~= pump.active then
				pump.active = enable
				game.print((enable and 'Enabling' or 'Disabling') .. ' pump ' .. uid)
			end
		end
	end
end

script.on_init(InitGlobal)
script.on_configuration_changed(InitGlobal)

script.on_nth_tick(PUMP_WAGON_CHECK_PERIOD, VerifyPumps)

local entityFilters = {{filter='name', name='filter-pump'}}
script.on_event(defines.events.on_built_entity, RegisterPump, entityFilters)
script.on_event(defines.events.on_robot_built_entity, RegisterPump, entityFilters)

script.on_event(defines.events.on_gui_opened, function(event)
	g_SelectedEntity = nil
	if event.gui_type ~= defines.gui_type.entity or event.entity == nil then
		return
	end
	if event.entity.prototype.name ~= 'filter-pump' then
		return
	end

	OpenFilterBox(event.player_index, event.entity)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	if g_SelectedEntity == nil or event.element.name ~= CHOOSE_BUTTON_NAME then
		return
	end

	SetFilter(event.player_index, event.element.elem_value)
end)

script.on_event(defines.events.on_entity_destroyed, function(event)
	if event.unit_number ~= nil then
		UnregisterPump(event.unit_number)
	end
end)

script.on_event(defines.events.on_player_rotated_entity, function(event)
	g_InputPositionCache[event.entity.unit_number] = nil
end)

--script.on_event(defines.events.on_entity_settings_pasted

-- debug stuff

function PrintPumps()
	game.player.print('=== Registered pumps ===')
	for uid, pump in pairs(global.pumps) do
		local filter = pump.fluidbox.get_filter(1)
		game.player.print('Pump ' .. uid .. ': ' .. (pump.active and 'enabled' or 'disabled') .. (filter and (' [' .. filter.name .. ']' or '')))
	end
	game.player.print('========== END =========')
end

function Clear()
	global.pumps = {}
	game.player.print('Pumps are cleared')
end

function Populate()
	global.pumps = {}
	for i, player in ipairs(game.connected_players) do
		if player ~= nil and player.surface ~= nil then
			local entities = player.surface.find_entities_filtered{area=nil, name='filter-pump'}
			for j, entity in ipairs(entities) do
				global.pumps[entity.unit_number] = entity
			end
		end
	end
end

commands.add_command('ff.print', nil, PrintPumps)
commands.add_command('ff.reset', nil, Clear)
commands.add_command('ff.populate', nil, Populate)
