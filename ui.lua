local ENTITY_FRAME_NAME = 'ui-entity'
local FILTER_FRAME_NAME = 'ui-liquid-filter'
local CLOSE_BUTTON_NAME = 'ui-close'
local CIRCUIT_BUTTON_NAME = 'ui-circuit'
local LOGISTIC_BUTTON_NAME = 'ui-logistic'
local CHOOSE_FILTER_BUTTON_NAME = 'ui-liquid-filter-chooser'
local CHOOSE_CIRCUIT_SIGNAL1_BUTTON_NAME = 'ui-circuit-signal1-chooser'
local CHOOSE_CIRCUIT_COMPARATOR_BUTTON_NAME = 'ui-circuit-comparator-chooser'
local CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME = 'ui-circuit-signal2-chooser'
local CHOOSE_CIRCUIT_SIGNAL2_FAKE_BUTTON_NAME = 'ui-circuit-signal2-choser-fake'
local CHOOSE_CIRCUIT_SIGNAL2_CONSTANT_BUTTON_NAME = 'ui-circuit-signal-chooser-constant'
local CHOOSE_LOGISTIC_SIGNAL1_BUTTON_NAME = 'ui-logistic-signal1-chooser'
local CHOOSE_LOGISTIC_COMPARATOR_BUTTON_NAME = 'ui-logistic-comparator-chooser'
local CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME = 'ui-logistic-signal-chooser'
local CHOOSE_LOGISTIC_SIGNAL2_FAKE_BUTTON_NAME = 'ui-logistic-signal2-choser-fake'
local CHOOSE_LOGISTIC_SIGNAL2_CONSTANT_BUTTON_NAME = 'ui-logistic-signal-chooser-constant'
local LOGISITIC_CONNECT_CHECKBOX_NAME = 'ui-logistic-connect'

local SIGNAL_FRAME_NAME = 'ui-signal'
local SIGNAL_OVERLAY_NAME = 'ui-signal-overlay'
local SIGNAL_SEARCH_BUTTON_NAME = 'ui-search'
local SIGNAL_SEARCH_FIELD_NAME = 'ui-search-field'
local SIGNAL_CONSTANT_SLIDER_NAME = 'ui-signal-slider'
local SIGNAL_CONSTANT_TEXT_NAME = 'ui-signal-text'
local SIGNAL_SET_CONSTANT_BUTTON_NAME = 'ui-signal-set'

local SIGNALS_FRAME_HEIGHT = 930
local SIGNALS_ROW_HEIGHT = 40 -- styles.slot_button.size
local SIGNALS_GROUP_ROW_SIZE = 6
local SIGNALS_ROW_SIZE = 10

local SIGNAL_VALUE_MIN = -2^31
local SIGNAL_VALUE_MAX = 2^31 - 1

local g_OpenedEntity = {} -- {player-index => entity}
local g_GuiElements = {} -- {player-index => {entityWindow={}, signalWindow={}}}
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

----------------------------------------
----- UI creation and interaction ------
----------------------------------------

