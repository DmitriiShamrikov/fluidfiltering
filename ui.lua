local ENTITY_FRAME_NAME = 'ui-entity'
local FILTER_FRAME_NAME = 'ui-liquid-filter'
local CHOOSE_BUTTON_NAME = 'ui-liquid-filter-chooser'
local CLOSE_BUTTON_NAME = 'ui-close'
local CIRCUIT_BUTTON_NAME = 'ui-circuit'
local LOGISTIC_BUTTON_NAME = 'ui-logistic'

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

function FindElementByName(root, name)
	if root.name == name then
		return root
	end

	for _, element in ipairs(root.children) do
		local result = FindElementByName(element, name)
		if result then
			return result
		end
	end

	return nil
end

function OnGuiOpened(event)
	g_SelectedEntity = nil
	if event.gui_type ~= defines.gui_type.entity or event.entity == nil then
		return
	end

	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	local isPump = event.entity.name == 'filter-pump'
	local isWagon = event.entity.name == 'filter-fluid-wagon'
	local hasMainlUI = event.name == defines.events.on_gui_opened
	if isPump or isWagon then
		if isWagon and hasMainlUI then
			OpenFluidFilterPanel(player, event.entity)
		else
			OpenEntityWindow(player, event.entity)
		end

		g_SelectedEntity = event.entity
	end
end

