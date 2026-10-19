extends Control
## The one-time unlock offer: one price, everything included, no ads.

var _status: Label
var _buy: Button


func _ready() -> void:
	var col := UI.page(self, 3)
	UI.spacer(col, 40)
	UI.title(col, "Unlock the Full Game", 44)
	UI.spacer(col, 10)
	var panel := PanelContainer.new()
	col.add_child(panel)
	var box := UI.column(panel, 10)
	UI.label(box, "You've held the Borderlands. Twenty-five more levels wait beyond: the Haunted Marsh, the Dragon Peaks, three bosses, Endless mode and every Challenge.", 21)
	UI.label(box, "✓  One price, everything included\n✓  No ads, ever\n✓  No in-game currency, nothing else to buy\n✓  Family Sharing supported\n✓  Free updates with new levels", 21, Palette.GOLD)
	UI.spacer(col, 10)
	_buy = UI.button(col, "Unlock everything · %s" % IAP.price, _purchase, 84)
	UITheme.style_primary(_buy)
	UI.button(col, "Restore purchases", func() -> void:
		_status.text = "Restoring…"
		IAP.restore(), 60)
	UI.button(col, "Not now", _leave, 60)
	_status = UI.label(col, "", 20, Palette.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	IAP.purchase_finished.connect(_on_finished)
	IAP.price_known.connect(func(price: String) -> void: _buy.text = "Unlock everything · %s" % price)
	Save.set_unlock_prompt_shown()


func _purchase() -> void:
	_buy.disabled = true
	_status.text = "Contacting the App Store…"
	IAP.purchase()


func _on_finished(success: bool, message: String) -> void:
	_status.text = message
	_buy.disabled = false
	if success:
		await get_tree().create_timer(1.2).timeout
		_leave()


func _leave() -> void:
	Game.go(Game.return_to if Game.return_to in Game.SCENES else "worlds")
