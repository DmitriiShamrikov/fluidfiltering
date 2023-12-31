local MOD_PREFIX = 'ffm'

BUILD_INPUT_EVENT = MOD_PREFIX .. '_build'
BUILD_GHOST_INPUT_EVENT = MOD_PREFIX .. '_build_ghost'
OPEN_GUI_INPUT_EVENT = MOD_PREFIX .. '_open_gui'
FOCUS_SEARCH_INPUT_EVENT = MOD_PREFIX .. '_focus_search'

HEADER_FILLER_STYLE = MOD_PREFIX .. '_header_filler'
HORIZONTAL_FILLER_STYLE = MOD_PREFIX .. '_horizontal_filler'
SIGNAL_SEARCH_FIELD_STYLE = MOD_PREFIX .. '_signal_search_field'
LEFT_COLUMN_STYLE = MOD_PREFIX .. '_left_column'
RIGHT_COLUMN_STYLE = MOD_PREFIX .. '_right_column'
CONSTANT_BUTTON_STYLE = MOD_PREFIX .. '_constant_button'
SIGNAL_OVERLAY_STYLE = MOD_PREFIX .. '_signal_overlay'

ENTITY_FRAME_NAME = MOD_PREFIX .. '-entity'
FILTER_FRAME_NAME = MOD_PREFIX .. '-liquid-filter'
CLOSE_BUTTON_NAME = MOD_PREFIX .. '-close'
CIRCUIT_BUTTON_NAME = MOD_PREFIX .. '-circuit'
LOGISTIC_BUTTON_NAME = MOD_PREFIX .. '-logistic'
CHOOSE_FILTER_BUTTON_NAME = MOD_PREFIX .. '-liquid-filter-chooser'
CHOOSE_CIRCUIT_SIGNAL1_BUTTON_NAME = MOD_PREFIX .. '-circuit-signal1-chooser'
CHOOSE_CIRCUIT_SIGNAL1_FAKE_BUTTON_NAME = MOD_PREFIX .. '-circuit-signal1-choser-fake'
CHOOSE_CIRCUIT_COMPARATOR_BUTTON_NAME = MOD_PREFIX .. '-circuit-comparator-chooser'
CHOOSE_CIRCUIT_SIGNAL2_BUTTON_NAME = MOD_PREFIX .. '-circuit-signal2-chooser'
CHOOSE_CIRCUIT_SIGNAL2_FAKE_BUTTON_NAME = MOD_PREFIX .. '-circuit-signal2-choser-fake'
CHOOSE_CIRCUIT_SIGNAL2_CONSTANT_BUTTON_NAME = MOD_PREFIX .. '-circuit-signal-chooser-constant'
CHOOSE_LOGISTIC_SIGNAL1_BUTTON_NAME = MOD_PREFIX .. '-logistic-signal1-chooser'
CHOOSE_LOGISTIC_SIGNAL1_FAKE_BUTTON_NAME = MOD_PREFIX .. '-logistic-signal1-choser-fake'
CHOOSE_LOGISTIC_COMPARATOR_BUTTON_NAME = MOD_PREFIX .. '-logistic-comparator-chooser'
CHOOSE_LOGISTIC_SIGNAL2_BUTTON_NAME = MOD_PREFIX .. '-logistic-signal-chooser'
CHOOSE_LOGISTIC_SIGNAL2_FAKE_BUTTON_NAME = MOD_PREFIX .. '-logistic-signal2-choser-fake'
CHOOSE_LOGISTIC_SIGNAL2_CONSTANT_BUTTON_NAME = MOD_PREFIX .. '-logistic-signal-chooser-constant'
LOGISITIC_CONNECT_CHECKBOX_NAME = MOD_PREFIX .. '-logistic-connect'

SIGNAL_FRAME_NAME = MOD_PREFIX .. '-signal'
SIGNAL_OVERLAY_NAME = MOD_PREFIX .. '-signal-overlay'
SIGNAL_SEARCH_BUTTON_NAME = MOD_PREFIX .. '-search'
SIGNAL_SEARCH_FIELD_NAME = MOD_PREFIX .. '-search-field'
SIGNAL_CONSTANT_SLIDER_NAME = MOD_PREFIX .. '-signal-slider'
SIGNAL_CONSTANT_TEXT_NAME = MOD_PREFIX .. '-signal-text'
SIGNAL_SET_CONSTANT_BUTTON_NAME = MOD_PREFIX .. '-signal-set'

SIGNALS_ROW_HEIGHT = 40 -- styles.slot_button.size
SIGNALS_GROUP_ROW_SIZE = 6
SIGNALS_ROW_SIZE = 10

MAX_DELETED_ENTITIES = 100

CircuitMode =
{
	None = 0,
	EnableDisable = 1,
	SetFilter = 2
}
