local ENTITY_FRAME_NAME = 'ui-entity'
local FILTER_FRAME_NAME = 'ui-liquid-filter'
local CLOSE_BUTTON_NAME = 'ui-close'
local CIRCUIT_BUTTON_NAME = 'ui-circuit'
local LOGISTIC_BUTTON_NAME = 'ui-logistic'
local CHOOSE_FILTER_BUTTON_NAME = 'ui-liquid-filter-chooser'
local CHOOSE_CIRCUIT_SIGNAL1_BUTTON_NAME = 'ui-circuit-signal1-chooser'
local CHOOSE_CIRCUIT_COMPARATOR_BUTTON_NAME = 'ui-circuit-comparator-chooser'
local CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME = 'ui-circuit-signal2-chooser'
local CHOOSE_CIRCUIT_SIGNAL2_FAKE_BUTTON_NAME = 'ui-circuit-signal-chooser-fake'
local CHOOSE_LOGISTIC_SIGNAL1_BUTTON_NAME = 'ui-logistic-signal1-chooser'
local CHOOSE_LOGISTIC_COMPARATOR_BUTTON_NAME = 'ui-logistic-comparator-chooser'
local CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME = 'ui-logistic-signal-chooser'
local CHOOSE_LOGISTIC_SIGNAL2_FAKE_BUTTON_NAME = 'ui-logistic-signal-chooser-fake'
local LOGISITIC_CONNECT_CHECKBOX_NAME = 'ui-logistic-connect'

local SIGNAL_FRAME_NAME = 'ui-signal'
local SIGNAL_SEARCH_BUTTON_NAME = 'ui-search'
local SIGNAL_GROUP_NAME_PREFIX = 'ui-signal-group-'
local SIGNAL_SIGNAL_NAME_PREFIX = 'ui-signal-signal-'
local SIGNAL_CONSTANT_SLIDER_NAME = 'ui-signal-slider'
local SIGNAL_CONSTANT_TEXT_NAME = 'ui-signal-text'
local SIGNAL_SET_CONSTANT_BUTTON_NAME = 'ui-signal-set'

local SIGNALS_FRAME_HEIGHT = 930
local SIGNALS_ROW_HEIGHT = 40 -- styles.slot_button.size
local SIGNALS_GROUP_ROW_SIZE = 6
local SIGNALS_ROW_SIZE = 10

