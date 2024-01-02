require('constants')

function InsertEffects(tech, items)
	for name, proto in pairs(items) do
		if proto.place_result then
			local isPump = data.raw['pump'][proto.place_result] ~= nil
			local isFluidWagon = data.raw['fluid-wagon'][proto.place_result] ~= nil
			if isPump or isFluidWagon then
				table.insert(tech.effects, {
					type = 'give-item',
					item = name
				})
			end
		end
	end
end

if data.raw['technology'][DUMMY_TECH_NAME] then
	log('ERROR: dummy technology ' .. DUMMY_TECH_NAME .. ' is already defined!')
else
	-- Create a dummy hidden technology with the list of (all pumps and fluid wagons by default for this mod)
	-- prototypes which should support the features of this mod
	-- This is a mechanism intended to exclude some of the target entities
	-- if deemed necessary by this or other mods

	local dummyTech = {
		type = 'technology',
		name = DUMMY_TECH_NAME,
		hidden = true,
		effects = {},

		-- this is just mandatory data to make the game not complain
		icon_size = 256, icon_mipmaps = 4,
		icon = "__base__/graphics/technology/advanced-electronics.png",
		unit = {
			time = 1,
			count = 1,
			ingredients = {},
		},
	}

	InsertEffects(dummyTech, data.raw['item'])
	InsertEffects(dummyTech, data.raw['item-with-entity-data'])

	data:extend{dummyTech}
end