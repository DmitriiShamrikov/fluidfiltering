-- pump
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

-- wagon
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

-- gui
local styles = data.raw["gui-style"].default
styles.header_filler_style = {
	type = "empty_widget_style",
	parent = "draggable_space_header",
	horizontally_stretchable = "on",
	vertically_stretchable = "on",
	height = 24
}

styles.left_column = {
	type = "vertical_flow_style",
	minimal_width = styles["wide_entity_button"].minimal_width / 2,
	horizontal_align = "left"
}

styles.right_column = {
	type = "vertical_flow_style",
	minimal_width = styles["wide_entity_button"].minimal_width / 2,
	horizontal_align = "right"
}

data:extend{{
	type = "font",
	name = "item-group",
	from = "default-semibold",
	size = 36
}}

-- input
data:extend{{
	type = "custom-input",
	name = "open_gui",
	key_sequence = "",
	linked_game_control = "open-gui"
}}
