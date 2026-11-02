extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	var dice: Dice3D = main.get_node("Objects/Dice")
	var card: Card3D = main.get_node("Objects/Card")
	var deck: Deck3D = main.get_node("Objects/Deck")
	if dice.top_face() != 1:
		_fail("El dado con orientación inicial debe mostrar 1.")
		return
	dice.freeze = true
	dice.quaternion = Quaternion(Vector3.FORWARD, PI)
	if dice.top_face() != 6:
		_fail("El dado invertido debe mostrar 6.")
		return
	dice.freeze = false
	if not _check_deck(main, deck):
		return
	card.flip()
	if not card.freeze:
		_fail("La carta debería congelarse durante el volteo.")
		return
	await create_timer(card.flip_duration + 0.1).timeout
	if card.freeze:
		_fail("La carta debe recuperar sus físicas después del volteo.")
		return
	print("Smoke test OK")
	quit(0)


func _check_deck(main: Node, deck: Deck3D) -> bool:
	var count := main.get_node("Objects").get_child_count()
	deck.draw_card()
	if deck.cards_remaining != 11 or main.get_node("Objects").get_child_count() != count + 1:
		_fail("El mazo no ha creado una carta correctamente.")
		return false
	var drawn: Card3D = main.get_node("Objects").get_child(count) as Card3D
	if drawn == null or drawn.card_label != "12":
		_fail("La carta robada debe conservar su identidad.")
		return false
	var before: Array[String] = deck._cards.duplicate()
	deck.shuffle_deck()
	var after: Array[String] = deck._cards.duplicate()
	before.sort()
	after.sort()
	if before != after or deck.cards_remaining != 11:
		_fail("Mezclar no debe crear ni eliminar cartas.")
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
