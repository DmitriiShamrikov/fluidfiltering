local ENTITY_FRAME_NAME = 'ui-entity'
local FILTER_FRAME_NAME = 'ui-liquid-filter'
local CLOSE_BUTTON_NAME = 'ui-close'
local CIRCUIT_BUTTON_NAME = 'ui-circuit'
local LOGISTIC_BUTTON_NAME = 'ui-logistic'
local CHOOSE_FILTER_BUTTON_NAME = 'ui-liquid-filter-chooser'
local CHOOSE_CIRCUIT_SIGNAL_BUTTON_NAME = 'ui-circuit-signal-chooser'
local CHOOSE_LOGISTIC_SIGNAL_BUTTON_NAME = 'ui-logistic-signal-chooser'
local LOGISITIC_CONNECT_CHECKBOX_NAME = 'ui-logistic-connect'

local SIGNAL_FRAME_NAME = 'ui-signal'
local SEARCH_BUTTON_NAME = 'ui-search'

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

----------------------------------------
----- UI creation and interaction ------
----------------------------------------

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
		chooseButton = contentFrame.add{type='choose-elem-button', name=CHOOSE_FILTER_BUTTON_NAME, elem_type='fluid'}
	else
		chooseButton = panelFrame.children[1].children[1]
	end

	chooseButton.elem_value = filterFluid
end

function OpenEntityWindow(player, entity)
	local isPump = entity.type == 'pump'

	local elements = {}
	local entityFrame = player.gui.screen[ENTITY_FRAME_NAME]
	if entityFrame == nil then
		entityFrame = CreateEntityWindow(player, elements)
	else
		elements = FetchEntityWindowElements(entityFrame)
	end

	elements.title.caption = entity.localised_name
	elements.preview.entity = entity

	elements.circuitButton.visible = isPump and (IsCircuitNetworkUnlocked(player) or IsConnectedToCircuitNetwork(entity))
	elements.circuitButton.toggled = isPump and IsConnectedToCircuitNetwork(entity)

	elements.logisticButton.visible = isPump
	elements.logisticButton.toggled = isPump and not elements.circuitButton.toggled and IsConnectedToLogisticNetwork(entity)

	if entity.status == defines.entity_status.normal or entity.status == defines.entity_status.working or entity.status == nil then
		elements.statusSprite.sprite = 'utility/status_working'
	elseif entity.status == defines.entity_status.low_power then
		elements.statusSprite.sprite = 'utility/status_yellow'
	else
		elements.statusSprite.sprite = 'utility/status_not_working'
	end

	local statusName = nil
	for key, value in pairs(defines.entity_status) do
		if value == entity.status then
			statusName = key
			break
		end
	end
	elements.statusText.caption = {'entity-status.' .. (statusName and statusName:gsub('_', '-') or 'normal')}

	FillFilterButton(elements.chooseButton, entity)

	ToggleCircuitLogisiticBlocksVisibility(player, entity, elements)

	local redNetwork = entity.get_circuit_network(defines.wire_type.red)
	local greenNetwork = entity.get_circuit_network(defines.wire_type.green)
	elements.redNetworkId.visible = redNetwork ~= nil
	elements.greenNetworkId.visible = greenNetwork ~= nil

	-- TODO: can we actually make these fancy tooltips showing all signals in the network?

	if redNetwork then
		elements.redNetworkId.caption = {'', {'gui-control-behavior.connected-to-network'}, ': ', {'gui-control-behavior.red-network-id', redNetwork.network_id}}
		elements.redNetworkId.tooltip = {'', {'gui-control-behavior.circuit-network'}, ': ', redNetwork.network_id}
	end
	if greenNetwork then
		elements.greenNetworkId.caption = {'',{'gui-control-behavior.connected-to-network'}, ': ', {'gui-control-behavior.green-network-id', greenNetwork.network_id}}
		elements.greenNetworkId.tooltip = {'', {'gui-control-behavior.circuit-network'}, ': ', greenNetwork.network_id}
	end

	FillLogisticBlock(elements, entity)

	elements.chooseButton.locked = isPump and IsConnectedToCircuitNetwork(entity) and elements.circuitSetFilterRadio.state == true

	player.opened = entityFrame
end