local SIGNAL_VALUE_MIN = -2^31
local SIGNAL_VALUE_MAX = 2^31 - 1

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

	local circuitCondition = behavior.circuit_condition.condition
	elements.circuitConditionSignal1Chooser.elem_value = circuitCondition.first_signal
	elements.circuitConditionComparatorList.selected_index = IndexOf(elements.circuitConditionComparatorList.items, circuitCondition.comparator)
	elements.circuitConditionSignal2Chooser.elem_value = circuitCondition.second_signal
	elements.circuitConditionSignal2Chooser.visible = circuitCondition.second_signal ~= nil
	elements.circuitConditionSignal2FakeChooser.caption = circuitCondition.constant ~= nil and GetShortStringValue(circuitCondition.constant) or 0
	elements.circuitConditionSignal2FakeChooser.visible = not elements.circuitConditionSignal2Chooser.visible
	local tags = elements.circuitConditionSignal2FakeChooser.tags or {}
	tags.value = circuitCondition.constant
	elements.circuitConditionSignal2FakeChooser.tags = tags

	FillLogisticBlock(elements, entity)

	local logisitcCondition = behavior.logistic_condition.condition
	elements.logisitcConditionSignal1Chooser.elem_value = logisitcCondition.first_signal
	elements.logisitcConditionComparatorList.selected_index = IndexOf(elements.logisitcConditionComparatorList.items, logisitcCondition.comparator)
	elements.logisitcConditionSignal2Chooser.elem_value = logisitcCondition.second_signal
	elements.logisitcConditionSignal2Chooser.visible = logisitcCondition.second_signal ~= nil
	elements.logisitcConditionSignal2FakeChooser.caption = logisitcCondition.constant ~= nil and GetShortStringValue(logisitcCondition.constant) or 0
	elements.logisitcConditionSignal2FakeChooser.visible = not elements.logisitcConditionSignal2Chooser.visible
	tags = elements.logisitcConditionSignal2FakeChooser.tags or {}
	tags.value = logisitcCondition.constant
	elements.logisitcConditionSignal2FakeChooser.tags = tags

	ToggleCircuitLogisiticBlocksVisibility(player, entity, elements)
	
	player.opened = entityFrame
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
			elements.circuitEnableConditionFlow.visible = elements.circuitMode.enableDisableRadio.state
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
	elements.circuitMode = {}
	elements.circuitMode.noneRadio = FindElementByName(entityFrame, 'circuitModeNoneRadio')
	elements.circuitMode.enableDisableRadio = FindElementByName(entityFrame, 'circuitModeEnableDisableRadio')
	elements.circuitMode.setFilterRadio = FindElementByName(entityFrame, 'circuitModeSetFilterRadio')
	elements.circuitEnableConditionFlow = FindElementByName(entityFrame, 'circuitEnableConditionFlow')
	elements.circuitConditionSignal1Chooser = FindElementByName(entityFrame, CHOOSE_CIRCUIT_SIGNAL1_BUTTON_NAME)
	elements.circuitConditionComparatorList = FindElementByName(entityFrame, CHOOSE_CIRCUIT_COMPARATOR_BUTTON_NAME)
	elements.circuitConditionSignal2Chooser = FindElementByName(entityFrame, CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME)
	elements.circuitConditionSignal2FakeChooser = FindElementByName(entityFrame, CHOOSE_CIRCUIT_SIGNAL2_FAKE_BUTTON_NAME)

	elements.logisticFlow = FindElementByName(entityFrame, 'logisticFlow')
	elements.logisticConnectionFlow = FindElementByName(entityFrame, 'logisticConnectionFlow')
	elements.logisticConnectedLabel = FindElementByName(entityFrame, 'logisticConnectedLabel')
	elements.logisticConnectCheckbox = FindElementByName(entityFrame, LOGISITIC_CONNECT_CHECKBOX_NAME)
	elements.logisticInnerFlow = FindElementByName(entityFrame, 'logisticInnerFlow')
	elements.logisitcEnableConditionFlow = FindElementByName(entityFrame, 'logisitcEnableConditionFlow')
	elements.logisitcConditionSignal1Chooser = FindElementByName(entityFrame, CHOOSE_LOGISTIC_SIGNAL1_BUTTON_NAME)
	elements.logisitcConditionComparatorList = FindElementByName(entityFrame, CHOOSE_LOGISTIC_COMPARATOR_BUTTON_NAME)
	elements.logisitcConditionSignal2Chooser = FindElementByName(entityFrame, CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME)
	elements.logisitcConditionSignal2FakeChooser = FindElementByName(entityFrame, CHOOSE_LOGISTIC_SIGNAL2_FAKE_BUTTON_NAME)
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
	local noneRadio = innerFlow.add{type='radiobutton', tags={radiogroup='circuit'}, caption={'gui-control-behavior-modes.none'}, tooltip={'gui-control-behavior-modes.none-write-description'}, state=true, name='circuitModeNoneRadio'}
	local enDisRadio = innerFlow.add{type='radiobutton', tags={radiogroup='circuit'}, caption={'gui-control-behavior-modes.enable-disable'}, tooltip={'gui-control-behavior-modes.enable-disable-description'}, state=false, name='circuitModeEnableDisableRadio'}
	local setFilterRadio = innerFlow.add{type='radiobutton', tags={radiogroup='circuit'}, caption={'gui-control-behavior-modes.set-filters'}, tooltip={'gui-control-behavior-modes.set-filters-description'}, state=false, name='circuitModeSetFilterRadio'}
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
	local logisticFlow = root.add{type='flow', direction='vertical', name='logisticFlow'}
	local connectionFlow = logisticFlow.add{type='flow', direction='vertical', name='logisticConnectionFlow'}
	local connectedLabel = connectionFlow.add{type='label', caption={'gui-control-behavior.not-connected'}, name='logisticConnectedLabel'}
	local connectChbx = connectionFlow.add{type='checkbox', caption={'gui-control-behavior.connect'}, state=false, name=LOGISITIC_CONNECT_CHECKBOX_NAME}

	local innerFlow = logisticFlow.add{type='flow', direction='vertical', name='logisticInnerFlow'}
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
	
	name = isCircuit and CHOOSE_CIRCUIT_SIGNAL1_BUTTON_NAME or CHOOSE_LOGISTIC_SIGNAL1_BUTTON_NAME
	local leftChooser = conditionSelectorFlow.add{type='choose-elem-button', elem_type='signal', tags={enable_disable=true}, name=name, style='slot_button_in_shallow_frame'}
	name = isCircuit and CHOOSE_CIRCUIT_COMPARATOR_BUTTON_NAME or CHOOSE_LOGISTIC_COMPARATOR_BUTTON_NAME
	local comparatorList = conditionSelectorFlow.add{type='drop-down', items={'>', '<', '=', '≥', '≤', '≠'}, selected_index=2, tags={enable_disable=true}, name=name, style='circuit_condition_comparator_dropdown'}
	name = isCircuit and CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME or CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME
	local rightChooser = conditionSelectorFlow.add{type='choose-elem-button', elem_type='signal', tags={enable_disable=true}, name=name, style='slot_button_in_shallow_frame'}
	rightChooser.locked = true -- don't open default chooser window, we create our own
	-- this is needed to show constant value
	name = isCircuit and CHOOSE_CIRCUIT_SIGNAL2_FAKE_BUTTON_NAME or CHOOSE_LOGISTIC_SIGNAL2_FAKE_BUTTON_NAME
	local fakeChooser = conditionSelectorFlow.add{type='button', name=name, style='constant_button', tooltip={'gui.constant-number'}}
	fakeChooser.visible = false

	if isCircuit then
		elements.circuitEnableConditionFlow = conditionFlow
		elements.circuitConditionSignal1Chooser = leftChooser
		elements.circuitConditionComparatorList = comparatorList
		elements.circuitConditionSignal2Chooser = rightChooser
		elements.circuitConditionSignal2FakeChooser = fakeChooser
	else
		elements.logisitcEnableConditionFlow = conditionFlow
		elements.logisitcConditionSignal1Chooser = leftChooser
		elements.logisitcConditionComparatorList = comparatorList
		elements.logisitcConditionSignal2Chooser = rightChooser
		elements.logisitcConditionSignal2FakeChooser = fakeChooser
	end
