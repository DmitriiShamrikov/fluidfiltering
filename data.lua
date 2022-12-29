local filterPump = table.deepcopy(data.raw["pump"]["pump"])
--print(serpent.block(filterPump))
filterPump.name = "filter-pump"
filterPump.minable.result = "filter-pump"
data:extend{filterPump}


local filterPumpItem = table.deepcopy(data.raw["item"]["pump"])
--print(serpent.block(filterPumpItem))
--[[
{
  icon = "__base__/graphics/icons/pump.png",
  icon_mipmaps = 4,
  icon_size = 64,
  name = "pump",
  order = "b[pipe]-c[pump]",
  place_result = "pump",
  stack_size = 50,
  subgroup = "energy-pipe-distribution",
  type = "item"
}
]]
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
--print(serpent.block(filterPumpRecipe))
--[[
{
  enabled = false,
  energy_required = 2,
  ingredients = {
    {
      "engine-unit",
      1
    },
    {
      "steel-plate",
      1
    },
    {
      "pipe",
      1
    }
  },
  name = "pump",
  result = "pump",
  type = "recipe"
}
]]
filterPumpRecipe.enabled = true
filterPumpRecipe.name = "filter-pump"
filterPumpRecipe.result = "filter-pump"
data:extend{filterPumpRecipe}
