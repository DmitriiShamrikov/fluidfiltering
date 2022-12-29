local g_SelectedEntity = nil

function InitGlobal()
	if global.filters == nil then
		global.filters = {}
	end
end

function OpenFilterBox(event)
	g_SelectedEntity = nil

	if event.gui_type ~= defines.gui_type.entity or event.entity == nil then
		return
	end

	if event.entity.prototype.name ~= 'filter-pump' then
		return
	end

	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	local frameName = 'liquid-filter-ui'
	local chooseButtonName = 'chooser'
	local filterFrame = player.gui.relative[frameName]
	if filterFrame == nil then
		local anchor = {
			gui = defines.relative_gui_type.entity_with_energy_source_gui,
			position = defines.relative_gui_position.bottom,
			name = 'filter-pump'
		}
		filterFrame = player.gui.relative.add{type='frame', name=frameName, caption='Filter', anchor=anchor}
		filterFrame.add{type='choose-elem-button', name=chooseButtonName, elem_type='fluid'}
	end

	filterFrame[chooseButtonName].elem_value = global.filters[event.entity.unit_number]
	g_SelectedEntity = event.entity
end

function SetFilter(event)
	if g_SelectedEntity == nil or event.element == nil then
		return
	end

	global.filters[g_SelectedEntity.unit_number] = event.element.elem_value

	-- unfortunately there is no way to 'unregister' the entity
	if event.element.elem_value ~= nil then
		script.register_on_entity_destroyed(g_SelectedEntity)
	end

	local player = game.get_player(event.player_index)
	if player ~= nil then
		player.print('Setting filter for the entity ' .. g_SelectedEntity.unit_number .. ': ' .. (event.element.elem_value or 'none'))
	end
end

function CleanupFilter(event)
	if event.unit_number == nil then
		return
	end

	global.filters[event.unit_number] = nil
end

script.on_init(InitGlobal)
script.on_configuration_changed(InitGlobal)
script.on_event(defines.events.on_gui_opened, OpenFilterBox)
script.on_event(defines.events.on_gui_elem_changed, SetFilter)
script.on_event(defines.events.on_entity_destroyed, CleanupFilter)

-- debug stuff

function PrintFilters(cmd)
	game.player.print(serpent.block(global.filters))
end

function Reset(cmd)
	global.filters = {}
	game.player.print('filters are reset')
end

commands.add_command('ff.print', nil, PrintFilters)
commands.add_command('ff.reset', nil, Reset)
