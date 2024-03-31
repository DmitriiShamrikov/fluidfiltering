require('constants')

ON_ENTITY_STATE_CHANGED = script.generate_event_name()
ON_ENTITY_DESTROYED_CUSTOM = script.generate_event_name()

local g_LocalizedSignalNames = {} -- {player-index => {localised-id => localized-name}}
local g_LocalizationRequests = {}

function SliderValueToConstantValue(svalue)
	local order = math.floor(svalue / 10)
	local value = svalue % 10 + order
	order = order + math.floor(value / 10)
	value = value % 10 + math.floor(value / 10)
	return value * 10^order
end

function ConstantValueToSliderValue(cvalue)
	local firstChar = cvalue:sub(1,1)
	if firstChar == '' or firstChar == '-' then
		return 0
	end
	local order = cvalue:len() - 1
	local value = tonumber(firstChar)
	return value + 9 * order
end

function GetShortStringValue(value)
	local SIGNAL_VALUE_MIN = -2^31
	local SIGNAL_VALUE_MAX = 2^31 - 1
	value = math.max(SIGNAL_VALUE_MIN, math.min(SIGNAL_VALUE_MAX, value))

	local result = ''
	if value < 0 then
		value = -value
		result = result .. '-'
	end

	if value < 1000 then
		result = result .. tostring(value)
	elseif value < 10000 then
		local v = tostring(value/1000):sub(1,3)
		if v:len() == 1 then
			v = v .. '.0'
		end
		result = result .. v .. 'k'
	elseif value < 1000000 then
		result = result .. tostring(math.floor(value/1000)) .. 'k'
	elseif value < 10000000 then
		local v = tostring(value/1000000):sub(1,3)
		if v:len() == 1 then
			v = v .. '.0'
		end
		result = result .. v .. 'M'
	elseif value < 1000000000 then
		result = result .. tostring(math.floor(value/1000000)) .. 'M'
	else
		local v = tostring(value/1000000000):sub(1,3)
		if v:len() == 1 then
			v = v .. '.0'
		end
		result = result .. v .. 'G'
	end

	return result
end

function IndexOf(array, value)
	for k, v in pairs(array) do
		if v == value then
			return k
		end
	end
	return nil
end

function RemoveValue(array, value)
	local idx = IndexOf(array, value)
	if idx then
		table.remove(array, idx)
	end
end

function GetSignalLocalizedString(signal)
	local proto = nil
	if signal.type == 'item' then
		proto = game.item_prototypes[signal.name]
	elseif signal.type == 'fluid' then
		proto = game.fluid_prototypes[signal.name]
	else
		proto = game.virtual_signal_prototypes[signal.name]
	end
	return proto.localised_name
end

function GetSpritePath(signal)
	if signal and signal.type and signal.name then
		return (signal.type == 'virtual' and 'virtual-signal' or signal.type) .. '/' .. signal.name
	else
		return nil
	end
end

----------------------------------------
----- UI creation and interaction ------
----------------------------------------

function IfGuiOpened(fn)
	return function(event)
		if global.guiState[event.player_index] == nil then
			return
		end
		local player = game.get_player(event.player_index)
		fn(player, event)
	end
end

function ForAllPlayersOpenedEntity(fn)
	return function(event)
		local id = event.unit_number or event.entity.unit_number
		if global.openedEntities[id] then
			local players = global.openedEntities[id].players
			for _, playerIdx in pairs(players) do
				local player = game.get_player(playerIdx)
				fn(player, event)
			end
		end
	end
end

function OnGuiOpened(event)
	if event.gui_type == defines.gui_type.item and event.item and event.item.valid_for_read and event.item.is_blueprint_setup() then
		global.guiState[event.player_index] = global.guiState[event.player_index] or {}
		global.guiState[event.player_index].blueprint = nil
		return
	end

	if event.gui_type ~= defines.gui_type.entity or event.entity == nil then
		return
	end

	local player = game.get_player(event.player_index)
	if not player.can_reach_entity(event.entity) then
		return
	end

	local isPump = IsFilterPump(event.entity)
	local isWagon = IsFilterFluidWagon(event.entity)
	local hasMainlUI = event.name == defines.events.on_gui_opened
	if isPump or isWagon then
		global.guiState[player.index] = global.guiState[player.index] or {}
		local prevEntity = global.guiState[player.index].entity
		global.guiState[player.index].entity = event.entity

		if isWagon and hasMainlUI then
			OpenFluidFilterPanel(player, event.entity)
		else
			OpenEntityWindow(player, event.entity)
		end

		-- this is in order to close the window properly when it's destroyed
		-- all pumps have already registered for this event
		if isWagon and not hasMainlUI then
			script.register_on_entity_destroyed(event.entity)
		end

		if prevEntity and global.openedEntities[prevEntity.unit_number] then
			RemoveValue(global.openedEntities[prevEntity.unit_number].players, player.index)
		end

		local entry = global.openedEntities[event.entity.unit_number] or {players={}}
		table.insert(entry.players, player.index)
		entry.active = event.entity.active
		entry.status = event.entity.status
		global.openedEntities[event.entity.unit_number] = entry
	elseif hasMainlUI then
		CloseFluidFilterPanel(player)
	end
end

function OpenFluidFilterPanel(player, entity)
	local guiType = nil
	local filterFluid = nil
	if IsPump(entity) then
		local filter = entity.fluidbox.get_filter(1)
		filterFluid = filter and filter.name or nil
		guiType = defines.relative_gui_type.entity_with_energy_source_gui
	elseif IsFluidWagon(entity) then
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
		}
		panelFrame = player.gui.relative.add{type='frame', name=frameName, caption={'gui-inserter.filter'}, anchor=anchor}
		local contentFrame = panelFrame.add{type='frame', style='inside_shallow_frame_with_padding'}
		chooseButton = contentFrame.add{type='choose-elem-button', name=CHOOSE_FILTER_BUTTON_NAME, elem_type='fluid'}
	else
		chooseButton = panelFrame.children[1].children[1]
	end

	chooseButton.elem_value = filterFluid
end

