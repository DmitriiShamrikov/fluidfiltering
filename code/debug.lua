local dictionary = require("__flib__.dictionary-lite")

function Clear()
	global.pumps = {}
	global.wagons = {}
	global.guiState = {}
	global.openedEntities = {}
	global.recentlyDeletedEntities = {}

	g_PumpConnectionsCache = {}
end

function PrintPumps()
	if global.pumps then
		game.player.print('=== Registered pumps ===')
		for uid, entry in pairs(global.pumps) do
			local pump = entry[1]
			local filter = pump.fluidbox.get_filter(1)
			game.player.print('Pump ' .. uid .. ': ' .. (pump.active and 'enabled' or 'disabled') .. (filter and (' [' .. filter.name .. ']') or '') .. (entry[2] == CircuitMode.SetFilter and '[circuit]' or ''))
		end
		game.player.print('Total: ' .. tostring(table_size(global.pumps)))
		game.player.print('========== END =========')
	end
end

function PrintWagons()
	game.player.print('=== Registered wagons ===')
	for uid, wagonEntry in pairs(global.wagons) do
		local filter = wagonEntry[2]
		game.player.print('Wagon ' .. uid .. ': ' .. (filter or 'none'))
	end
	game.player.print('Total: ' .. tostring(table_size(global.wagons)))
	game.player.print('========== END =========')
end

function RepopulatePumps()
	local ids = rendering.get_all_ids('fluidfiltering')
	local icons = {}
	for _, id in pairs(ids) do
		local target = rendering.get_target(id)
		if target and target.entity then
			local sprite = rendering.get_sprite(id)
			local prefix = 'fluid/'
			local idx = sprite:sub(1, #prefix) == prefix and 2 or 1

			local uid = target.entity.unit_number
			icons[uid] = icons[uid] or {}
			icons[uid][idx] = id
		end
	end

	local missingPumpsNum = 0
	local mismatchedIconPumps = 0
	global.pumps = global.pumps or {}
	for name, surface in pairs(game.surfaces) do
		local entities = surface.find_entities_filtered{area=nil, type='pump'}
		for _, entity in ipairs(entities) do
			local entry = global.pumps[entity.unit_number]
			if entry == nil then
				entry = CreatePumpEntry(entity)
				entry[3] = icons[entity.unit_number] or {}
				UpdateFilterIcon(entity, entry)
				global.pumps[entity.unit_number] = entry
				missingPumpsNum = missingPumpsNum + 1
			elseif icons[entity.unit_number] then
				local shouldUpdateIcons = false
				local iconEntry = icons[entity.unit_number]
				for i = 1,2 do
					if iconEntry[i] ~= entry[3][i] then
						if entry[3][i] then
							if iconEntry[i] then
								rendering.destroy(iconEntry[i])
								shouldUpdateIcons = true
							end
						else
							entry[3][i] = iconEntry[i]
							shouldUpdateIcons = true
						end
					end
				end
				if shouldUpdateIcons then
					UpdateFilterIcon(entity, entry)
					mismatchedIconPumps = mismatchedIconPumps + 1
				end
			end
		end
	end

	if missingPumpsNum > 0 then
		game.player.print('Found ' .. tostring(missingPumpsNum) .. ' missing pumps')
	end

	if mismatchedIconPumps > 0 then
		game.player.print('Updated icons for ' .. tostring(mismatchedIconPumps) .. ' pumps')
	end
end

function ExportSaveData()
	local data = {
		pumps = global.pumps,
		wagons = global.wagons,
		openedEntities = global.openedEntities,
		recentlyDeletedEntities = global.recentlyDeletedEntities
	}

	game.write_file('savedata.json', game.table_to_json(data))
end

function ImportSaveData(cmd)
	if cmd.parameter == nil or cmd.parameter == '' then
		game.player.print('No data provided')
		return
	end

	game.player.print('Received ' .. #(cmd.parameter) .. ' bytes of data')

	local data = game.json_to_table(cmd.parameter)
	if data then
		local entities = {}
		local numSurfaces = 0
		for name, surface in pairs(game.surfaces) do
			local surfEntities = surface.find_entities()
			for idx, ent in pairs(surfEntities) do
				if ent and ent.unit_number then
					entities[ent.unit_number] = ent
				end
			end
			numSurfaces = numSurfaces + 1
		end

		game.player.print('Searching through ' .. table_size(entities) .. ' entities on ' .. numSurfaces .. ' surfaces')

		if data.pumps then
			for key, value in pairs(data.pumps) do
				uid = tonumber(key)
				if entities[uid] then
					global.pumps[uid] = {entities[uid], value[2], value[3]}
				else
					game.player.print('Pump ' .. uid .. ' is not found!')
				end
			end
			game.player.print('Imported ' .. table_size(global.pumps) .. ' pumps')
		end
		if data.wagons then
			for key, value in pairs(data.wagons) do
				uid = tonumber(key)
				if entities[uid] then
					global.wagons[uid] = {entities[uid], value[2]}
				else
					game.player.print('Wagon ' .. uid .. ' is not found!')
				end
			end
			game.player.print('Imported ' .. table_size(global.wagons) .. ' wagons')
		end
		if data.openedEntities then
			for key, value in pairs(data.openedEntities) do
				if table_size(value.players) > 0 then
					uid = tonumber(key)
					if entities[uid] then
						global.openedEntities[uid] = value
					else
						game.player.print('Entity ' .. uid .. ' is not found!')
					end
				end
			end
			game.player.print('Imported ' .. table_size(global.openedEntities) .. ' openedEntities')
		end
		if data.recentlyDeletedEntities then
			global.recentlyDeletedEntities = data.recentlyDeletedEntities
			game.player.print('Imported ' .. #(global.recentlyDeletedEntities) .. ' recentlyDeletedEntities')
		end
	else
		game.player.print('Failed to parse data')
	end
end

function RefreshLocale()
	dictionary.on_init()
	RequestLocalizedSignalNames()
end

--commands.add_command('ff.reset', nil, Clear)
commands.add_command('ff.print_pumps', nil, PrintPumps)
commands.add_command('ff.print_wagons', nil, PrintWagons)
commands.add_command('ff.repopulate_pumps', nil, RepopulatePumps)
commands.add_command('ff.refresh_locale', nil, RefreshLocale)
--commands.add_command('ff.export', nil, ExportSaveData)
--commands.add_command('ff.import', nil, ImportSaveData)