extends Node
## Walks one game through every screen and saves a screenshot of each to the folder given by --flow=DIR: the title,
## the coast, a cast and a fight, the town, the market, the board, the shore, a pond, the garum works, the map and the
## logbook. Run with: --path game -- --flow=DIR --no-save


func _ready() -> void:
	_walk.call_deferred()


func _walk() -> void:
	var dir := Dev.get_arg("flow", "user://flow")
	DirAccess.make_dir_recursive_absolute(dir)
	Game.demo_state()
	await _go("title", {}, dir, "01_title")
	await _go("coast", {"place": "harbour", "boat_x": 300.0}, dir, "02_coast")
	var coast: Node = Nav.current
	coast._demo = true
	await _wait(5.0)
	await _shot(dir, "03_cast")
	for i in 180:
		await _wait(0.5)
		if coast.line_state() == "fighting":
			await _shot(dir, "04_fight")
			break
	for i in 40:
		await _wait(0.5)
		if CatchCard.is_open():
			await _shot(dir, "05_catch")
			break
	await _go("town", {}, dir, "06_town")
	ShopPanel.market()
	await _shot(dir, "07_market")
	BoardPanel.open()
	await _shot(dir, "08_board")
	Ui.close_window()
	await _go("shore", {}, dir, "09_shore")
	PondPanel.open(0, Nav.current.views[0])
	await _shot(dir, "10_pond")
	GarumPanel.open()
	await _shot(dir, "11_garum")
	Ui.close_window()
	await _go("map", {}, dir, "12_map")
	LogbookPanel.open(0)
	await _shot(dir, "13_logbook")
	print("FLOW DONE ", dir)
	get_tree().quit()


func _go(screen: String, args: Dictionary, dir: String, name: String) -> void:
	Nav.go(screen, args)
	await _wait(1.6)
	await _shot(dir, name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot ", name)
