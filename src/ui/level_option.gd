extends OptionButton

## An OptionButton that can also be changed with the arrow keys while it
## is focused and closed.
##
## A plain OptionButton only changes its value through the popup. That
## leaves the keyboard path in two pieces: you have to open the popup
## (Enter or Space), move the highlight, and confirm. It is worse than
## that when the popup was opened with the mouse: the highlight starts on
## "no item", so the first arrow press lands on the first entry instead
## of moving one step from the current value.
##
## With this, a focused dropdown responds to Up and Down directly, so a
## player can step through the values without opening anything. Enter and
## Space still open the popup for a labelled choice.

## Emitted when the value changes, with the new index. Mirrors the
## inherited `item_selected` signal so existing handlers need no change.
signal level_changed(index: int)


func _init() -> void:
	focus_mode = Control.FOCUS_ALL


func _gui_input(event: InputEvent) -> void:
	# While the popup is open the popup owns the arrow keys.
	if get_popup().visible:
		return
	var step := 0
	if event.is_action_pressed("ui_down", true):
		step = 1
	elif event.is_action_pressed("ui_up", true):
		step = -1
	if step == 0:
		return
	accept_event()
	var next: int = clampi(selected + step, 0, item_count - 1)
	if next == selected:
		return
	select(next)
	item_selected.emit(next)
	level_changed.emit(next)
