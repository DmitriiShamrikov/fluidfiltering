require('constants')

-- this is a way to define if an entity should support filters
-- since we can't add any new fields to prototypes, hijack order field
-- make all pumps and fluid wagons support filters by default

function MakeFiltering(table)
	for name, entity in pairs(table) do
		if entity.minable then
			local results = {name}
			if entity.minable.results and #(entity.minable.results) > 0 then
				for _, result in pairs(entity.minable.results) do
					table.insert(results, result.name)
				end
			elseif entity.minable.result then
				results = {entity.minable.result}
			end
			for _, result in pairs(results) do
				local item = data.raw['item'][result] or data.raw['item-with-entity-data'][result]
				if item then
					item.order = item.order .. ORDER_FILTER_SUFFIX
				else
					log('Item "' .. result .. '" not found!')
				end
			end
		end
	end
end

MakeFiltering(data.raw['pump'])
MakeFiltering(data.raw['fluid-wagon'])
