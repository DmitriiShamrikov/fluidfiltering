local ENTITY_FRAME_NAME = 'ui-entity'
local FILTER_FRAME_NAME = 'ui-liquid-filter'
local CHOOSE_BUTTON_NAME = 'ui-liquid-filter-chooser'
local CLOSE_BUTTON_NAME = 'ui-close'
-- Unfortunately pumping from a fluid wagon doesn't seem working through fluidboxes
-- therefore fluidbox filter on a pump doesn't work in this case. As a workaround
-- I run through all pumps and disable them if there is a fluid wagon with a wrong fluid in front of them
-- Can I check that not every frame?
local PUMP_WAGON_CHECK_PERIOD = 1

local g_SelectedEntity = nil
local g_PumpConnectionsCache = {}

-- global.pumps - array of entities
-- global.wagons - array of entries, each entry is a pair of entity and a filter (string)

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
	global.pumps = QueryEntities{type='pump'}
end

function InitGlobal()
	if global.pumps == nil then
		PopulatePumps()
	end

	if global.wagons == nil then
		global.wagons = {}
	end
end

function OnEntityBuilt(event)
	RegisterPump(event.created_entity)
	if event.tags then
		local filter = event.tags['filter']
		if filter then
			event.created_entity.fluidbox.set_filter(1, {name=filter, force=true})

			local player = game.get_player(event.player_index)
			if player ~= nil then
				player.print('Setting filter for entity ' .. event.created_entity.unit_number .. ': ' .. filter)
			end
		end
	end
end

function RegisterPump(entity)
	global.pumps[entity.unit_number] = entity
	script.register_on_entity_destroyed(entity)
end

function UnregisterEntity(uid)
	global.wagons[uid] = nil
	global.pumps[uid] = nil
	g_PumpConnectionsCache[uid] = nil
end

function OnSettingsPasted(event)
	if event.source.type == 'pump' and event.destination.name == 'filter-pump' then
		-- that shouldn't noramlly happen, just being extra careful
		if global.pumps[event.source.unit_number] == nil then
			global.pumps[event.source.unit_number] = event.source
		end
		if global.pumps[event.destination.unit_number] == nil then
			global.pumps[event.destination.unit_number] = event.destination
		end

		local filter = event.source.fluidbox.get_filter(1)
		if filter then
			filter.force = true
		end
		event.destination.fluidbox.set_filter(1, filter)
	elseif event.source.type == 'fluid-wagon' and event.destination.name == 'filter-fluid-wagon' then
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
			local filter = entity.fluidbox.get_filter(1)
			if filter then
				bp.set_blueprint_entity_tag(bpIndex, 'filter', filter.name)
			end
		end
	end
end

------- UI ------

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
	local entityFrame = player.gui.screen[ENTITY_FRAME_NAME]
	local title = nil
	local preview = nil
	local chooseButton = nil
	local statusSprite = nil
	local statusText = nil
	if entityFrame == nil then
		entityFrame = player.gui.screen.add{type='frame', name=ENTITY_FRAME_NAME}
		entityFrame.auto_center = true

		local mainFlow = entityFrame.add{type='flow', direction='vertical'}

		local titleFlow = mainFlow.add{type='flow', direction='horizontal'}
		titleFlow.drag_target = entityFrame
		titleFlow.style.horizontal_spacing = 12
		title = titleFlow.add{type='label', ignored_by_interaction=true, style='frame_title'}
		titleFlow.add{type='empty-widget', ignored_by_interaction=true, style='header_filler_style'}
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
		statusSprite = statusFlow.add{type='sprite'}
		statusText = statusFlow.add{type='label'}

		local previewContainer = contentFlow.add{type='frame', style='slot_container_frame'}
		previewContainer.style.bottom_margin = 4
		preview = previewContainer.add{type='entity-preview', style='wide_entity_button'}

		local label = contentFlow.add{type='label', caption='Filter:', style='bold_label'}
		label.style.top_margin = 4
		chooseButton = contentFlow.add{type='choose-elem-button', name=CHOOSE_BUTTON_NAME, elem_type='fluid'}
	else
		--      entityFrame/mainFlow/titleFlow/title
		title = entityFrame.children[1].children[2].children[1]

		--        entityFrame/mainFlow/contentFrame/contentFlow/previewContainer/preview
		preview = entityFrame.children[1].children[2].children[1].children[2].children[1]

		--             entityFrame/mainFlow/contentFrame/contentFlow/chooseButton
		chooseButton = entityFrame.children[1].children[2].children[1].children[4]

		--             entityFrame/mainFlow/contentFrame/contentFlow/statusFlow/statusSprite
		statusSprite = entityFrame.children[1].children[2].children[1].children[1].children[1]

		--           entityFrame/mainFlow/contentFrame/contentFlow/statusFlow/statusText
		statusText = entityFrame.children[1].children[2].children[1].children[1].children[2]
	end

	title.caption = entity.localised_name
	preview.entity = entity

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