function OpenEntityWindow(player, entity)
	local isPump = entity.type == 'pump'

	local entityFrame = player.gui.screen[ENTITY_FRAME_NAME]
	local title = nil
	local preview = nil
	local chooseButton = nil
	local statusSprite = nil
	local statusText = nil
	
	local circuitButton = nil
	local redNetworkId = nil
	local greenNetworkId = nil

	local logisticButton = nil
	if entityFrame == nil then
		entityFrame = player.gui.screen.add{type='frame', name=ENTITY_FRAME_NAME}
		entityFrame.auto_center = true

		local mainFlow = entityFrame.add{type='flow', direction='vertical'}

		local titleFlow = mainFlow.add{type='flow', direction='horizontal'}
		titleFlow.drag_target = entityFrame
		titleFlow.style.horizontal_spacing = 12
		title = titleFlow.add{type='label', ignored_by_interaction=true, style='frame_title', name='title'}
		titleFlow.add{type='empty-widget', ignored_by_interaction=true, style='header_filler_style'}
		if isPump and (IsCircuitNetworkUnlocked(player) or IsConnectedToCircuitNetwork(entity)) then
			circuitButton = titleFlow.add{
				type='sprite-button',
				name=CIRCUIT_BUTTON_NAME,
				style='frame_action_button',
				tooltip={'gui-control-behavior.circuit-network'},
				sprite='utility/circuit_network_panel_white',
				hovered_sprite='utility/circuit_network_panel_black',
				clicked_sprite='utility/circuit_network_panel_black',
				auto_toggle=true
			}
			circuitButton.style.right_margin = -4
		end
		if isPump and IsLogisticNetworkUnlocked(player) then
			logisticButton = titleFlow.add{
				type='sprite-button',
				name=LOGISTIC_BUTTON_NAME,
				style='frame_action_button',
				tooltip={'gui-control-behavior.logistic-network'},
				sprite='utility/logistic_network_panel_white',
				hovered_sprite='utility/logistic_network_panel_black',
				clicked_sprite='utility/logistic_network_panel_black',
				auto_toggle=true
			}
			logisticButton.style.right_margin = -4
		end

		titleFlow.add{
			type='sprite-button',
			name=CLOSE_BUTTON_NAME,
			style='close_button',
			sprite='utility/close_white',
			hovered_sprite='utility/close_black',
			clicked_sprite='utility/close_black',
		}

		local contentFrame = mainFlow.add{type='frame', style='inside_shallow_frame_with_padding'}
		local contentFlow = contentFrame.add{type='flow', direction='vertical'}

		local statusFlow = contentFlow.add{type='flow', direction='horizontal'}
		statusFlow.style.vertical_align = 'center'
		statusFlow.style.top_margin = -4
		statusFlow.style.bottom_margin = 4
		statusSprite = statusFlow.add{type='sprite', name='statusSprite'}
		statusText = statusFlow.add{type='label', name='statusText'}

		local previewContainer = contentFlow.add{type='frame', style='slot_container_frame'}
		previewContainer.style.bottom_margin = 4
		preview = previewContainer.add{type='entity-preview', style='wide_entity_button', name='preview'}

		local columnsFlow = contentFlow.add{type='flow', direction='horizontal'}
		columnsFlow.style.top_margin = 4

		local leftColumnFlow = columnsFlow.add{type='flow', direction='vertical', style='left_column'}
		
		local circuitFlow = leftColumnFlow.add{type='flow', direction='vertical', name='circuitFlow'}
		local connectionFlow = circuitFlow.add{type='flow', direction='vertical', name='connectionFlow'}
		connectionFlow.add{type='label', caption={'gui-control-behavior.not-connected'}}

		local circuitInnerFlow = circuitFlow.add{type='flow', direction='vertical', name='circuitInnerFlow'}
		redNetworkId = circuitInnerFlow.add{type='label', name='redNetworkId'}
		greenNetworkId = circuitInnerFlow.add{type='label', name='greenNetworkId'}
		circuitInnerFlow.add{type='line', direction='horizontal'}
		circuitInnerFlow.add{type='label', caption={'gui-control-behavior.mode-of-operation'}, style='caption_label'}
		circuitInnerFlow.add{type='radiobutton', caption={'gui-control-behavior-modes.none'}, tooltip={'gui-control-behavior-modes.none-write-description'}, state=true}
		circuitInnerFlow.add{type='radiobutton', caption={'gui-control-behavior-modes.enable-disable'}, tooltip={'gui-control-behavior-modes.enable-disable-description'}, state=false}
		circuitInnerFlow.add{type='radiobutton', caption={'gui-control-behavior-modes.set-filters'}, tooltip={'gui-control-behavior-modes.set-filters-description'}, state=false}
		circuitInnerFlow.add{type='checkbox', caption={'gui-control-behavior-modes.read-contents'}, tooltip={'gui-control-behavior-modes.read-contents-description'}, state=false}
		
		local conditionFlow = circuitInnerFlow.add{type='flow', direction='vertical', name='conditionFlow'}
		conditionFlow.add{type='line', direction='horizontal'}
		conditionFlow.add{type='label', caption={'gui-control-behavior-modes-guis.enabled-condition'}, style='caption_label'}
		local conditionSelectorFlow = conditionFlow.add{type='flow', direction='horizontal'}
		conditionSelectorFlow.style.vertical_align = 'center'
		conditionSelectorFlow.add{type='choose-elem-button', elem_type='signal'}
		conditionSelectorFlow.add{type='drop-down', items={'>', '<', '=', '≥', '≤', '≠'}, selected_index=2, style='circuit_condition_comparator_dropdown'}
		conditionSelectorFlow.add{type='choose-elem-button', elem_type='signal'} -- FUCK


		local logisticFlow = leftColumnFlow.add{type='flow', direction='vertical', name='logisticFlow'}
		connectionFlow = logisticFlow.add{type='flow', direction='vertical', name='connectionFlow'}
		connectionFlow.add{type='label', caption={'gui-control-behavior.not-connected'}}
		connectionFlow.add{type='checkbox', caption={'gui-control-behavior.connect'}, state=false}

		local filterFlow = columnsFlow.add{type='flow', direction='vertical', style='right_column'}
		filterFlow.add{type='label', caption='Filter:', style='bold_label'}
		chooseButton = filterFlow.add{type='choose-elem-button', name=CHOOSE_BUTTON_NAME, elem_type='fluid'}
	else
		title = FindElementByName(entityFrame, 'title')
		circuitButton = FindElementByName(entityFrame, CIRCUIT_BUTTON_NAME)
		logisticButton = FindElementByName(entityFrame, LOGISTIC_BUTTON_NAME)
		statusSprite = FindElementByName(entityFrame, 'statusSprite')
		statusText = FindElementByName(entityFrame, 'statusText')
		preview = FindElementByName(entityFrame, 'preview')
		chooseButton = FindElementByName(entityFrame, CHOOSE_BUTTON_NAME)
		redNetworkId = FindElementByName(entityFrame, 'redNetworkId')
		greenNetworkId = FindElementByName(entityFrame, 'greenNetworkId')
	end

	title.caption = entity.localised_name
	preview.entity = entity

	if circuitButton then
		circuitButton.visible = isPump
		circuitButton.toggled = isPump and IsConnectedToCircuitNetwork(entity)
	end

	if logisticButton then
		logisticButton.visible = isPump
		logisticButton.toggled = isPump and (not circuitButton or not circuitButton.toggled) and IsConnectedToLogisticNetwork(entity)
	end

	if entity.status == defines.entity_status.normal or entity.status == defines.entity_status.working or entity.status == nil then
		statusSprite.sprite = 'utility/status_working'
	elseif entity.status == defines.entity_status.low_power then
		statusSprite.sprite = 'utility/status_yellow'
	else
		statusSprite.sprite = 'utility/status_not_working'
	end

	local statusName = nil
	for key, value in pairs(defines.entity_status) do
		if value == entity.status then
			statusName = key
			break
		end
	end
	statusText.caption = {'entity-status.' .. (statusName and statusName:gsub('_', '-') or 'normal')}

	local filter = nil
	if global.wagons[entity.unit_number] then
		filter = global.wagons[entity.unit_number][2]
	elseif global.pumps[entity.unit_number] then
		local f = global.pumps[entity.unit_number].fluidbox.get_filter(1)
		if f then
			filter = f.name
		end
	end
	chooseButton.elem_value = filter

	if ToggleCircuitNetworkBlock(player, entity, circuitButton) then
		local redNetwork = entity.get_circuit_network(defines.wire_type.red)
		local greenNetwork = entity.get_circuit_network(defines.wire_type.green)
		redNetworkId.visible = redNetwork ~= nil
		greenNetworkId.visible = greenNetwork ~= nil
		
		if redNetwork then
			redNetworkId.caption = {'', {'gui-control-behavior.connected-to-network'}, ': ', {'gui-control-behavior.red-network-id', redNetwork.network_id}}
			redNetworkId.tooltip = {'', {'gui-control-behavior.circuit-network'}, ': ', redNetwork.network_id}
		end
		if greenNetwork then
			greenNetworkId.caption = {'',{'gui-control-behavior.connected-to-network'}, ': ', {'gui-control-behavior.green-network-id', greenNetwork.network_id}}
			greenNetworkId.tooltip = {'', {'gui-control-behavior.circuit-network'}, ': ', greenNetwork.network_id}
		end
	elseif ToggleLogisticNetworkBlock(player, entity, logisticButton) then

	end

	player.opened = entityFrame