function FillFilterButton(chooseButton, entity)
	local filter = nil
	if global.wagons[entity.unit_number] then
		filter = global.wagons[entity.unit_number][2]
	elseif global.pumps[entity.unit_number] and global.pumps[entity.unit_number][1] then
		local f = global.pumps[entity.unit_number][1].fluidbox.get_filter(1)
		if f then
			filter = f.name
		end
	end
	chooseButton.elem_value = filter
end

function FillLogisticBlock(elements, entity)
	local behavior = entity.get_control_behavior()
	local isConnected = behavior and behavior.connect_to_logistic_network
	if isConnected then
		if entity.logistic_network then
			elements.logisticConnectedLabel.caption = {'gui-control-behavior.connected-to-network'}
		else
			elements.logisticConnectedLabel.caption = {'gui-control-behavior.no-network-in-range'}
		end
	else
		elements.logisticConnectedLabel.caption = {'gui-control-behavior.not-connected'}
	end
	elements.logisticConnectCheckbox.state = isConnected
end

function ToggleCircuitLogisiticBlocksVisibility(player, entity, elements)
	local showCircuitNetwork = elements.circuitButton and elements.circuitButton.toggled
	local showLogisticNetwork = not showCircuitNetwork and elements.logisticButton and elements.logisticButton.toggled

	if showCircuitNetwork then
		elements.circuitFlow.visible = true
		elements.logisticFlow.visible = false

		if IsConnectedToCircuitNetwork(entity) then
			elements.circuitConnectionFlow.visible = false
			elements.circuitInnerFlow.visible = true
			elements.circuitEnableConditionFlow.visible = elements.circuitEnableDisableRadio.state
		else
			elements.circuitConnectionFlow.visible = true
			elements.circuitInnerFlow.visible = false
			elements.circuitEnableConditionFlow.visible = false
		end

	elseif showLogisticNetwork then
		elements.circuitFlow.visible = false
		elements.logisticFlow.visible = true

		local isConnected = IsConnectedToLogisticNetwork(entity)
		elements.logisticInnerFlow.visible = isConnected
		elements.logisitcEnableConditionFlow.visible = isConnected
	else
		elements.circuitFlow.visible = false
		elements.logisticFlow.visible = false
	end
end

function FetchEntityWindowElements(entityFrame)
	elements = {}
	elements.title = FindElementByName(entityFrame, 'title')
	elements.circuitButton = FindElementByName(entityFrame, CIRCUIT_BUTTON_NAME)
	elements.logisticButton = FindElementByName(entityFrame, LOGISTIC_BUTTON_NAME)
	elements.statusSprite = FindElementByName(entityFrame, 'statusSprite')
	elements.statusText = FindElementByName(entityFrame, 'statusText')
	elements.preview = FindElementByName(entityFrame, 'preview')
	elements.chooseButton = FindElementByName(entityFrame, CHOOSE_FILTER_BUTTON_NAME)
	elements.redNetworkId = FindElementByName(entityFrame, 'redNetworkId')
	elements.greenNetworkId = FindElementByName(entityFrame, 'greenNetworkId')

	elements.circuitFlow = FindElementByName(entityFrame, 'circuitFlow')
	elements.circuitConnectionFlow = FindElementByName(entityFrame, 'circuitConnectionFlow')
	elements.circuitInnerFlow = FindElementByName(entityFrame, 'circuitInnerFlow')
	elements.circuitEnableDisableRadio = FindElementByName(entityFrame, 'circuitEnableDisableRadio')
	elements.circuitSetFilterRadio = FindElementByName(entityFrame, 'circuitSetFilterRadio')
	elements.circuitEnableConditionFlow = FindElementByName(entityFrame, 'circuitEnableConditionFlow')

	elements.logisticFlow = FindElementByName(entityFrame, 'logisticFlow')
	elements.logisticConnectionFlow = FindElementByName(entityFrame, 'logisticConnectionFlow')
	elements.logisticConnectedLabel = FindElementByName(entityFrame, 'logisticConnectedLabel')
	elements.logisticConnectCheckbox = FindElementByName(entityFrame, LOGISITIC_CONNECT_CHECKBOX_NAME)
	elements.logisticInnerFlow = FindElementByName(entityFrame, 'logisticInnerFlow')
	elements.logisitcEnableConditionFlow = FindElementByName(entityFrame, 'logisitcEnableConditionFlow')
	return elements
