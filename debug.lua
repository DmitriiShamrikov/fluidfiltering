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
		game.player.print('Pump ' .. uid .. ': ' .. (pump.active and 'enabled' or 'disabled') .. (filter and (' [' .. filter.name .. ']') or '') .. (entry[2] and '[circuit]' or ''))
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
	global.pumps = QueryEntities({type='pump'}, function(entity) return {entity, false} end)
end

commands.add_command('ff.reset', nil, Clear)
commands.add_command('ff.print_pumps', nil, PrintPumps)
commands.add_command('ff.print_wagons', nil, PrintWagons)
commands.add_command('ff.populate_pumps', nil, RepopulatePumps)