end

function OpenFluidFilterPanel(player, entity)
	local guiType = nil
	local filterFluid = nil
	if entity.type == 'pump' then
		local filter = entity.fluidbox.get_filter(1)
		filterFluid = filter and filter.name or nil
		guiType = defines.relative_gui_type.entity_with_energy_source_gui
	elseif entity.type == 'fluid-wagon' then
		local filter = global.wagons[entity.unit_number]
		filterFluid = filter and filter[2] or nil
		if entity.prototype.grid_prototype ~= nil then
			guiType = defines.relative_gui_type.equipment_grid_gui
		else
			guiType = defines.relative_gui_type.additional_entity_info_gui -- for editor only
		end
	else
		return
	end

	local frameName = FILTER_FRAME_NAME .. '-' .. guiType
	local panelFrame = player.gui.relative[frameName]
	local chooseButton = nil
	if panelFrame == nil then
		local anchor = {
			gui = guiType,
			position = defines.relative_gui_position.bottom,
			names = {'filter-pump', 'filter-fluid-wagon'}
		}
		panelFrame = player.gui.relative.add{type='frame', name=frameName, caption='Filter', anchor=anchor}
		local contentFrame = panelFrame.add{type='frame', style='inside_shallow_frame_with_padding'}
		chooseButton = contentFrame.add{type='choose-elem-button', name=CHOOSE_BUTTON_NAME, elem_type='fluid'}
	else
		chooseButton = panelFrame.children[1].children[1]
	end

	chooseButton.elem_value = filterFluid
end

function ToggleCircuitNetworkBlock(player, entity, circuitButton)
	local isPump = entity.type == 'pump'

	local entityFrame = player.gui.screen[ENTITY_FRAME_NAME]
	local circuitFlow = FindElementByName(entityFrame, 'circuitFlow')
	
	if circuitButton then
		circuitButton.sprite = circuitButton.toggled and 'utility/circuit_network_panel_black' or 'utility/circuit_network_panel_white'
	end

	local shouldShowCircuitBlock = false
	if isPump and circuitButton and circuitButton.toggled then
		circuitFlow.visible = true
		local connectionFlow = FindElementByName(circuitFlow, 'connectionFlow')
		local circuitInnerFlow = FindElementByName(circuitFlow, 'circuitInnerFlow')
		if IsConnectedToCircuitNetwork(entity) then
			connectionFlow.visible = false
			circuitInnerFlow.visible = true
			shouldShowCircuitBlock = true
		else
			connectionFlow.visible = true
			circuitInnerFlow.visible = false
		end
	else
		circuitFlow.visible = false
	end

	if circuitFlow.visible then
		local logisticButton = FindElementByName(entityFrame, LOGISTIC_BUTTON_NAME)
		local logisticFlow = FindElementByName(entityFrame, 'logisticFlow')
		
		if logisticButton then
			logisticButton.toggled = false
			logisticButton.sprite = 'utility/logistic_network_panel_white'
		end

		logisticFlow.visible = false
	end

	return shouldShowCircuitBlock