end

function CreateEntityWindow(player, elements)
	local entityFrame = player.gui.screen.add{type='frame', name=ENTITY_FRAME_NAME}
	entityFrame.auto_center = true

	local mainFlow = entityFrame.add{type='flow', direction='vertical'}

	local titleFlow = mainFlow.add{type='flow', direction='horizontal'}
	titleFlow.drag_target = entityFrame
	titleFlow.style.horizontal_spacing = 8
	elements.title = titleFlow.add{type='label', ignored_by_interaction=true, style='frame_title', name='title'}
	titleFlow.add{type='empty-widget', ignored_by_interaction=true, style='header_filler_style'}

	elements.circuitButton = titleFlow.add{
		type='sprite-button',
		name=CIRCUIT_BUTTON_NAME,
		style='frame_action_button',
		tooltip={'gui-control-behavior.circuit-network'},
		sprite='utility/circuit_network_panel_white',
		hovered_sprite='utility/circuit_network_panel_black',
		clicked_sprite='utility/circuit_network_panel_black',
		auto_toggle=true
	}

	elements.logisticButton = titleFlow.add{
		type='sprite-button',
		name=LOGISTIC_BUTTON_NAME,
		style='frame_action_button',
		tooltip={'gui-control-behavior.logistic-network'},
		sprite='utility/logistic_network_panel_white',
		hovered_sprite='utility/logistic_network_panel_black',
		clicked_sprite='utility/logistic_network_panel_black',
		auto_toggle=true
	}

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
	elements.statusSprite = statusFlow.add{type='sprite', name='statusSprite'}
	elements.statusText = statusFlow.add{type='label', name='statusText'}

	local previewContainer = contentFlow.add{type='frame', style='slot_container_frame'}
	previewContainer.style.bottom_margin = 4
	elements.preview = previewContainer.add{type='entity-preview', style='wide_entity_button', name='preview'}

	local columnsFlow = contentFlow.add{type='flow', direction='horizontal'}
	columnsFlow.style.top_margin = 4

	local leftColumnFlow = columnsFlow.add{type='flow', direction='vertical', style='left_column'}
	CreateCircuitConditionBlock(leftColumnFlow, elements)
	CreateLogisticConditionBlock(leftColumnFlow, elements)

	local rightColumnFlow = columnsFlow.add{type='flow', direction='vertical', style='right_column'}
	rightColumnFlow.add{type='label', caption='Filter:', style='bold_label'}
	elements.chooseButton = rightColumnFlow.add{type='choose-elem-button', name=CHOOSE_FILTER_BUTTON_NAME, elem_type='fluid'}

	return entityFrame
end

function CreateCircuitConditionBlock(root, elements)
	local circuitFlow = root.add{type='flow', direction='vertical', name='circuitFlow'}
	connectionFlow = circuitFlow.add{type='flow', direction='vertical', name='circuitConnectionFlow'}
	connectionFlow.add{type='label', caption={'gui-control-behavior.not-connected'}}

	local innerFlow = circuitFlow.add{type='flow', direction='vertical', name='circuitInnerFlow'}
	elements.redNetworkId = innerFlow.add{type='label', name='redNetworkId'}
	elements.greenNetworkId = innerFlow.add{type='label', name='greenNetworkId'}
	innerFlow.add{type='line', direction='horizontal'}
	innerFlow.add{type='label', caption={'gui-control-behavior.mode-of-operation'}, style='caption_label'}
	innerFlow.add{type='radiobutton', caption={'gui-control-behavior-modes.none'}, tooltip={'gui-control-behavior-modes.none-write-description'}, state=true}
	local enDisRadio = innerFlow.add{type='radiobutton', caption={'gui-control-behavior-modes.enable-disable'}, tooltip={'gui-control-behavior-modes.enable-disable-description'}, state=false, name='circuitEnableDisableRadio'}
	local setFilterRadio = innerFlow.add{type='radiobutton', caption={'gui-control-behavior-modes.set-filters'}, tooltip={'gui-control-behavior-modes.set-filters-description'}, state=false, name='circuitSetFilterRadio'}
	--innerFlow.add{type='checkbox', caption={'gui-control-behavior-modes.read-contents'}, tooltip={'gui-control-behavior-modes.read-contents-description'}, state=false}
	
	elements.circuitFlow = circuitFlow
	elements.circuitConnectionFlow = connectionFlow
	elements.circuitInnerFlow = innerFlow
	elements.circuitEnableDisableRadio = enDisRadio
	elements.circuitSetFilterRadio = setFilterRadio
	CreateEnabledDisabledBlock(circuitFlow, elements, true)
