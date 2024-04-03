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
	for uid, entry in pairs(global.pumps) do
		local pump = entry[1]
		local filter = pump.fluidbox.get_filter(1)
		game.player.print('Pump ' .. uid .. ': ' .. (pump.active and 'enabled' or 'disabled') .. (filter and (' [' .. filter.name .. ']') or '') .. (entry[2] == CircuitMode.SetFilter and '[circuit]' or ''))
	end
	game.player.print('Total: ' .. tostring(table_size(global.pumps)))
	game.player.print('========== END =========')
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
	global.pumps = QueryEntities({type='pump'}, CreatePumpEntry)

	local ids = rendering.get_all_ids('fluidfiltering')
	local icons = {}
	for _, id in pairs(ids) do
		local target = rendering.get_target(id)
		if target and target.entity then
			local pumpEntry = global.pumps[target.entity.unit_number]
			if pumpEntry then
				local sprite = rendering.get_sprite(id)
				local prefix = 'fluid/'
				local idx = sprite:sub(#prefix) == prefix and 2 or 1
				table.insert(pumpEntry[3], id, idx)
			end
		end
	end
end

function ExportSaveData()
	local data = {
		visitedSurfaces = global.visitedSurfaces,
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
		if data.visitedSurfaces then
			for key, value in pairs(data.visitedSurfaces) do
				id = tonumber(key)
				global.visitedSurfaces[id] = value
			end
			game.player.print('Imported ' .. table_size(global.visitedSurfaces) .. ' visitedSurfaces')
		end
		if data.recentlyDeletedEntities then
			global.recentlyDeletedEntities = data.recentlyDeletedEntities
			game.player.print('Imported ' .. #(global.recentlyDeletedEntities) .. ' recentlyDeletedEntities')
		end
	else
		game.player.print('Failed to parse data')
	end
end

--commands.add_command('ff.reset', nil, Clear)
commands.add_command('ff.print_pumps', nil, PrintPumps)
commands.add_command('ff.print_wagons', nil, PrintWagons)
--commands.add_command('ff.populate_pumps', nil, RepopulatePumps)
--commands.add_command('ff.export', nil, ExportSaveData)
--commands.add_command('ff.import', nil, ImportSaveData)