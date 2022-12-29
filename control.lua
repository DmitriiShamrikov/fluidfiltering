function OpenFilterBox(event)
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

	local name = 'liquid-filter-ui'
	local filterFrame = nil
	for key, child in pairs(player.gui.relative.children) do
		if child.name == name then
			filterFrame = child
			break
		end
	end

	if filterFrame == nil then
		local anchor = {
			gui = defines.relative_gui_type.entity_with_energy_source_gui,
			position = defines.relative_gui_position.bottom,
			name = 'filter-pump'
		}
		filterFrame = player.gui.relative.add{type='frame', name=name, anchor=anchor}
		filterFrame.add{type='label', caption=player.name}
	end
end

script.on_event(defines.events.on_gui_opened, OpenFilterBox)
