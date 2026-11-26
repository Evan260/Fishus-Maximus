extends Node
## A phone's reminders through the native SlowSundayPhone plugin, as Farmus Maximus sends them: as the phone puts the
## game away it schedules what `PhoneNotices` plans, and cancels them all when the game comes back, so none is sent
## while it is open. Nothing is sent until the player taps Allow on the Notifications tab. Without the plugin, as on
## every computer, every call does nothing.

const SINGLETON := "SlowSundayPhone"

var _phone: Object = null
## Set while the game is put away, when every save plans the reminders again from what it wrote.
var _away := false


func _ready() -> void:
	if Engine.has_singleton(SINGLETON):
		_phone = Engine.get_singleton(SINGLETON)
		# Reminders left from a game the phone closed while it was put away are out of date once it opens again.
		cancel_all()
	Saves.saved.connect(func() -> void: if _away: _schedule())


func _notification(what: int) -> void:
	# A game that has only lost the focus, under the notification shade or beside another app, is still on screen.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		put_away()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		came_back()


## Whether reminders can be sent: an Android build with the plugin, or a computer previewing a phone; an iPhone has no
## plugin for them yet.
func can_remind() -> bool:
	return _phone != null or not OS.has_feature("mobile")


func put_away() -> void:
	if _phone == null:
		return
	_away = true
	_schedule()


func came_back() -> void:
	if _phone == null:
		return
	_away = false
	cancel_all()
	# The phone's own question about notifications may just have been answered.
	SettingsPanel.refresh()


## The reminders for the game being played, as it stands now: none before the player allows them.
func notices() -> Array:
	if not Settings.reminders or not Game.away_counts():
		return []
	return PhoneNotices.plan(Game.to_dict(), Settings.remind_pots, Settings.remind_boat)


func _schedule() -> void:
	cancel_all()
	for n in notices():
		_phone.call("schedule", n["id"], ceilf(float(n["seconds"])), n["title"], n["text"])


func cancel_all() -> void:
	if _phone:
		_phone.call("cancel_all")


func notifications_allowed() -> bool:
	return _phone != null and bool(_phone.call("notifications_allowed"))


## Turns the reminders on and asks the phone's own question about notifications, which a phone told no stops asking.
func allow() -> void:
	Settings.set_value("reminders", true)
	if _phone:
		_phone.call("request_notifications")


func open_notification_settings() -> void:
	if _phone:
		_phone.call("open_notification_settings")
