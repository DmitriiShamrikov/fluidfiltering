local g_SelectedEntity = nil

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

	local filter = event.entity.fluidbox.get_filter(1)
	filterFrame[chooseButtonName].elem_value = filter and filter.name or nil

	g_SelectedEntity = event.entity
end

function SetFilter(event)
	if g_SelectedEntity == nil or event.element == nil then
		return
	end

	if event.element.elem_value == nil then
		g_SelectedEntity.fluidbox.set_filter(1, nil)
	else
		g_SelectedEntity.fluidbox.set_filter(1, {name=event.element.elem_value, force=true})
	end

	local player = game.get_player(event.player_index)
	if player ~= nil then
		player.print('Setting filter for the entity ' .. g_SelectedEntity.unit_number .. ': ' .. (event.element.elem_value or 'none'))
	end
end

script.on_event(defines.events.on_gui_opened, OpenFilterBox)
script.on_event(defines.events.on_gui_elem_changed, SetFilter)