end

function ToggleLogisticNetworkBlock(player, entity, logisticButton)
	local isPump = entity.type == 'pump'

	local entityFrame = player.gui.screen[ENTITY_FRAME_NAME]
	local logisticFlow = FindElementByName(entityFrame, 'logisticFlow')

	if logisticButton then
		logisticButton.sprite = logisticButton.toggled and 'utility/logistic_network_panel_black' or 'utility/logistic_network_panel_white'
	end

	local shouldShowLogisticBlock = false
	if isPump and logisticButton and logisticButton.toggled then
		logisticFlow.visible = true
		local connectionFlow = FindElementByName(logisticFlow, 'connectionFlow')
		--local logisticInnerFlow = FindElementByName(logisticFlow, 'logisticInnerFlow')
		if IsConnectedToLogisticNetwork(entity) then
			connectionFlow.visible = false
			--logisticInnerFlow.visible = true
			shouldShowLogisticBlock = true
		else
			connectionFlow.visible = true
			--logisticInnerFlow.visible = false
		end
	else
		logisticFlow.visible = false
	end

	if logisticFlow.visible then
		local circuitButton = FindElementByName(entityFrame, CIRCUIT_BUTTON_NAME)
		local circuitFlow = FindElementByName(entityFrame, 'circuitFlow')
		
		if circuitButton then
			circuitButton.toggled = false
			circuitButton.sprite = 'utility/circuit_network_panel_white'
		end

		circuitFlow.visible = false
	end

	return shouldShowLogisticBlock
end

function CloseEntityWindow(element)
	while element ~= nil do
		if element.name == ENTITY_FRAME_NAME then
			element.destroy()
			break
		end
		element = element.parent
	end
end

function SetFilter(playerIndex, fluid)
	if g_SelectedEntity.type == 'pump' then
		if fluid == nil then
			g_SelectedEntity.fluidbox.set_filter(1, nil)
		else
			g_SelectedEntity.fluidbox.set_filter(1, {name=fluid, force=true})
		end
	else -- fluid-wagon
		if fluid == nil then
			global.wagons[g_SelectedEntity.unit_number] = nil
		else
			global.wagons[g_SelectedEntity.unit_number] = {g_SelectedEntity, fluid}
			script.register_on_entity_destroyed(g_SelectedEntity)
		end
	end

	local player = game.get_player(playerIndex)
	if player ~= nil then
		player.print('Setting filter for entity ' .. g_SelectedEntity.unit_number .. ': ' .. (fluid or 'none'))
	end
end


script.on_event(defines.events.on_gui_opened, OnGuiOpened)
script.on_event('open_gui', function(event)
	local player = game.get_player(event.player_index)
	if player == nil or player.selected == nil or player.selected == g_SelectedEntity then
		return
	end

	event.gui_type = defines.gui_type.entity
	event.entity = player.selected
	OnGuiOpened(event)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	if g_SelectedEntity ~= nil and event.element.name == CHOOSE_BUTTON_NAME then
		SetFilter(event.player_index, event.element.elem_value)
	end
end)

script.on_event(defines.events.on_gui_click, function(event)
	if event.element.name == CLOSE_BUTTON_NAME then
		CloseEntityWindow(event.element)
		g_SelectedEntity = nil
	elseif event.element.name == CIRCUIT_BUTTON_NAME then
		local player = game.get_player(event.player_index)
		if player == nil then
			return
		end
		ToggleCircuitNetworkBlock(player, g_SelectedEntity, event.element)
	elseif event.element.name == LOGISTIC_BUTTON_NAME then
		local player = game.get_player(event.player_index)
		if player == nil then
			return
		end
		ToggleLogisticNetworkBlock(player, g_SelectedEntity, event.element)
	end
end)

script.on_event(defines.events.on_gui_closed, function(event)
	if event.element and event.element.name == ENTITY_FRAME_NAME then
		event.element.destroy()
		g_SelectedEntity = nil
	end
end)