function FindElementByName(root, name)
	if not root or root.name == name then
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

		g_OpenedEntity[player.index] = event.entity
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
		g_GuiElements[player.index] = {entityWindow = elements}
	else
		elements = g_GuiElements[player.index].entityWindow
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

	local disableFilterButton = global.pumps[entity.unit_number] and global.pumps[entity.unit_number][2] == CircuitMode.SetFilter
	FillFilterButton(elements.chooseButton, entity, disableFilterButton)

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

	ToggleCircuitLogisiticBlocksVisibility(player, entity, elements)
	
	player.opened = entityFrame

	RequestLocalizedSignalNames(player)
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
	conditionElements.comparatorList.selected_index = IndexOf(conditionElements.comparatorList.items, condition.comparator)
	conditionElements.signal2Chooser.elem_value = condition.second_signal
	conditionElements.signal2FakeChooser.sprite = condition.second_signal and (condition.second_signal.type .. '/' .. condition.second_signal.name) or nil
	conditionElements.signal2ConstantChooser.caption = condition.constant ~= nil and GetShortStringValue(condition.constant) or ''
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
	titleFlow.add{type='empty-widget', ignored_by_interaction=true, style='header_filler'}

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

	local leftColumnFlow = columnsFlow.add{type='flow', direction='vertical', style='left_column'}
	CreateCircuitConditionBlock(leftColumnFlow, elements)
	CreateLogisticConditionBlock(leftColumnFlow, elements)

	local rightColumnFlow = columnsFlow.add{type='flow', direction='vertical', style='right_column'}
	rightColumnFlow.add{type='label', caption='Filter:', style='bold_label'}
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
	local constantChooser = conditionSelectorFlow.add{type='button', tags=tags, name=name, style='constant_button', tooltip={'gui.constant-number'}}
	constantChooser.visible = false

	local flowElements = {
		flow = conditionFlow,
		signal1Chooser = leftChooser,
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

function OpenSignalChooseWindow(player, signal, constant, clickPos)
	local elements = {}
	local signalFrame = player.gui.screen[SIGNAL_FRAME_NAME]
	if signalFrame == nil then
		signalFrame = CreateSignalChooseWindow(player, elements)
		g_GuiElements[player.index].signalWindow = elements
	else
		elements = g_GuiElements[player.index].signalWindow
		signalFrame.bring_to_front()
	end

	local signalGroup = signal and GetSignalGroup(signal.name) or nil
	if signalGroup then
		SelectSignalGroup(elements, signalGroup)
	end

	elements.constantText.text = tostring(constant)
	elements.constantSlider.slider_value = ConstantValueToSliderValue(tostring(constant))

	local posX = math.min(clickPos.x, player.display_resolution.width - signalFrame.tags.size.x)
	local posY = math.min(clickPos.y, player.display_resolution.height - signalFrame.tags.size.y)
	
	signalFrame.location = {x=posX, y=posY}
end

function CreateSignalChooseWindow(player, elements)
	player.gui.screen.add{type='button', name=SIGNAL_OVERLAY_NAME, style='signal_overlay'}

	local signalFrame = player.gui.screen.add{type='frame', direction='vertical', name=SIGNAL_FRAME_NAME, style='inner_frame_in_outer_frame'}
	signalFrame.style.maximal_height = SIGNALS_FRAME_HEIGHT

	local titleFlow = signalFrame.add{type='flow', direction='horizontal', style='centering_horizontal_flow'}
	titleFlow.drag_target = signalFrame
	titleFlow.style.horizontal_spacing = 8
	titleFlow.add{type='label', caption={'gui.select-signal'}, ignored_by_interaction=true, style='frame_title'}
	titleFlow.add{type='empty-widget', ignored_by_interaction=true, style='header_filler'}

	local searchField = titleFlow.add{type='textfield', name=SIGNAL_SEARCH_FIELD_NAME, style='signal_search_field'}
	searchField.visible = false

	titleFlow.add{
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
			for _, signal in pairs(subgroupSignals) do
				local tags = {
					type='signal',
					loc_id=GetSignalLocalizedString(signal)[1]
				}
				local signalButton = signalsTable.add{type='choose-elem-button', elem_type='signal', signal=signal, tags=tags, style='slot_button'}
				signalButton.locked = true
			end
			
			local numEmptyWidgets = SIGNALS_ROW_SIZE - (#(subgroupSignals) % SIGNALS_ROW_SIZE)
			for i = 1, SIGNALS_ROW_SIZE do
				local widget = signalsTable.add{type='empty-widget'}
				widget.visible = i <= numEmptyWidgets
			end
		end
	end

	local constantFrame = contentFrame.add{type='frame', direction='vertical', style='inside_shallow_frame_with_padding'}

	constantFrame.add{type='label', caption={'gui.or-set-a-constant'}, style='frame_title'}

	local constantFlow = constantFrame.add{type='flow', direction='horizontal', style='centering_horizontal_flow'}
	local constantSlider = constantFlow.add{type='slider', maximum_value=41, name=SIGNAL_CONSTANT_SLIDER_NAME}
	local constantText = constantFlow.add{type='textfield', text=0, numeric=true, allow_negative=true, name=SIGNAL_CONSTANT_TEXT_NAME, style='slider_value_textfield'}
	constantFlow.add{type='empty-widget', style='horizontal_filler'}
	constantFlow.add{type='button', name=SIGNAL_SET_CONSTANT_BUTTON_NAME, caption={'gui.set'}, style='green_button'}

	elements.searchField = searchField
	elements.groupsTable = groupsTable
	elements.scrollPane = scrollPane
	elements.scrollFrame = scrollFrame
	elements.constantSlider = constantSlider
	elements.constantText = constantText

	local frameHight =
		8 +  -- frame.top_padding (it's 4 in the style...)
		28 + -- titleFlow (button.minimal_height or probably label height)
		72 * math.ceil(#(elements.groupsTable.children) / SIGNALS_GROUP_ROW_SIZE) + -- filter_group_button_tab.size
		6 +  -- filter_frame.top_padding
		4 +  -- filter_scroll_pane.top_padding
		signalTableHeight +
		4 +  -- filter_scroll_pane.bottom_padding
		4 +  -- filter_frame.bottom_padding
		12 + -- WTF
		12 + -- inside_shallow_frame_with_padding.padding
		28 + -- label height
		28 + -- textbox.minimal_height or button.minimal_height
		12 + -- inside_shallow_frame_with_padding.padding
		12   -- frame.bottom_padding (it's 8 in the style...)
	frameHight = math.min(frameHight, SIGNALS_FRAME_HEIGHT)

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

		local numChildren = #(table.children)
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
	conditionElements.signal2Chooser.elem_value = signal
	conditionElements.signal2FakeChooser.sprite = signal and (signal.type .. '/' .. signal.name) or nil
	conditionElements.signal2ConstantChooser.caption = ''
	SetEnabledCondition(entity, conditionElements.signal2Chooser, nil)
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
	if name == ENTITY_FRAME_NAME then
		if player.gui.screen[SIGNAL_FRAME_NAME] then
			CloseWindow(player, player.gui.screen[SIGNAL_FRAME_NAME])
		end
		g_OpenedEntity[player.index] = nil

		g_GuiElements[player.index].entityWindow = nil
	elseif name == SIGNAL_FRAME_NAME then
		if player.gui.screen[SIGNAL_OVERLAY_NAME] then
			player.gui.screen[SIGNAL_OVERLAY_NAME].destroy()
		end

		local elements = g_GuiElements[player.index].entityWindow
		local conditionElements = elements.circuitFlow.visible and elements.circuitCondition or elements.logisticCondition
		SelectSignal2Chooser(conditionElements, false)

		g_GuiElements[player.index].signalWindow = nil
	end
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

function SetFilter(player, entity, fluid)
	if entity.type == 'pump' then
		if fluid == nil then
			entity.fluidbox.set_filter(1, nil)
		else
			entity.fluidbox.set_filter(1, {name=fluid, force=true})
		end
	else -- fluid-wagon
		if fluid == nil then
			global.wagons[entity.unit_number] = nil
		else
			global.wagons[entity.unit_number] = {entity, fluid}
			script.register_on_entity_destroyed(entity)
		end
	end

	player.print('Setting filter for entity ' .. entity.unit_number .. ': ' .. (fluid or 'none'))
end

function ConnectToLogisiticNetwork(entity, connect)
	if entity.type == 'pump' then
		local behavior = entity.get_control_behavior()
		if not behavior then
			if not connect then
				return
			end
			behavior = entity.get_or_create_control_behavior()
		end
		behavior.connect_to_logistic_network = connect
	end
end

function SetCircuitMode(player, entity, circuitMode)
	if entity.type ~= 'pump' then
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

	player.print('Entity ' .. entity.unit_number .. (circuitMode == CircuitMode.SetFilter and ' will' or ' will not') .. ' get its filter from circuit network')
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
script.on_event('open_gui', function(event)
	local player = game.get_player(event.player_index)
	if player.selected == nil or player.selected == g_OpenedEntity[player.index] or player.cursor_stack then
		return
	end

	event.gui_type = defines.gui_type.entity
	event.entity = player.selected
	OnGuiOpened(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
	local player = game.get_player(event.player_index)
	if g_OpenedEntity[player.index] == nil then
		return
	end

	---- Signal Selection Window handling ----
	if event.element.name == SIGNAL_SET_CONSTANT_BUTTON_NAME then
		local value = g_GuiElements[player.index].signalWindow.constantText.text
		local elements = g_GuiElements[player.index].entityWindow
		SelectConstant(g_OpenedEntity[player.index], elements, tonumber(value))
		CloseWindow(player, event.element)
		return
	elseif event.element.name == SIGNAL_OVERLAY_NAME then
		CloseWindow(player, player.gui.screen[SIGNAL_FRAME_NAME])
		return
	elseif event.element.name == SIGNAL_SEARCH_BUTTON_NAME then
		local elements = g_GuiElements[player.index].signalWindow
		elements.searchField.visible = event.element.toggled
		if event.element.toggled then
			elements.searchField:focus()
		else
			if elements.searchField.text ~= '' then
				FilterSignals(player, elements, '')
			end
			elements.searchField.text = ''
		end
	elseif event.element.tags then
		if event.element.tags.type == 'signal-group' then
			local elements = g_GuiElements[player.index].signalWindow
			SelectSignalGroup(elements, event.element.name)
		elseif event.element.tags.type == 'signal' then
			local elements = g_GuiElements[player.index].entityWindow
			SelectSignal(g_OpenedEntity[player.index], elements, event.element.elem_value)
			CloseWindow(player, event.element)
			return
		end
	end

	local textField = FindElementByName(player.gui.screen[SIGNAL_FRAME_NAME], SIGNAL_CONSTANT_TEXT_NAME)
	if textField and textField.text == '' then
		textField.text = '0'
	end
	------------------------------------------

	---- Entity Window handling ----
	if event.element.name == CLOSE_BUTTON_NAME then
		CloseWindow(player, event.element)
		return
	elseif event.element.name == CIRCUIT_BUTTON_NAME or event.element.name == LOGISTIC_BUTTON_NAME then
		local elements = g_GuiElements[player.index].entityWindow
		if event.element.toggled then
			if event.element.name == CIRCUIT_BUTTON_NAME then
				elements.logisticButton.toggled = false
			else
				elements.circuitButton.toggled = false
			end
		end
		ToggleCircuitLogisiticBlocksVisibility(player, g_OpenedEntity[player.index], elements)
	elseif event.element.name == LOGISITIC_CONNECT_CHECKBOX_NAME then
		local elements = g_GuiElements[player.index].entityWindow
		ConnectToLogisiticNetwork(g_OpenedEntity[player.index], event.element.state)
		FillLogisticBlock(elements, g_OpenedEntity[player.index])
		ToggleCircuitLogisiticBlocksVisibility(player, g_OpenedEntity[player.index], elements)
	elseif event.element.name == CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME or event.element.name == CHOOSE_CIRCUIT_SIGNAL2_CONSTANT_BUTTON_NAME or
			event.element.name == CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME or event.element.name == CHOOSE_LOGISTIC_SIGNAL2_CONSTANT_BUTTON_NAME then
		if event.button == defines.mouse_button_type.right then
			if event.element.type == 'choose-elem-button' then
				event.element.elem_value = nil
			else
				event.element.caption = ''
			end

			SetEnabledCondition(g_OpenedEntity[player.index], event.element, nil)
		else
			local elements = g_GuiElements[player.index].entityWindow
			local conditionElements = elements.circuitFlow.visible and elements.circuitCondition or elements.logisticCondition
			SelectSignal2Chooser(conditionElements, true)

			local signal = event.element.type == 'choose-elem-button' and event.element.elem_value or nil
			local constant = event.element.type == 'button' and event.element.tags.value or 0
			OpenSignalChooseWindow(player, signal, constant, event.cursor_display_location)
		end
	elseif event.element.tags and event.element.tags.radiogroup == 'circuit' then
		local elements = g_GuiElements[player.index].entityWindow
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
		SetCircuitMode(player, g_OpenedEntity[player.index], circuitMode)
		UpdateCircuit(g_OpenedEntity[player.index], circuitMode)
		FillCondition(elements.circuitCondition, g_OpenedEntity[player.index].get_or_create_control_behavior().circuit_condition.condition)
		FillFilterButton(elements.chooseButton, g_OpenedEntity[player.index], circuitMode == CircuitMode.SetFilter)
		ToggleCircuitLogisiticBlocksVisibility(player, g_OpenedEntity[player.index], elements)
	end
end)

-- choose-elem-button
script.on_event(defines.events.on_gui_elem_changed, function(event)
	local player = game.get_player(event.player_index)
	if g_OpenedEntity[player.index] == nil then
		return
	end

	if event.element.name == CHOOSE_FILTER_BUTTON_NAME then
		SetFilter(player, g_OpenedEntity[player.index], event.element.elem_value)
	elseif event.element.tags and event.element.tags.enable_disable then
		SetEnabledCondition(g_OpenedEntity[player.index], event.element, nil)
	end
end)

-- drop-down
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
	local player = game.get_player(event.player_index)
	if g_OpenedEntity[player.index] == nil then
		return
	end

	if event.element.tags and event.element.tags.enable_disable then
		SetEnabledCondition(g_OpenedEntity[player.index], event.element, nil)
	end
end)

-- textfield
script.on_event(defines.events.on_gui_confirmed, function(event)
	local player = game.get_player(event.player_index)
	if g_OpenedEntity[player.index] == nil then
		return
	end

	if event.element.name == SIGNAL_CONSTANT_TEXT_NAME then
		local value = g_GuiElements[player.index].signalWindow.constantText.text
		local elements = g_GuiElements[player.index].entityWindow
		SelectConstant(g_OpenedEntity[player.index], elements, tonumber(value))
		CloseWindow(player, event.element)
	elseif event.element.name == SIGNAL_SEARCH_FIELD_NAME then
		if g_LocalizedSignalNames[player.index] ~= nil then
			local elements = g_GuiElements[player.index].signalWindow
			FilterSignals(player, elements, event.element.text:lower())
		end
	end
end)

-- slider
script.on_event(defines.events.on_gui_value_changed, function(event)
	local player = game.get_player(event.player_index)
	if g_OpenedEntity[player.index] == nil then
		return
	end

	if event.element.name == SIGNAL_CONSTANT_SLIDER_NAME then
		local elements = g_GuiElements[player.index].signalWindow
		elements.constantText.text = tostring(SliderValueToConstantValue(event.element.slider_value))
	end
end)

-- textfield
script.on_event(defines.events.on_gui_text_changed, function(event)
	local player = game.get_player(event.player_index)
	if g_OpenedEntity[player.index] == nil then
		return
	end

	if event.element.name == SIGNAL_CONSTANT_TEXT_NAME then
		local elements = g_GuiElements[player.index].signalWindow
		elements.constantSlider.slider_value = ConstantValueToSliderValue(event.element.text)
	end
end)

script.on_event(defines.events.on_gui_closed, function(event)
	local player = game.get_player(event.player_index)
	if g_OpenedEntity[player.index] == nil then
		return
	end

	if event.element then
		if player.gui.screen[SIGNAL_FRAME_NAME] then
			local elements = g_GuiElements[player.index].signalWindow
			if elements.searchField.visible then
				elements.searchField.visible = false
				if elements.searchField.text ~= '' then
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
	end
end)

script.on_event(defines.events.on_string_translated, function(event)
	if not event.translated then
		game.get_player(event.player_index).print('Failed to translate "' .. serpent.block(event.localised_string) .. '"')
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