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

function RepopulatePumps()
	global.pumps = QueryEntities({type='pump'}, function(entity) return {entity, CircuitMode.None, {}} end)

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

commands.add_command('ff.reset', nil, Clear)
commands.add_command('ff.print_pumps', nil, PrintPumps)
commands.add_command('ff.print_wagons', nil, PrintWagons)
commands.add_command('ff.populate_pumps', nil, RepopulatePumps)