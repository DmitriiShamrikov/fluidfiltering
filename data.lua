local filterPump = table.deepcopy(data.raw["pump"]["pump"])
filterPump.name = "filter-pump"
filterPump.minable.result = "filter-pump"
data:extend{filterPump}

local filterPumpItem = table.deepcopy(data.raw["item"]["pump"])
filterPumpItem.name = "filter-pump"
filterPumpItem.place_result = "filter-pump"
filterPumpItem.icons = {
	{
		icon = filterPumpItem.icon,
		tint = {r=1,g=0,b=0,a=0.3}
	},
}
data:extend{filterPumpItem}

local filterPumpRecipe = table.deepcopy(data.raw["recipe"]["pump"])
filterPumpRecipe.enabled = true
filterPumpRecipe.name = "filter-pump"
filterPumpRecipe.result = "filter-pump"
data:extend{filterPumpRecipe}