local entityFilters = {{filter='type', type='pump'}}
script.on_event(defines.events.on_built_entity, OnEntityBuilt, entityFilters)
script.on_event(defines.events.on_robot_built_entity, OnEntityBuilt, entityFilters)

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
	end
end)

script.on_event(defines.events.on_gui_closed, function(event)
	if event.element and event.element.name == ENTITY_FRAME_NAME then
		event.element.destroy()
		g_SelectedEntity = nil
	end
end)

script.on_event(defines.events.on_entity_destroyed, function(event)
	if event.unit_number ~= nil then
		UnregisterEntity(event.unit_number)
	end
end)

script.on_event(defines.events.on_player_rotated_entity, function(event)
	g_PumpConnectionsCache[event.entity.unit_number] = nil
end)

script.on_event(defines.events.on_entity_settings_pasted, OnSettingsPasted)
script.on_event(defines.events.on_player_setup_blueprint, OnBlueprintSelected)

-- debug stuff

function Clear()
	global.pumps = {}
	game.player.print('Pumps are cleared')

	global.wagons = {}
	game.player.print('Wagons are cleared')

	g_PumpConnectionsCache = {}
	game.player.print('Cache is cleared')
end

function PrintPumps()
	game.player.print('=== Registered pumps ===')
	for uid, pump in pairs(global.pumps) do
		local filter = pump.fluidbox.get_filter(1)
		game.player.print('Pump ' .. uid .. ': ' .. (pump.active and 'enabled' or 'disabled') .. (filter and (' [' .. filter.name .. ']') or ''))
	end
	game.player.print('========== END =========')
end

function PrintWagons()
	game.player.print('=== Registered wagons ===')
	for uid, wagonEntry in pairs(global.wagons) do
		local filter = wagonEntry[2]
		game.player.print('Wagon ' .. uid .. ': ' .. (filter or 'none'))
	end
	game.player.print('========== END =========')
end

commands.add_command('ff.reset', nil, Clear)
commands.add_command('ff.print_pumps', nil, PrintPumps)
commands.add_command('ff.print_wagons', nil, PrintWagons)
commands.add_command('ff.populate_pumps', nil, PopulatePumps)

--[[

tests:

-- vanilla stuff
water: pipe -> pump               -> pipe        | yes
water: pipe -> pump               -> fluid-wagon | yes
water: fluid-wagon -> pump        -> pipe        | yes

-- filter-pump with vanilla stuff
water: pipe -> filter-pump[water] -> pipe        | yes
steam: pipe -> filter-pump[water] -> pipe        | no
water: pipe -> filter-pump[]      -> pipe        | yes
steam: pipe -> filter-pump[]      -> pipe        | yes
water: tank -> filter-pump[water] -> pipe        | yes
steam: tank -> filter-pump[water] -> pipe        | no
water: pipe -> filter-pump[water] -> tank        | yes
steam: pipe -> filter-pump[water] -> tank        | no

-- filter-pump with vanilla wagons 
water: fluid-wagon -> filter-pump[water] -> pipe | yes
steam: fluid-wagon -> filter-pump[water] -> pipe | no
water: fluid-wagon -> filter-pump[]      -> pipe | yes
steam: fluid-wagon -> filter-pump[]      -> pipe | yes
water: pipe -> filter-pump[water] -> fluid-wagon | yes
steam: pipe -> filter-pump[water] -> fluid-wagon | no
water: pipe -> filter-pump[]      -> fluid-wagon | yes
steam: pipe -> filter-pump[]      -> fluid-wagon | yes

-- filter-fluid-wagon with vanilla stuff
water: pipe -> pump -> filter-fluid-wagon[]      | yes
water: pipe -> pump -> filter-fluid-wagon[water] | yes
steam: pipe -> pump -> filter-fluid-wagon[water] | no
water: filter-fluid-wagon[] -> pump -> pipe      | yes
water: filter-fluid-wagon[water] -> pump -> pipe | yes

-- filter-pumps with filter-fluid-wagons
water: filter-fluid-wagon[]      -> filter-pump[water] -> pipe | yes
steam: filter-fluid-wagon[]      -> filter-pump[water] -> pipe | no
water: filter-fluid-wagon[]      -> filter-pump[]      -> pipe | yes
steam: filter-fluid-wagon[]      -> filter-pump[]      -> pipe | yes
water: filter-fluid-wagon[water] -> filter-pump[water] -> pipe | yes
steam: filter-fluid-wagon[steam] -> filter-pump[water] -> pipe | no
water: filter-fluid-wagon[water] -> filter-pump[]      -> pipe | yes
steam: filter-fluid-wagon[steam] -> filter-pump[]      -> pipe | yes

]]