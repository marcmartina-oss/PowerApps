extends Node
## Autoload "IAP": the single non-consumable "Full Game" unlock.
##
## On iOS this talks to the StoreKit plugin from godot-ios-plugins (singleton
## "InAppStore"). Anywhere the plugin is missing (editor, desktop, tests) the
## purchase is simulated so the whole flow can be exercised. Google Play Billing
## slots in the same way for the Android build.

signal purchase_finished(success: bool, message: String)
signal price_known(price: String)

const PRODUCT_ID := "com.neuralseek.mazekeep.fullgame"
const FALLBACK_PRICE := "$4.99"

var price := FALLBACK_PRICE
var _store: Object


func _ready() -> void:
	if Engine.has_singleton("InAppStore"):
		_store = Engine.get_singleton("InAppStore")
		_store.set_auto_finish_transaction(true)
		_store.request_product_info({"product_ids": [PRODUCT_ID]})
		set_process(true)
	else:
		set_process(false)


func is_unlocked() -> bool:
	return Save.is_purchased()


func purchase() -> void:
	if _store:
		_store.purchase({"product_id": PRODUCT_ID})
	else:
		# Simulated store: succeed after a short delay so the UI shows its busy state.
		await get_tree().create_timer(0.6).timeout
		Save.set_purchased(true)
		purchase_finished.emit(true, "Thank you! The full game is unlocked.")


func restore() -> void:
	if _store:
		_store.restore_purchases()
	else:
		await get_tree().create_timer(0.4).timeout
		var had := Save.is_purchased()
		purchase_finished.emit(had, "Purchases restored." if had else "No previous purchase found.")


## Drains StoreKit events delivered by the plugin.
func _process(_delta: float) -> void:
	while _store.get_pending_event_count() > 0:
		var event: Dictionary = _store.pop_pending_event()
		match event.get("type", ""):
			"product_info":
				if event.get("result") == "ok" and not event.get("localized_prices", []).is_empty():
					price = event.localized_prices[0]
					price_known.emit(price)
			"purchase":
				if event.get("result") == "ok":
					Save.set_purchased(true)
					purchase_finished.emit(true, "Thank you! The full game is unlocked.")
				else:
					purchase_finished.emit(false, "Purchase did not complete.")
			"restore":
				if event.get("result") == "ok" and event.get("product_id") == PRODUCT_ID:
					Save.set_purchased(true)
					purchase_finished.emit(true, "Purchases restored.")
			"restore_completed":
				if not Save.is_purchased():
					purchase_finished.emit(false, "No previous purchase found.")