end

function CreateLogisticConditionBlock(root, elements)
	local logisticFlow = root.add{type='flow', direction='vertical', name='logisticFlow'}
	local connectionFlow = logisticFlow.add{type='flow', direction='vertical', name='logisticConnectionFlow'}
	local connectedLabel = connectionFlow.add{type='label', caption={'gui-control-behavior.not-connected'}, name='logisticConnectedLabel'}
	local connectChbx = connectionFlow.add{type='checkbox', caption={'gui-control-behavior.connect'}, state=false, name=LOGISITIC_CONNECT_CHECKBOX_NAME}

	local innerFlow = logisticFlow.add{type='flow', direction='vertical', name='logisticInnerFlow'}
	innerFlow.add{type='line', direction='horizontal'}
	innerFlow.add{type='label', caption={'gui-control-behavior.mode-of-operation'}, style='caption_label'}
	innerFlow.add{type='radiobutton', caption={'gui-control-behavior-modes.enable-disable'}, tooltip={'gui-control-behavior-modes.enable-disable-description'}, state=true}

	elements.logisticFlow = logisticFlow
	elements.logisticConnectionFlow = connectionFlow
	elements.logisticConnectedLabel = connectedLabel
	elements.logisticConnectCheckbox = connectChbx
	elements.logisticInnerFlow = innerFlow
	CreateEnabledDisabledBlock(logisticFlow, elements, false)
end

function CreateEnabledDisabledBlock(root, elements, isCircuit)
	local flowName = isCircuit and 'circuitEnableConditionFlow' or 'logisitcEnableConditionFlow'
	local conditionFlow = root.add{type='flow', direction='vertical', name=flowName}
	conditionFlow.add{type='line', direction='horizontal'}
	conditionFlow.add{type='label', caption={'gui-control-behavior-modes-guis.enabled-condition'}, style='caption_label'}
	local conditionSelectorFlow = conditionFlow.add{type='flow', direction='horizontal'}
	conditionSelectorFlow.style.vertical_align = 'center'
	conditionSelectorFlow.add{type='choose-elem-button', elem_type='signal'}
	conditionSelectorFlow.add{type='drop-down', items={'>', '<', '=', '≥', '≤', '≠'}, selected_index=2, style='circuit_condition_comparator_dropdown'}
	local chooserName = isCircuit and CHOOSE_CIRCUIT_SIGNAL_BUTTON_NAME or CHOOSE_LOGISTIC_SIGNAL_BUTTON_NAME
	local rightChooser = conditionSelectorFlow.add{type='choose-elem-button', elem_type='signal', name=chooserName}
	rightChooser.locked = true -- don't open default chooser window, we create our own

	if isCircuit then
		elements.circuitEnableConditionFlow = conditionFlow
	else
		elements.logisitcEnableConditionFlow = conditionFlow
	end
end

function OpenSignalChooseWindow(player)
	-- okay, it looks like we will fail to mimic original UI completely and it would be noticable and ugly
	-- plus I personally don't think the original UI is the best UI
	-- so: copy the idea, have our reasonable implementation

	local elements = {}
	local signalFrame = player.gui.screen[SIGNAL_FRAME_NAME]
	if signalFrame == nil then
		CreateSignalChooseWindow(player, elements)
	else

	end
end