function CloseFluidFilterPanel(player)
	local guis = {
		defines.relative_gui_type.entity_with_energy_source_gui,
		defines.relative_gui_type.equipment_grid_gui,
		defines.relative_gui_type.additional_entity_info_gui
	}
	for _, guiType in pairs(guis) do
		local frameName = FILTER_FRAME_NAME .. '-' .. guiType
		local panelFrame = player.gui.relative[frameName]
		if panelFrame then
			OnWindowClosed(player, FILTER_FRAME_NAME)
			panelFrame.destroy()
		end
	end
end

function OpenEntityWindow(player, entity)
	local isPump = IsPump(entity)

	local elements = {}
	local entityFrame = player.gui.screen[ENTITY_FRAME_NAME]
	if entityFrame == nil then
		entityFrame = CreateEntityWindow(player, elements)
		global.guiState[player.index].entityWindow = elements
	else
		elements = global.guiState[player.index].entityWindow
	end

	elements.title.caption = entity.localised_name
	elements.preview.entity = entity

	elements.circuitButton.visible = isPump and (IsCircuitNetworkUnlocked(player) or IsConnectedToCircuitNetwork(entity))
	elements.circuitButton.toggled = isPump and IsConnectedToCircuitNetwork(entity)
	
	elements.logisticButton.visible = isPump
	elements.logisticButton.toggled = isPump and not elements.circuitButton.toggled and IsConnectedToLogisticNetwork(entity)

	FillEntityStatus(elements, entity)

	local disableFilterButton = global.pumps[entity.unit_number] and global.pumps[entity.unit_number][2] == CircuitMode.SetFilter
	FillFilterButton(elements.chooseButton, entity, disableFilterButton)

	if isPump then
		local redNetwork = entity.get_circuit_network(defines.wire_type.red)
		local greenNetwork = entity.get_circuit_network(defines.wire_type.green)
		elements.redNetworkId.visible = redNetwork ~= nil
		elements.greenNetworkId.visible = greenNetwork ~= nil

		-- TODO: make these fancy tooltips showing all signals in the network?

		if redNetwork then
			elements.redNetworkId.caption = {'', {'gui-control-behavior.connected-to-network'}, ': ', {'gui-control-behavior.red-network-id', redNetwork.network_id}}
			elements.redNetworkId.tooltip = {'', {'gui-control-behavior.circuit-network'}, ': ', redNetwork.network_id}
		end
		if greenNetwork then
			elements.greenNetworkId.caption = {'',{'gui-control-behavior.connected-to-network'}, ': ', {'gui-control-behavior.green-network-id', greenNetwork.network_id}}
			elements.greenNetworkId.tooltip = {'', {'gui-control-behavior.circuit-network'}, ': ', greenNetwork.network_id}
		end

		if isPump then
			if global.pumps[entity.unit_number] then
				elements.circuitMode.noneRadio.state = global.pumps[entity.unit_number][2] == CircuitMode.None
				elements.circuitMode.enableDisableRadio.state = global.pumps[entity.unit_number][2] == CircuitMode.EnableDisable
				elements.circuitMode.setFilterRadio.state = global.pumps[entity.unit_number][2] == CircuitMode.SetFilter
			else
				elements.circuitMode.noneRadio.state = true
				elements.circuitMode.enableDisableRadio.state = false
				elements.circuitMode.setFilterRadio.state = false
			end
		end

		local behavior = entity.get_or_create_control_behavior()

		FillCondition(elements.circuitCondition, behavior.circuit_condition.condition)

		FillLogisticBlock(elements, entity)

		FillCondition(elements.logisticCondition, behavior.logistic_condition.condition)
	end

	ToggleCircuitLogisiticBlocksVisibility(player, entity, elements)

	player.opened = entityFrame
	
	RequestLocalizedSignalNames(player)
end

function FillEntityStatus(elements, entity)
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
end

function FillFilterButton(chooseButton, entity, locked)
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
	chooseButton.locked = locked
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

function FillCondition(conditionElements, condition)
	conditionElements.signal1Chooser.elem_value = condition.first_signal
	conditionElements.signal1FakeChooser.sprite = GetSpritePath(condition.first_signal)
	conditionElements.comparatorList.selected_index = IndexOf(conditionElements.comparatorList.items, condition.comparator)
	conditionElements.signal2Chooser.elem_value = condition.second_signal
	conditionElements.signal2FakeChooser.sprite = GetSpritePath(condition.second_signal)
	conditionElements.signal2ConstantChooser.caption = condition.constant ~= nil and GetShortStringValue(condition.constant) or ''
	SelectSignal1Chooser(conditionElements, false)
	SelectSignal2Chooser(conditionElements, false)

	local tags = conditionElements.signal2ConstantChooser.tags or {}
	tags.value = condition.constant
	conditionElements.signal2ConstantChooser.tags = tags
end

function ToggleCircuitLogisiticBlocksVisibility(player, entity, elements)
	local showCircuitNetwork = elements.circuitButton and elements.circuitButton.toggled
	local showLogisticNetwork = not showCircuitNetwork and elements.logisticButton and elements.logisticButton.toggled

	elements.circuitButton.sprite = elements.circuitButton.toggled and 'utility/circuit_network_panel_black' or 'utility/circuit_network_panel_white'
	elements.logisticButton.sprite = elements.logisticButton.toggled and 'utility/logistic_network_panel_black' or 'utility/logistic_network_panel_white'

	if showCircuitNetwork then
		elements.circuitFlow.visible = true
		elements.logisticFlow.visible = false

		if IsConnectedToCircuitNetwork(entity) then
			elements.circuitConnectionFlow.visible = false
			elements.circuitInnerFlow.visible = true
			elements.circuitCondition.flow.visible = elements.circuitMode.enableDisableRadio.state
		else
			elements.circuitConnectionFlow.visible = true
			elements.circuitInnerFlow.visible = false
			elements.circuitCondition.flow.visible = false
		end

	elseif showLogisticNetwork then
		elements.circuitFlow.visible = false
		elements.logisticFlow.visible = true

		local isConnected = IsConnectedToLogisticNetwork(entity)
		elements.logisticInnerFlow.visible = isConnected
		elements.logisticCondition.flow.visible = isConnected
	else
		elements.circuitFlow.visible = false
		elements.logisticFlow.visible = false
	end
end

