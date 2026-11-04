class_name SaveCodecs
extends RefCounted


static func chess(record: Variant) -> Variant:
	var rules := ChessRules.new()
	return rules if rules.import_record(record) else null


static func checkers(record: Variant) -> Variant:
	var rules := CheckersRules.new()
	return rules if rules.import_record(record) else null


static func domino(record: Variant) -> Variant:
	var rules := DominoRules.new()
	return rules if rules.import_record(record) else null


static func island(record: Variant) -> Variant:
	return IslandRules.from_record(record)


static func ludo(record: Variant) -> Variant:
	return LudoRules.from_record(record)