function CreateSignalChooseWindow(player, elements)
	local signalFrame = player.gui.screen.add{type='frame', name=SIGNAL_FRAME_NAME}
	signalFrame.auto_center = true

	local titleFlow = signalFrame.add{type='flow', direction='horizontal'}
	titleFlow.drag_target = signalFrame
	titleFlow.style.horizontal_spacing = 8
	titleFlow.add{type='label', caption={'gui.select-signal'}, ignored_by_interaction=true, style='frame_title'}
	titleFlow.add{type='empty-widget', ignored_by_interaction=true, style='header_filler_style'}
	
	titleFlow.add{
		type='sprite-button',
		name=SEARCH_BUTTON_NAME,
		style='frame_action_button',
		tooltip={'gui.search-with-focus', '__CONTROL__focus-search__'},
		sprite='utility/search_white',
		hovered_sprite='utility/search_black',
		clicked_sprite='utility/search_black',
		auto_toggle=true
	}

	titleFlow.add{
		type='sprite-button',
		name=CLOSE_BUTTON_NAME,
		style='close_button',
		sprite='utility/close_white',
		hovered_sprite='utility/close_black',
		clicked_sprite='utility/close_black',
	}
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

function OnApplyCircuitFilterChanged(playerIndex, entity)
	local player = game.get_player(playerIndex)
	if player ~= nil then
		local entityFrame = player.gui.screen[ENTITY_FRAME_NAME]
		local chooseButton = FindElementByName(entityFrame, CHOOSE_FILTER_BUTTON_NAME)
		FillFilterButton(chooseButton, entity)
		-- chooseButton.locked = <true if the 'set filter' is chosen>
	end
end

---------------------------------------
----- Apply changes to the entity -----
---------------------------------------

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

function ConnectToLogisiticNetwork(playerIndex, connect)
	if g_SelectedEntity.type == 'pump' then
		local behavior = g_SelectedEntity.get_control_behavior()
		if not behavior then
			if not connect then
				return
			end
			behavior = g_SelectedEntity.get_or_create_control_behavior()
		end
		behavior.connect_to_logistic_network = connect
	end
end

function SetFilterControlledByCircuit(playerIndex, set)
	if g_SelectedEntity.type ~= 'pump' then
		return
	end

	global.pumps[g_SelectedEntity.unit_number][2] = set

	local player = game.get_player(playerIndex)
	if player ~= nil then
		player.print('Entity ' .. g_SelectedEntity.unit_number .. (set and ' will' or 'will not') .. ' get its filter from circuit network')
	end
end

----------------------------------
-------- Event callbacks ---------
----------------------------------

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
	if g_SelectedEntity ~= nil and event.element.name == CHOOSE_FILTER_BUTTON_NAME then
		SetFilter(event.player_index, event.element.elem_value)
	end
end)

script.on_event(defines.events.on_gui_click, function(event)
	if event.element.name == CLOSE_BUTTON_NAME then
		CloseEntityWindow(event.element)
		g_SelectedEntity = nil
	elseif event.element.name == CIRCUIT_BUTTON_NAME or event.element.name == LOGISTIC_BUTTON_NAME then
		local player = game.get_player(event.player_index)
		if player == nil then
			return
		end

		local elements = FetchEntityWindowElements(player.gui.screen[ENTITY_FRAME_NAME])
		if event.element.toggled then
			if event.element.name == CIRCUIT_BUTTON_NAME then
				elements.logisticButton.toggled = false
			else
				elements.circuitButton.toggled = false
			end
		end
		ToggleCircuitLogisiticBlocksVisibility(player, g_SelectedEntity, elements)
	elseif event.element.name == LOGISITIC_CONNECT_CHECKBOX_NAME then
		local player = game.get_player(event.player_index)
		if player == nil then
			return
		end

		local elements = FetchEntityWindowElements(player.gui.screen[ENTITY_FRAME_NAME])
		ConnectToLogisiticNetwork(event.player_index, event.element.state)
		FillLogisticBlock(elements, g_SelectedEntity)
		ToggleCircuitLogisiticBlocksVisibility(player, g_SelectedEntity, elements)
	elseif event.element.name == CHOOSE_SIGNAL_BUTTON_NAME then
		local player = game.get_player(event.player_index)
		if player == nil then
			return
		end
		if event.button == defines.mouse_button_type.right then
			event.element.elem_value = nil
		else
			CreateSignalChooseWindow(player)
		end	
	end
end)

script.on_event(defines.events.on_gui_closed, function(event)
	if event.element and event.element.name == ENTITY_FRAME_NAME then
		event.element.destroy()
		g_SelectedEntity = nil
	end
end)