end

function OpenSignalChooseWindow(player, signal, constant)
	local elements = {}
	local signalFrame = player.gui.screen[SIGNAL_FRAME_NAME]
	if signalFrame == nil then
		signalFrame = CreateSignalChooseWindow(player, elements)
	else
		elements = FetchSignalWindowElements(signalFrame)
		signalFrame.bring_to_front()
	end

	local signalGroup = signal and GetSignalGroup(signal.name) or nil
	if signalGroup then
		SelectSignalGroup(elements, signalGroup)
	end

	elements.constantText.text = tostring(constant)
	elements.constantSlider.slider_value = ConstantValueToSliderValue(tostring(constant))
end

function FetchSignalWindowElements(rootFrame)
	local elements = {}
	elements.groupsTable = FindElementByName(rootFrame, 'groupsTable')
	elements.scrollPane = FindElementByName(rootFrame, 'scrollPane')
	elements.scrollFrame = FindElementByName(rootFrame, 'scrollFrame')
	elements.constantSlider = FindElementByName(rootFrame, SIGNAL_CONSTANT_SLIDER_NAME)
	elements.constantText = FindElementByName(rootFrame, SIGNAL_CONSTANT_TEXT_NAME)
	return elements
end

function CreateSignalChooseWindow(player, elements)
	local signalFrame = player.gui.screen.add{type='frame', direction='vertical', name=SIGNAL_FRAME_NAME, style='inner_frame_in_outer_frame'}
	signalFrame.auto_center = true
	signalFrame.style.maximal_height = SIGNALS_FRAME_HEIGHT

	local titleFlow = signalFrame.add{type='flow', direction='horizontal'}
	titleFlow.drag_target = signalFrame
	titleFlow.style.horizontal_spacing = 8
	titleFlow.add{type='label', caption={'gui.select-signal'}, ignored_by_interaction=true, style='frame_title'}
	titleFlow.add{type='empty-widget', ignored_by_interaction=true, style='header_filler'}
	
	--[[
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
	]]

	titleFlow.add{
		type='sprite-button',
		name=CLOSE_BUTTON_NAME,
		style='close_button',
		sprite='utility/close_white',
		hovered_sprite='utility/close_black',
		clicked_sprite='utility/close_black',
	}

	local contentFrame = signalFrame.add{type='frame', direction='vertical', style='crafting_frame'}

	local groupsTable = contentFrame.add{type='table', name='groupsTable', column_count=SIGNALS_GROUP_ROW_SIZE, style='filter_group_table'}
	
	local wrapperFrame = contentFrame.add{type='frame', style='filter_frame'}
	local scrollPane = wrapperFrame.add{type='scroll-pane', name='scrollPane', vertical_scroll_policy='always', horizontal_scroll_policy='never', style='filter_scroll_pane_in_tab'}
	local scrollFrame = scrollPane.add{type='frame', direction='vertical', name='scrollFrame', style='filter_scroll_pane_background_frame'}

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
		local button = groupsTable.add{type='sprite-button', name=group.name, tags={type='signal-group'}, tooltip={'item-group-name.'..group.name}, style='filter_group_button_tab'}
		button.add{type='label', caption='[font=item-group][img=item-group/' .. group.name .. '][/font]'}
		button.toggled = selectedGroupName == groupName

		local signalsTable = scrollFrame.add{type='table', name=group.name, column_count=SIGNALS_ROW_SIZE, style='filter_slot_table'}
		signalsTable.visible = button.toggled
		signalsTable.style.height = signalTableHeight
		for _, subgroupSignals in pairs(groupSignals) do
			for _, signal in pairs(subgroupSignals) do
				local signalButton = signalsTable.add{type='choose-elem-button', elem_type='signal', signal=signal, tags={type='signal'}, style='slot_button'}
				signalButton.locked = true
			end
			
			local numEmptyWidgets = SIGNALS_ROW_SIZE - (#(subgroupSignals) % SIGNALS_ROW_SIZE)
			for i = 1, numEmptyWidgets do
				signalsTable.add{type='empty-widget'}
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

	elements.groupsTable = groupsTable
	elements.scrollPane = scrollPane
	elements.scrollFrame = scrollFrame
	elements.constantSlider = constantSlider
	elements.constantText = constantText

	return signalFrame
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

function SelectSignal(elements, signal)
	if elements.circuitFlow.visible then
		elements.circuitConditionSignal2Chooser.visible = true
		elements.circuitConditionSignal2Chooser.elem_value = signal
		elements.circuitConditionSignal2FakeChooser.visible = false
		elements.circuitConditionSignal2FakeChooser.caption = ''

		SetEnabledCondition(elements.circuitConditionSignal2Chooser, nil)
	end

	-- TODO: logistic
end

function SelectConstant(player, value)
	local elements = FetchEntityWindowElements(player.gui.screen[ENTITY_FRAME_NAME])
	if elements.circuitFlow.visible then
		local number = tonumber(value)
		elements.circuitConditionSignal2Chooser.visible = false
		elements.circuitConditionSignal2Chooser.elem_value = nil
		elements.circuitConditionSignal2FakeChooser.visible = true
		elements.circuitConditionSignal2FakeChooser.caption = GetShortStringValue(number)
		local tags = elements.circuitConditionSignal2FakeChooser.tags
		tags.value = number
		elements.circuitConditionSignal2FakeChooser.tags = tags
		SetEnabledCondition(elements.circuitConditionSignal2FakeChooser, number)
	end

	-- TODO: logistic
end

function CloseWindow(element)
	local name = nil
	while element ~= nil do
		if element.name == ENTITY_FRAME_NAME or element.name == SIGNAL_FRAME_NAME then
			name = element.name
			element.destroy()
			break
		end
		element = element.parent
	end
	return name
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

function ConnectToLogisiticNetwork(connect)
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

function SetCircuitMode(player, circuitMode)
	if g_SelectedEntity.type ~= 'pump' then
		return
	end

	if global.pumps[g_SelectedEntity.unit_number][2] == circuitMode then
		return
	end

	global.pumps[g_SelectedEntity.unit_number][2] = circuitMode

	player.print('Entity ' .. g_SelectedEntity.unit_number .. (circuitMode == CircuitMode.SetFilter and ' will' or ' will not') .. ' get its filter from circuit network')
end

function SetEnabledCondition(element, constantValue)
	local behavior = g_SelectedEntity.get_or_create_control_behavior()
	local circuit = behavior.circuit_condition
	if element.name == CHOOSE_CIRCUIT_SIGNAL1_BUTTON_NAME then
		circuit.condition.first_signal = element.elem_value
	elseif element.name == CHOOSE_CIRCUIT_COMPARATOR_BUTTON_NAME then
		circuit.condition.comparator = element.items[element.selected_index]
	elseif element.name == CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME then
		circuit.condition.constant = nil
		circuit.condition.second_signal = element.elem_value
	elseif element.name == CHOOSE_CIRCUIT_SIGNAL2_FAKE_BUTTON_NAME then
		circuit.condition.constant = constantValue
		circuit.condition.second_signal = nil
	end

	behavior.circuit_condition = circuit

	-- TODO: logistic
end

----------------------------------
-------- Event callbacks ---------
----------------------------------

script.on_event(defines.events.on_gui_opened, OnGuiOpened)
script.on_event('open_gui', function(event)
	local player = game.get_player(event.player_index)
	if player == nil or player.selected == nil or player.selected == g_SelectedEntity or player.cursor_stack then
		return
	end

	event.gui_type = defines.gui_type.entity
	event.entity = player.selected
	OnGuiOpened(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
	local player = game.get_player(event.player_index)
	if player == nil or g_SelectedEntity == nil then
		return
	end

	---- Signal Selection Window handling ----
	if event.element.name == SIGNAL_SET_CONSTANT_BUTTON_NAME then
		local elements = FetchSignalWindowElements(player.gui.screen[SIGNAL_FRAME_NAME])
		SelectConstant(player, elements.constantText.text)
		CloseWindow(event.element)
		return
	elseif event.element.tags then
		if event.element.tags.type == 'signal-group' then
			local elements = FetchSignalWindowElements(player.gui.screen[SIGNAL_FRAME_NAME])
			SelectSignalGroup(elements, event.element.name)
		elseif event.element.tags.type == 'signal' then
			local elements = FetchEntityWindowElements(player.gui.screen[ENTITY_FRAME_NAME])
			SelectSignal(elements, event.element.elem_value)
			CloseWindow(event.element)
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
		local closedName = CloseWindow(event.element)
		if closedName == ENTITY_FRAME_NAME then
			if player.gui.screen[SIGNAL_FRAME_NAME] then
				player.gui.screen[SIGNAL_FRAME_NAME].destroy()
			end
			g_SelectedEntity = nil
		end
	elseif event.element.name == CIRCUIT_BUTTON_NAME or event.element.name == LOGISTIC_BUTTON_NAME then
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
		local elements = FetchEntityWindowElements(player.gui.screen[ENTITY_FRAME_NAME])
		ConnectToLogisiticNetwork(event.element.state)
		FillLogisticBlock(elements, g_SelectedEntity)
		ToggleCircuitLogisiticBlocksVisibility(player, g_SelectedEntity, elements)
	elseif event.element.name == CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME or event.element.name == CHOOSE_CIRCUIT_SIGNAL2_FAKE_BUTTON_NAME or
			event.element.name == CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME or event.element.name == CHOOSE_LOGISTIC_SIGNAL2_FAKE_BUTTON_NAME then
		if event.button == defines.mouse_button_type.right then
			if event.element.type == 'choose-elem-button' then
				event.element.elem_value = nil
				SetEnabledCondition(event.element, nil)
			else
				event.element.caption = ''
			end
		else
			local signal = event.element.type == 'choose-elem-button' and event.element.elem_value or nil
			local constant = event.element.type == 'button' and event.element.tags.value or 0
			OpenSignalChooseWindow(player, signal, constant)
		end
	elseif event.element.tags and event.element.tags.radiogroup == 'circuit' then
		local elements = FetchEntityWindowElements(player.gui.screen[ENTITY_FRAME_NAME])
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
		SetCircuitMode(player, circuitMode)
		UpdateCircuit(g_SelectedEntity, circuitMode)
		FillFilterButton(elements.chooseButton, g_SelectedEntity, circuitMode == CircuitMode.SetFilter)
		ToggleCircuitLogisiticBlocksVisibility(player, g_SelectedEntity, elements)
	end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	local player = game.get_player(event.player_index)
	if player == nil or g_SelectedEntity == nil then
		return
	end

	if event.element.name == CHOOSE_FILTER_BUTTON_NAME then
		SetFilter(player, g_SelectedEntity, event.element.elem_value)
	elseif event.element.tags and event.element.tags.enable_disable then
		SetEnabledCondition(event.element, nil)
	end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	if event.element.tags and event.element.tags.enable_disable then
		SetEnabledCondition(event.element, nil)
	end
end)

script.on_event(defines.events.on_gui_confirmed, function(event)
	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	if event.element.name == SIGNAL_CONSTANT_TEXT_NAME then
		local elements = FetchSignalWindowElements(player.gui.screen[SIGNAL_FRAME_NAME])
		SelectConstant(player, tonumber(elements.constantText.text))
		CloseWindow(event.element)
	end
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	if event.element.name == SIGNAL_CONSTANT_SLIDER_NAME then
		local elements = FetchSignalWindowElements(player.gui.screen[SIGNAL_FRAME_NAME])
		elements.constantText.text = tostring(SliderValueToConstantValue(event.element.slider_value))
	end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	if event.element.name == SIGNAL_CONSTANT_TEXT_NAME then
		local elements = FetchSignalWindowElements(player.gui.screen[SIGNAL_FRAME_NAME])
		elements.constantSlider.slider_value = ConstantValueToSliderValue(event.element.text)
	end
end)

script.on_event(defines.events.on_gui_closed, function(event)
	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	if event.element and event.element.name == ENTITY_FRAME_NAME then
		if player.gui.screen[SIGNAL_FRAME_NAME] then
			player.gui.screen[SIGNAL_FRAME_NAME].destroy()
		end
		event.element.destroy()
		g_SelectedEntity = nil
	end
end)