function CreateEntityWindow(player, elements)
	local entityFrame = player.gui.screen.add{type='frame', name=ENTITY_FRAME_NAME}
	entityFrame.auto_center = true

	local mainFlow = entityFrame.add{type='flow', direction='vertical'}

	local titleFlow = mainFlow.add{type='flow', direction='horizontal'}
	titleFlow.drag_target = entityFrame
	titleFlow.style.horizontal_spacing = 8
	elements.title = titleFlow.add{type='label', ignored_by_interaction=true, style='frame_title'}
	titleFlow.add{type='empty-widget', ignored_by_interaction=true, style=HEADER_FILLER_STYLE}

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
	elements.statusSprite = statusFlow.add{type='sprite'}
	elements.statusText = statusFlow.add{type='label'}

	local previewContainer = contentFlow.add{type='frame', style='slot_container_frame'}
	previewContainer.style.bottom_margin = 4
	elements.preview = previewContainer.add{type='entity-preview', style='wide_entity_button'}

	local columnsFlow = contentFlow.add{type='flow', direction='horizontal'}
	columnsFlow.style.top_margin = 4

	local leftColumnFlow = columnsFlow.add{type='flow', direction='vertical', style=LEFT_COLUMN_STYLE}
	CreateCircuitConditionBlock(leftColumnFlow, elements)
	CreateLogisticConditionBlock(leftColumnFlow, elements)

	local rightColumnFlow = columnsFlow.add{type='flow', direction='vertical', style=RIGHT_COLUMN_STYLE}
	local label = rightColumnFlow.add{type='label', caption={'gui-inserter.filter'}, style='bold_label'}
	label.style.right_padding = 5
	elements.chooseButton = rightColumnFlow.add{type='choose-elem-button', name=CHOOSE_FILTER_BUTTON_NAME, elem_type='fluid'}

	return entityFrame
end

function CreateCircuitConditionBlock(root, elements)
	local circuitFlow = root.add{type='flow', direction='vertical'}
	connectionFlow = circuitFlow.add{type='flow', direction='vertical'}
	connectionFlow.add{type='label', caption={'gui-control-behavior.not-connected'}}

	local innerFlow = circuitFlow.add{type='flow', direction='vertical'}
	elements.redNetworkId = innerFlow.add{type='label'}
	elements.greenNetworkId = innerFlow.add{type='label'}
	innerFlow.add{type='line', direction='horizontal'}
	innerFlow.add{type='label', caption={'gui-control-behavior.mode-of-operation'}, style='caption_label'}
	local noneRadio = innerFlow.add{type='radiobutton', tags={radiogroup='circuit'}, caption={'gui-control-behavior-modes.none'}, tooltip={'gui-control-behavior-modes.none-write-description'}, state=true}
	local enDisRadio = innerFlow.add{type='radiobutton', tags={radiogroup='circuit'}, caption={'gui-control-behavior-modes.enable-disable'}, tooltip={'gui-control-behavior-modes.enable-disable-description'}, state=false}
	local setFilterRadio = innerFlow.add{type='radiobutton', tags={radiogroup='circuit'}, caption={'gui-control-behavior-modes.set-filters'}, tooltip={'gui-control-behavior-modes.set-filters-description'}, state=false}
	--innerFlow.add{type='checkbox', caption={'gui-control-behavior-modes.read-contents'}, tooltip={'gui-control-behavior-modes.read-contents-description'}, state=false}
	
	elements.circuitFlow = circuitFlow
	elements.circuitConnectionFlow = connectionFlow
	elements.circuitInnerFlow = innerFlow
	elements.circuitMode = {
		noneRadio = noneRadio,
		enableDisableRadio = enDisRadio,
		setFilterRadio = setFilterRadio
	}
	CreateEnabledDisabledBlock(circuitFlow, elements, true)
end

function CreateLogisticConditionBlock(root, elements)
	local logisticFlow = root.add{type='flow', direction='vertical'}
	local connectionFlow = logisticFlow.add{type='flow', direction='vertical'}
	local connectedLabel = connectionFlow.add{type='label', caption={'gui-control-behavior.not-connected'}}
	local connectChbx = connectionFlow.add{type='checkbox', caption={'gui-control-behavior.connect'}, state=false, name=LOGISITIC_CONNECT_CHECKBOX_NAME}

	local innerFlow = logisticFlow.add{type='flow', direction='vertical'}
	innerFlow.add{type='line', direction='horizontal'}
	innerFlow.add{type='label', caption={'gui-control-behavior.mode-of-operation'}, style='caption_label'}
	innerFlow.add{type='radiobutton', tags={radiogroup='logistic'}, caption={'gui-control-behavior-modes.enable-disable'}, tooltip={'gui-control-behavior-modes.enable-disable-description'}, state=true}

	elements.logisticFlow = logisticFlow
	elements.logisticConnectionFlow = connectionFlow
	elements.logisticConnectedLabel = connectedLabel
	elements.logisticConnectCheckbox = connectChbx
	elements.logisticInnerFlow = innerFlow
	CreateEnabledDisabledBlock(logisticFlow, elements, false)
end

