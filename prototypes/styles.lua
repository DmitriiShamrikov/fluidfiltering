require('constants')

local styles = data.raw['gui-style'].default

styles[HEADER_FILLER_STYLE] = {
	type = 'empty_widget_style',
	parent = 'draggable_space_header',
	horizontally_stretchable = 'on',
	vertically_stretchable = 'on',
	height = 24
}

styles[HORIZONTAL_FILLER_STYLE] = {
	type = 'empty_widget_style',
	horizontally_stretchable = 'on',
	height = 24
}

styles[SIGNAL_SEARCH_FIELD_STYLE] = {
	type = 'textbox_style',
	parent = 'titlebar_search_textfield',
	width = styles['search_popup_textfield'].width,
}

styles[LEFT_COLUMN_STYLE] = {
	type = 'vertical_flow_style',
	minimal_width = styles['wide_entity_button'].minimal_width / 2,
	horizontal_align = 'left'
}

styles[RIGHT_COLUMN_STYLE] = {
	type = 'vertical_flow_style',
	minimal_width = styles['wide_entity_button'].minimal_width / 2,
	horizontal_align = 'right'
}

styles[CONSTANT_BUTTON_STYLE] = {
	type = 'button_style',
	parent = 'slot_button_in_shallow_frame',
	font = 'default-game',
	default_font_color = {1,1,1},
	clicked_font_color = {1,1,1},
	hovered_font_color = {1,1,1},
	disabled_font_color = {1,1,1},
	selected_font_color = {1,1,1},
	selected_hovered_font_color = {1,1,1},
	selected_clicked_font_color = {1,1,1},
	maximal_width = 62,
}

styles[SIGNAL_OVERLAY_STYLE] = {
	type = 'button_style',
	default_graphical_set = {},
	hovered_graphical_set = {},
	clicked_graphical_set = {},
	left_click_sound = {},
}
