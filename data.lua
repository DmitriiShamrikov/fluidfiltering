require('constants')

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
styles.header_filler = {
	type = "empty_widget_style",
	parent = "draggable_space_header",
	horizontally_stretchable = "on",
	vertically_stretchable = "on",
	height = 24
}

styles.horizontal_filler = {
	type = "empty_widget_style",
	horizontally_stretchable = "on",
	height = 24
}

styles.signal_search_field = {
	type = "textbox_style",
	parent = "titlebar_search_textfield",
	width = styles["search_popup_textfield"].width,
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

styles.constant_button = {
	type = "button_style",
	parent = "slot_button_in_shallow_frame",
	font = "default-game",
	default_font_color = {1,1,1},
	clicked_font_color = {1,1,1},
	hovered_font_color = {1,1,1},
	disabled_font_color = {1,1,1},
	selected_font_color = {1,1,1},
	selected_hovered_font_color = {1,1,1},
	selected_clicked_font_color = {1,1,1},
	maximal_width = 62,
}

styles.signal_overlay = {
	type = "button_style",
	default_graphical_set = {},
	hovered_graphical_set = {},
	clicked_graphical_set = {},
	left_click_sound = {},
}

-- input
data:extend{{
	type = "custom-input",
	name = OPEN_GUI_INPUT_EVENT,
	key_sequence = "",
	linked_game_control = "open-gui"
},
{
	type = "custom-input",
	name = FOCUS_SEARCH_INPUT_EVENT,
	key_sequence = "",
	linked_game_control = "focus-search"
},
{
	type = "custom-input",
	name = BUILD_INPUT_EVENT,
	key_sequence = "",
	linked_game_control = "build"
},
{
	type = "custom-input",
	name = BUILD_GHOST_INPUT_EVENT,
	key_sequence = "",
	linked_game_control = "build-ghost"
}}