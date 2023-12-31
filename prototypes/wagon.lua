local filterWagon = table.deepcopy(data.raw["fluid-wagon"]["fluid-wagon"])
filterWagon.name = "filter-fluid-wagon"
filterWagon.minable.result = "filter-fluid-wagon"
data:extend{filterWagon}

local filterWagonItem = table.deepcopy(data.raw["item-with-entity-data"]["fluid-wagon"])
filterWagonItem.name = "filter-fluid-wagon"
filterWagonItem.place_result = "filter-fluid-wagon"
filterWagonItem.icons = {
	{
		icon = filterWagonItem.icon,
		tint = {r=1,g=0,b=0,a=0.3}
	},
}
data:extend{filterWagonItem}

local filterWagonRecipe = table.deepcopy(data.raw["recipe"]["fluid-wagon"])
filterWagonRecipe.enabled = true
filterWagonRecipe.name = "filter-fluid-wagon"
filterWagonRecipe.result = "filter-fluid-wagon"
data:extend{filterWagonRecipe}