function CreateEnabledDisabledBlock(root, elements, isCircuit)
	local name = isCircuit and 'circuitEnableConditionFlow' or 'logisitcEnableConditionFlow'
	local conditionFlow = root.add{type='flow', direction='vertical', name=name}
	conditionFlow.add{type='line', direction='horizontal'}
	conditionFlow.add{type='label', caption={'gui-control-behavior-modes-guis.enabled-condition'}, style='caption_label'}
	
	local conditionSelectorFlow = conditionFlow.add{type='flow', direction='horizontal', style='centering_horizontal_flow'}
	
	local tags = {
		enable_disable = true,
		is_circuit = isCircuit,
	}

	name = isCircuit and CHOOSE_CIRCUIT_SIGNAL1_BUTTON_NAME or CHOOSE_LOGISTIC_SIGNAL1_BUTTON_NAME
	local leftChooser = conditionSelectorFlow.add{type='choose-elem-button', elem_type='signal', tags=tags, name=name, style='slot_button_in_shallow_frame'}
	leftChooser.locked = true -- don't open default chooser window, we create our own
	name = isCircuit and CHOOSE_CIRCUIT_SIGNAL1_FAKE_BUTTON_NAME or CHOOSE_LOGISTIC_SIGNAL1_FAKE_BUTTON_NAME
	local fakeLeftChooser = conditionSelectorFlow.add{type='sprite-button', tags=tags, name=name, style='slot_button_in_shallow_frame'}
	fakeLeftChooser.visible = false
	fakeLeftChooser.toggled = true

	name = isCircuit and CHOOSE_CIRCUIT_COMPARATOR_BUTTON_NAME or CHOOSE_LOGISTIC_COMPARATOR_BUTTON_NAME
	local comparatorList = conditionSelectorFlow.add{type='drop-down', items={'>', '<', '=', '≥', '≤', '≠'}, selected_index=2, tags=tags, name=name, style='circuit_condition_comparator_dropdown'}

	name = isCircuit and CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME or CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME
	local rightChooser = conditionSelectorFlow.add{type='choose-elem-button', elem_type='signal', tags=tags, name=name, style='slot_button_in_shallow_frame'}
	rightChooser.locked = true -- don't open default chooser window, we create our own
	name = isCircuit and CHOOSE_CIRCUIT_SIGNAL2_FAKE_BUTTON_NAME or CHOOSE_LOGISTIC_SIGNAL2_FAKE_BUTTON_NAME
	local fakeRightChooser = conditionSelectorFlow.add{type='sprite-button', tags=tags, name=name, style='slot_button_in_shallow_frame'}
	fakeRightChooser.visible = false
	fakeRightChooser.toggled = true
	name = isCircuit and CHOOSE_CIRCUIT_SIGNAL2_CONSTANT_BUTTON_NAME or CHOOSE_LOGISTIC_SIGNAL2_CONSTANT_BUTTON_NAME
	local constantChooser = conditionSelectorFlow.add{type='button', tags=tags, name=name, style=CONSTANT_BUTTON_STYLE, tooltip={'gui.constant-number'}}
	constantChooser.visible = false

	local flowElements = {
		flow = conditionFlow,
		signal1Chooser = leftChooser,
		signal1FakeChooser = fakeLeftChooser,
		comparatorList = comparatorList,
		signal2Chooser = rightChooser,
		signal2FakeChooser = fakeRightChooser,
		signal2ConstantChooser = constantChooser
	}

	if isCircuit then
		elements.circuitCondition = flowElements
	else
		elements.logisticCondition = flowElements
	end
end

function OpenSignalChooseWindow(player, signal, constant, includeSpecialSignals, clickPos)
	local elements = {}
	local signalFrame = player.gui.screen[SIGNAL_FRAME_NAME]
	if signalFrame == nil then
		signalFrame = CreateSignalChooseWindow(player, elements, includeSpecialSignals, constant ~= nil)
		global.guiState[player.index].signalWindow = elements
	else
		elements = global.guiState[player.index].signalWindow
		signalFrame.bring_to_front()
	end

	local signalGroup = signal and GetSignalGroup(signal.name) or nil
	if signalGroup then
		SelectSignalGroup(elements, signalGroup)
	end

	if constant ~= nil then
		elements.constantText.text = tostring(constant)
		elements.constantSlider.slider_value = ConstantValueToSliderValue(tostring(constant))
	end

	local posX = math.min(clickPos.x, player.display_resolution.width - signalFrame.tags.size.x)
	local posY = math.min(clickPos.y, player.display_resolution.height - signalFrame.tags.size.y)
	
	signalFrame.location = {x=posX, y=posY}
end

function CreateSignalChooseWindow(player, elements, includeSpecialSignals, includeConstant)
	local overlayButton = player.gui.screen.add{type='button', name=SIGNAL_OVERLAY_NAME, style=SIGNAL_OVERLAY_STYLE}
	overlayButton.style.width = player.display_resolution.width / player.display_scale
	overlayButton.style.height = player.display_resolution.height / player.display_scale

	local signalFrame = player.gui.screen.add{type='frame', direction='vertical', name=SIGNAL_FRAME_NAME, style='inner_frame_in_outer_frame'}
	signalFrame.style.maximal_height = player.display_resolution.height * 0.85 / player.display_scale

	local titleFlow = signalFrame.add{type='flow', direction='horizontal', style='centering_horizontal_flow'}
	titleFlow.drag_target = signalFrame
	titleFlow.style.horizontal_spacing = 8
	titleFlow.add{type='label', caption={'gui.select-signal'}, ignored_by_interaction=true, style='frame_title'}
	titleFlow.add{type='empty-widget', ignored_by_interaction=true, style=HEADER_FILLER_STYLE}

	local searchField = titleFlow.add{type='textfield', name=SIGNAL_SEARCH_FIELD_NAME, style=SIGNAL_SEARCH_FIELD_STYLE}
	searchField.tags = {dirty=false}
	searchField.visible = false

	local searchButton = titleFlow.add{
		type='sprite-button',
		name=SIGNAL_SEARCH_BUTTON_NAME,
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

	local contentFrame = signalFrame.add{type='frame', direction='vertical', style='crafting_frame'}

	local groupsTable = contentFrame.add{type='table', column_count=SIGNALS_GROUP_ROW_SIZE, style='filter_group_table'}
	
	local wrapperFrame = contentFrame.add{type='frame', style='filter_frame'}
	local scrollPane = wrapperFrame.add{type='scroll-pane', vertical_scroll_policy='always', horizontal_scroll_policy='never', style='filter_scroll_pane_in_tab'}
	local scrollFrame = scrollPane.add{type='frame', direction='vertical', style='filter_scroll_pane_background_frame'}

	local groups = GetSignalGroups()
	local selectedGroupName, _ = next(groups)

	local maxRows = 0
	for _, groupSignals in pairs(groups) do
		local groupRows = 0
		for _, subgroupSignals in pairs(groupSignals) do
			groupRows = groupRows + math.ceil(#(subgroupSignals) / SIGNALS_ROW_SIZE)
		end
		maxRows = math.max(maxRows, groupRows)
	end
	local signalTableHeight = SIGNALS_ROW_HEIGHT * maxRows

	for groupName, groupSignals in pairs(groups) do
		local group = game.item_group_prototypes[groupName]
		local isSelected = selectedGroupName == groupName
		groupsTable.add{
			type='sprite-button',
			sprite='item-group/' .. group.name,
			toggled=isSelected,
			name=group.name,
			tags={type='signal-group'},
			tooltip={'item-group-name.'..group.name},
			style='filter_group_button_tab'
		}

		local signalsTable = scrollFrame.add{type='table', name=group.name, column_count=SIGNALS_ROW_SIZE, style='filter_slot_table'}
		signalsTable.visible = isSelected
		signalsTable.style.height = signalTableHeight
		for _, subgroupSignals in pairs(groupSignals) do
			local numSignalsInSubgroup = 0
			for _, signal in pairs(subgroupSignals) do
				if not signal.special or includeSpecialSignals then
					numSignalsInSubgroup = numSignalsInSubgroup + 1
					local tags = {
						type='signal',
						loc_id=GetSignalLocalizedString(signal)[1]
					}
					local signalButton = signalsTable.add{type='choose-elem-button', elem_type='signal', signal=signal, tags=tags, style='slot_button'}
					signalButton.locked = true
				end
			end

			if numSignalsInSubgroup > 0 then
				local numEmptyWidgets = SIGNALS_ROW_SIZE - (numSignalsInSubgroup % SIGNALS_ROW_SIZE)
				for i = 1, SIGNALS_ROW_SIZE do
					local widget = signalsTable.add{type='empty-widget'}
					widget.visible = i <= numEmptyWidgets
				end
			end
		end
	end

	if includeConstant then
		local constantFrame = contentFrame.add{type='frame', direction='vertical', style='inside_shallow_frame_with_padding'}

		constantFrame.add{type='label', caption={'gui.or-set-a-constant'}, style='frame_title'}

		local constantFlow = constantFrame.add{type='flow', direction='horizontal', style='centering_horizontal_flow'}
		local constantSlider = constantFlow.add{type='slider', maximum_value=41, name=SIGNAL_CONSTANT_SLIDER_NAME}
		local constantText = constantFlow.add{type='textfield', text=0, numeric=true, allow_negative=true, name=SIGNAL_CONSTANT_TEXT_NAME, style='slider_value_textfield'}
		constantFlow.add{type='empty-widget', style=HORIZONTAL_FILLER_STYLE}
		constantFlow.add{type='button', name=SIGNAL_SET_CONSTANT_BUTTON_NAME, caption={'gui.set'}, style='green_button'}

		elements.constantSlider = constantSlider
		elements.constantText = constantText
	end

	elements.searchButton = searchButton
	elements.searchField = searchField
	elements.groupsTable = groupsTable
	elements.scrollPane = scrollPane
	elements.scrollFrame = scrollFrame

	local frameHight =
		8 +  -- frame.top_padding (it's 4 in the style...)
		28 + -- titleFlow (button.minimal_height or probably label height)
		72 * math.ceil(table_size(elements.groupsTable.children) / SIGNALS_GROUP_ROW_SIZE) + -- filter_group_button_tab.size
		6 +  -- filter_frame.top_padding
		4 +  -- filter_scroll_pane.top_padding
		signalTableHeight +
		4 +  -- filter_scroll_pane.bottom_padding
		4 +  -- filter_frame.bottom_padding
		12 + -- WTF
		(includeConstant and (
			12 + -- inside_shallow_frame_with_padding.padding
			28 + -- label height
			28 + -- textbox.minimal_height or button.minimal_height
			12 -- inside_shallow_frame_with_padding.padding
		) or 0) +
		12   -- frame.bottom_padding (it's 8 in the style...)
	frameHight = math.min(frameHight, signalFrame.style.maximal_height)

	local frameWidth =
		12 +  -- frame.left_padding (it's 8 in the style...)
		71 * SIGNALS_GROUP_ROW_SIZE + -- filter_group_button_tab.size
		12    -- frame.right_padding (it's 8 in the style...)

	signalFrame.tags = {size={
		x=math.floor(frameWidth * player.display_scale),
		y=math.floor(frameHight * player.display_scale)
	}}

	return signalFrame
end

function FilterSignals(player, elements, pattern)
	local groupsState = {}
	for _, table in pairs(elements.scrollFrame.children) do
		local hasSignalsInGroup = false
		local numVisibleInSubgroup = 0

		local numChildren = table_size(table.children)
		local i = 1
		while i <= numChildren do
			local widget = table.children[i]
			if widget.type == 'choose-elem-button' then
				widget.visible = g_LocalizedSignalNames[player.index][widget.tags.loc_id]:find(pattern, 1, true) ~= nil
				if widget.visible then
					hasSignalsInGroup = true
					numVisibleInSubgroup = numVisibleInSubgroup + 1
				end
				i = i + 1
			else
				local numEmptyWidgets = 0
				if numVisibleInSubgroup > 0 then
					numEmptyWidgets = SIGNALS_ROW_SIZE - (numVisibleInSubgroup % SIGNALS_ROW_SIZE)
				end
				for j = 0, SIGNALS_ROW_SIZE - 1 do
					widget = table.children[i + j]
					widget.visible = j < numEmptyWidgets
				end

				i = i + SIGNALS_ROW_SIZE
				numVisibleInSubgroup = 0
			end
		end
		groupsState[table.name] = hasSignalsInGroup
	end

	local toggledGroupDisabled = false
	for _, button in pairs(elements.groupsTable.children) do
		button.enabled = groupsState[button.name]
		if button.toggled and not button.enabled then
			toggledGroupDisabled = true
		end
	end

	if toggledGroupDisabled then
		for groupName, state in pairs(groupsState) do
			if state then
				SelectSignalGroup(elements, groupName)
				break
			end
		end
	end

	elements.searchField.tags = {dirty = false}
end

function SelectSignalGroup(elements, groupName)
	for _, button in pairs(elements.groupsTable.children) do
		if button.type == 'sprite-button' then
			button.toggled = button.name == groupName
		end
	end
	for _, table in pairs(elements.scrollFrame.children) do
		table.visible = table.name == groupName
	end
	elements.scrollPane.scroll_to_top()
end

function SelectSignal(entity, elements, signal)
	local conditionElements = elements.circuitFlow.visible and elements.circuitCondition or elements.logisticCondition
	if conditionElements.signal1FakeChooser.visible then
		conditionElements.signal1Chooser.elem_value = signal
		conditionElements.signal1FakeChooser.sprite = GetSpritePath(signal)
		SetEnabledCondition(entity, conditionElements.signal1Chooser, nil)
	else
		conditionElements.signal2Chooser.elem_value = signal
		conditionElements.signal2FakeChooser.sprite = GetSpritePath(signal)
		conditionElements.signal2ConstantChooser.caption = ''
		SetEnabledCondition(entity, conditionElements.signal2Chooser, nil)
	end
end

function SelectConstant(entity, elements, value)
	local conditionElements = elements.circuitFlow.visible and elements.circuitCondition or elements.logisticCondition
	conditionElements.signal2Chooser.elem_value = nil
	conditionElements.signal2FakeChooser.sprite = nil
	conditionElements.signal2ConstantChooser.caption = GetShortStringValue(value)
	local tags = conditionElements.signal2ConstantChooser.tags
	tags.value = value
	conditionElements.signal2ConstantChooser.tags = tags
	SetEnabledCondition(entity, conditionElements.signal2ConstantChooser, value)
end

function SelectSignal1Chooser(conditionElements, isSignalWindowOpened)
	conditionElements.signal1Chooser.visible = not isSignalWindowOpened
	conditionElements.signal1FakeChooser.visible = isSignalWindowOpened
end

function SelectSignal2Chooser(conditionElements, isSignalWindowOpened)
	if conditionElements.signal2ConstantChooser.caption ~= '' then
		conditionElements.signal2Chooser.visible = false
		conditionElements.signal2FakeChooser.visible = false
		conditionElements.signal2ConstantChooser.visible = true
		conditionElements.signal2ConstantChooser.toggled = isSignalWindowOpened
	else
		if isSignalWindowOpened then
			conditionElements.signal2Chooser.visible = false
			conditionElements.signal2FakeChooser.visible = true
			conditionElements.signal2ConstantChooser.visible = false
		else
			conditionElements.signal2Chooser.visible = true
			conditionElements.signal2FakeChooser.visible = false
			conditionElements.signal2ConstantChooser.visible = false
		end
	end
end

function CloseWindow(player, element)
	while element ~= nil do
		if element.name == ENTITY_FRAME_NAME or element.name == SIGNAL_FRAME_NAME then
			OnWindowClosed(player, element.name)
			element.destroy()
			break
		end
		element = element.parent
	end
end

function OnWindowClosed(player, name)
	if name == ENTITY_FRAME_NAME or name == FILTER_FRAME_NAME then
		if player.gui.screen[SIGNAL_FRAME_NAME] then
			CloseWindow(player, player.gui.screen[SIGNAL_FRAME_NAME])
		end

		local entity = global.guiState[player.index] and global.guiState[player.index].entity or nil
		global.guiState[player.index].entityWindow = nil
		global.guiState[player.index] = nil

		if entity and entity.valid and global.openedEntities[entity.unit_number] then
			RemoveValue(global.openedEntities[entity.unit_number].players, player.index)
			if #(global.openedEntities[entity.unit_number].players) == 0 then
				global.openedEntities[entity.unit_number] = nil
			end
		end
	elseif name == SIGNAL_FRAME_NAME then
		if player.gui.screen[SIGNAL_OVERLAY_NAME] then
			player.gui.screen[SIGNAL_OVERLAY_NAME].destroy()
		end

		local elements = global.guiState[player.index].entityWindow
		local conditionElements = elements.circuitFlow.visible and elements.circuitCondition or elements.logisticCondition
		SelectSignal1Chooser(conditionElements, false)
		SelectSignal2Chooser(conditionElements, false)

		global.guiState[player.index].signalWindow = nil
	end
end

function CleanupPlayer(player)
	CloseWindow(player, player.gui.screen[ENTITY_FRAME_NAME])
	CloseFluidFilterPanel(player)
end

function RequestLocalizedSignalNames(player)
	if g_LocalizedSignalNames[player.index] ~= nil then
		return
	end

	local strings = {}
	local groups = GetSignalGroups()
	for _, subgroups in pairs(groups) do
		for _, subgroup in pairs(subgroups) do
			for _, signal in pairs(subgroup) do
				table.insert(strings, GetSignalLocalizedString(signal))
			end
		end
	end

	local ids = player.request_translations(strings)
	for _, id in pairs(ids) do
		g_LocalizationRequests[id] = true
	end
end

---------------------------------------
----- Apply changes to the entity -----
---------------------------------------

function SetFilter(entity, fluid)
	if IsPump(entity) then
		SetPumpFilter(entity, fluid)
	else -- fluid-wagon
		if fluid == nil then
			global.wagons[entity.unit_number] = nil
		else
			global.wagons[entity.unit_number] = {entity, fluid}
			script.register_on_entity_destroyed(entity)
		end
	end

	--game.print('Setting filter for entity ' .. entity.unit_number .. ': ' .. (fluid or 'none'))
end

function ConnectToLogisiticNetwork(entity, connect)
	if not IsPump(entity) then
		return
	end

	local behavior = entity.get_control_behavior()
	if not behavior then
		if not connect then
			return
		end
		behavior = entity.get_or_create_control_behavior()
	end
	behavior.connect_to_logistic_network = connect
end

function SetCircuitMode(entity, circuitMode)
	if not IsPump(entity) then
		return
	end

	if global.pumps[entity.unit_number][2] == circuitMode then
		return
	end

	global.pumps[entity.unit_number][2] = circuitMode

	-- hack away circuit control behavior
	-- which is enabled/disabled by default for pumps and cannot be changed
	if IsConnectedToCircuitNetwork(entity) then
		local behavior = entity.get_control_behavior()
		if behavior then
			if circuitMode == CircuitMode.EnableDisable then
				behavior.circuit_condition = nil
			else
				behavior.circuit_condition = {condition={
					comparator='=',
					first_signal={type='item', name='red-wire'},
					second_signal={type='item', name='red-wire'}
				}}
			end
		end
	end

	--game.print('Entity ' .. entity.unit_number .. (circuitMode == CircuitMode.SetFilter and ' will' or ' will not') .. ' get its filter from circuit network')
end

function SetEnabledCondition(entity, element, constantValue)
	local behavior = entity.get_or_create_control_behavior()
	local condition = element.tags.is_circuit and behavior.circuit_condition.condition or behavior.logistic_condition.condition
	if element.name == CHOOSE_CIRCUIT_SIGNAL1_BUTTON_NAME or element.name == CHOOSE_LOGISTIC_SIGNAL1_BUTTON_NAME then
		condition.first_signal = element.elem_value
	elseif element.name == CHOOSE_CIRCUIT_COMPARATOR_BUTTON_NAME or element.name == CHOOSE_LOGISTIC_COMPARATOR_BUTTON_NAME then
		condition.comparator = element.items[element.selected_index]
	elseif element.name == CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME or element.name == CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME then
		condition.constant = nil
		condition.second_signal = element.elem_value
	elseif element.name == CHOOSE_CIRCUIT_SIGNAL2_CONSTANT_BUTTON_NAME or element.name == CHOOSE_LOGISTIC_SIGNAL2_CONSTANT_BUTTON_NAME then
		condition.constant = constantValue
		condition.second_signal = nil
	end

	if element.tags.is_circuit then
		behavior.circuit_condition = {condition=condition}
	else
		behavior.logistic_condition = {condition=condition}
	end
end

----------------------------------
-------- Event callbacks ---------
----------------------------------

script.on_event(defines.events.on_gui_opened, OnGuiOpened)
script.on_event(OPEN_GUI_INPUT_EVENT, function(event)
	local player = game.get_player(event.player_index)
	local hasSomethingInHand = player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read
	if player.selected == nil
		or global.guiState[player.index] and player.selected == global.guiState[player.index].entity
		or hasSomethingInHand then
		return
	end

	event.gui_type = defines.gui_type.entity
	event.entity = player.selected
	OnGuiOpened(event)
end)

script.on_event(defines.events.on_gui_click, IfGuiOpened(function(player, event)
	---- Signal Selection Window handling ----
	local elements = global.guiState[player.index].signalWindow
	if elements then
		if event.element.name == SIGNAL_SET_CONSTANT_BUTTON_NAME then
			local value = elements.constantText.text
			local entityWindowElements = global.guiState[player.index].entityWindow
			SelectConstant(global.guiState[player.index].entity, entityWindowElements, tonumber(value))
			CloseWindow(player, event.element)
			return
		elseif event.element.name == SIGNAL_OVERLAY_NAME then
			CloseWindow(player, player.gui.screen[SIGNAL_FRAME_NAME])
			return
		elseif event.element.name == SIGNAL_SEARCH_BUTTON_NAME then
			elements.searchField.visible = event.element.toggled
			if event.element.toggled then
				elements.searchField.focus()
			else
				if elements.searchField.text ~= '' or elements.searchField.tags.dirty then
					FilterSignals(player, elements, '')
				end
				elements.searchField.text = ''
			end
		elseif event.element.tags then
			if event.element.tags.type == 'signal-group' then
				SelectSignalGroup(elements, event.element.name)
			elseif event.element.tags.type == 'signal' then
				local entityWindowElements = global.guiState[player.index].entityWindow
				SelectSignal(global.guiState[player.index].entity, entityWindowElements, event.element.elem_value)
				CloseWindow(player, event.element)
				return
			end
		end

		local constantText = elements.constantText
		if constantText and constantText.text == '' then
			constantText.text = '0'
		end
	end
	------------------------------------------

	---- Entity Window handling ----
	elements = global.guiState[player.index].entityWindow
	if elements then
		if event.element.name == CLOSE_BUTTON_NAME then
			CloseWindow(player, event.element)
			return
		elseif event.element.name == CIRCUIT_BUTTON_NAME or event.element.name == LOGISTIC_BUTTON_NAME then
			if event.element.toggled then
				if event.element.name == CIRCUIT_BUTTON_NAME then
					elements.logisticButton.toggled = false
				else
					elements.circuitButton.toggled = false
				end
			end
			ToggleCircuitLogisiticBlocksVisibility(player, global.guiState[player.index].entity, elements)
		elseif event.element.name == LOGISITIC_CONNECT_CHECKBOX_NAME then
			ConnectToLogisiticNetwork(global.guiState[player.index].entity, event.element.state)
			FillLogisticBlock(elements, global.guiState[player.index].entity)
			ToggleCircuitLogisiticBlocksVisibility(player, global.guiState[player.index].entity, elements)
		elseif event.element.name == CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME or event.element.name == CHOOSE_CIRCUIT_SIGNAL2_CONSTANT_BUTTON_NAME or
				event.element.name == CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME or event.element.name == CHOOSE_LOGISTIC_SIGNAL2_CONSTANT_BUTTON_NAME then
			if event.button == defines.mouse_button_type.right then
				if event.element.type == 'choose-elem-button' then
					event.element.elem_value = nil
				else
					event.element.caption = ''
				end

				SetEnabledCondition(global.guiState[player.index].entity, event.element, nil)
			else
				local conditionElements = elements.circuitFlow.visible and elements.circuitCondition or elements.logisticCondition
				SelectSignal2Chooser(conditionElements, true)

				local signal = event.element.type == 'choose-elem-button' and event.element.elem_value or nil
				local constant = event.element.type == 'button' and event.element.tags.value or 0
				OpenSignalChooseWindow(player, signal, constant, false, event.cursor_display_location)
			end
		elseif event.element.name == CHOOSE_CIRCUIT_SIGNAL1_BUTTON_NAME or event.element.name == CHOOSE_LOGISTIC_SIGNAL1_BUTTON_NAME then
			if event.button == defines.mouse_button_type.right then
				event.element.elem_value = nil
				SetEnabledCondition(global.guiState[player.index].entity, event.element, nil)
			else
				local conditionElements = elements.circuitFlow.visible and elements.circuitCondition or elements.logisticCondition
				SelectSignal1Chooser(conditionElements, true)

				local signal = event.element.type == 'choose-elem-button' and event.element.elem_value or nil
				OpenSignalChooseWindow(player, signal, nil, true, event.cursor_display_location)
			end
		elseif event.element.tags and event.element.tags.radiogroup == 'circuit' then
			for _, radio in pairs(elements.circuitMode) do
				if radio ~= event.element then
					radio.state = false
				end
			end

			local circuitMode = CircuitMode.None
			if elements.circuitMode.enableDisableRadio.state then
				circuitMode = CircuitMode.EnableDisable
			elseif elements.circuitMode.setFilterRadio.state then
				circuitMode = CircuitMode.SetFilter
			end

			local setFilterFromCircuit = elements.circuitMode.setFilterRadio.state
			SetCircuitMode(global.guiState[player.index].entity, circuitMode)
			UpdateCircuit(global.guiState[player.index].entity, circuitMode)
			FillCondition(elements.circuitCondition, global.guiState[player.index].entity.get_or_create_control_behavior().circuit_condition.condition)
			FillFilterButton(elements.chooseButton, global.guiState[player.index].entity, circuitMode == CircuitMode.SetFilter)
			ToggleCircuitLogisiticBlocksVisibility(player, global.guiState[player.index].entity, elements)
		end
	end
end))

-- choose-elem-button
script.on_event(defines.events.on_gui_elem_changed, IfGuiOpened(function(player, event)
	if event.element.name == CHOOSE_FILTER_BUTTON_NAME then
		SetFilter(global.guiState[player.index].entity, event.element.elem_value)
	end
end))

-- drop-down
script.on_event(defines.events.on_gui_selection_state_changed, IfGuiOpened(function(player, event)
	if event.element.tags and event.element.tags.enable_disable then
		SetEnabledCondition(global.guiState[player.index].entity, event.element, nil)
	end
end))

-- textfield
script.on_event(defines.events.on_gui_confirmed, IfGuiOpened(function(player, event)
	if event.element.name == SIGNAL_CONSTANT_TEXT_NAME then
		local value = global.guiState[player.index].signalWindow.constantText.text
		local elements = global.guiState[player.index].entityWindow
		SelectConstant(global.guiState[player.index].entity, elements, tonumber(value))
		CloseWindow(player, event.element)
	elseif event.element.name == SIGNAL_SEARCH_FIELD_NAME then
		if g_LocalizedSignalNames[player.index] ~= nil then
			local elements = global.guiState[player.index].signalWindow
			FilterSignals(player, elements, event.element.text:lower())
		end
	end
end))

-- slider
script.on_event(defines.events.on_gui_value_changed, IfGuiOpened(function(player, event)
	if event.element.name == SIGNAL_CONSTANT_SLIDER_NAME then
		local elements = global.guiState[player.index].signalWindow
		elements.constantText.text = tostring(SliderValueToConstantValue(event.element.slider_value))
	end
end))

-- textfield
script.on_event(defines.events.on_gui_text_changed, IfGuiOpened(function(player, event)
	if event.element.name == SIGNAL_CONSTANT_TEXT_NAME then
		local elements = global.guiState[player.index].signalWindow
		elements.constantSlider.slider_value = ConstantValueToSliderValue(event.element.text)
	elseif event.element.name == SIGNAL_SEARCH_FIELD_NAME then
		event.element.tags = {dirty = true}
	end
end))

script.on_event(FOCUS_SEARCH_INPUT_EVENT, IfGuiOpened(function(player, event)
	local elements = global.guiState[player.index].signalWindow
	if elements == nil or elements.searchField.visible then
		return
	end

	elements.searchButton.toggled = true
	elements.searchField.visible = true
	elements.searchField.focus()
end))

script.on_event(defines.events.on_gui_closed, IfGuiOpened(function(player, event)
	if event.element then
		if player.gui.screen[SIGNAL_FRAME_NAME] then
			local elements = global.guiState[player.index].signalWindow
			if elements.searchField.visible then
				elements.searchField.visible = false
				if elements.searchField.text ~= '' or elements.searchField.tags.dirty then
					FilterSignals(player, elements, '')
				end
				elements.searchField.text = ''
			else
				CloseWindow(player, player.gui.screen[SIGNAL_FRAME_NAME])
			end
			player.opened = event.element
		else
			OnWindowClosed(player, event.element.name)
			event.element.destroy()
		end
	elseif event.entity and event.entity == global.guiState[player.index].entity then
		CloseFluidFilterPanel(player)
	elseif event.item and event.item.valid_for_read and event.item.is_blueprint_setup() then
		global.guiState[event.player_index].blueprint = event.item
	end
end))

script.on_event(defines.events.on_player_changed_position, IfGuiOpened(function(player, event)
	local entity = global.guiState[player.index].entity
	if not entity or not entity.valid or not player.can_reach_entity(entity) then
		CleanupPlayer(player)
	end
end))

script.on_event(ON_ENTITY_STATE_CHANGED, ForAllPlayersOpenedEntity(function(player, event)
	FillEntityStatus(global.guiState[player.index].entityWindow, event.entity)
end))

script.on_event(ON_ENTITY_DESTROYED_CUSTOM, ForAllPlayersOpenedEntity(function(player, event)
	CleanupPlayer(player)
	global.openedEntities[event.unit_number] = nil
end))

script.on_event(defines.events.on_player_died, IfGuiOpened(function(player, event)
	CleanupPlayer(player)
end))

script.on_event(defines.events.on_player_left_game, IfGuiOpened(function(player, event)
	CleanupPlayer(player)
end))

script.on_event(defines.events.on_player_removed, function(event)
	if global.guiState[event.player_index] then
		local entity = global.guiState[event.player_index].entity
		if entity and entity.valid then
			RemoveValue(global.openedEntities[entity.unit_number].players, event.player_index)
		end
	end
	global.guiState[event.player_index] = nil
end)

script.on_event(defines.events.on_string_translated, function(event)
	if not event.translated then
		log('Failed to translate "' .. serpent.block(event.localised_string) .. '"')
		return
	end

	if not g_LocalizationRequests[event.id] then
		return
	end

	g_LocalizationRequests[event.id] = nil

	if g_LocalizedSignalNames[event.player_index] == nil then
		g_LocalizedSignalNames[event.player_index] = {}
	end
	g_LocalizedSignalNames[event.player_index][event.localised_string[1]] = event.result:lower()
end)