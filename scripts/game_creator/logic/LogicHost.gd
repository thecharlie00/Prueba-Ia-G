# LogicHost.gd
# Une cada `mesa` (TableApi) con su editor sin que el código de los bloques pueda llegar a
# él: la API no guarda ninguna referencia propia, sólo pregunta aquí por su id.
class_name LogicHost
extends RefCounted

## Iteraciones de mesa.rango() que puede gastar un bloque en cada ejecución.
const LOOP_BUDGET := 20000

static var _editors := {}
static var _budgets := {}


static func bind(api: Object, editor: Node) -> void:
	_editors[api.get_instance_id()] = weakref(editor)
	_budgets[api.get_instance_id()] = LOOP_BUDGET


static func release(api: Object) -> void:
	_editors.erase(api.get_instance_id())
	_budgets.erase(api.get_instance_id())


static func editor_for(api: Object) -> Node:
	var ref: WeakRef = _editors.get(api.get_instance_id())
	return ref.get_ref() as Node if ref != null else null


static func reset_budget(api: Object) -> void:
	_budgets[api.get_instance_id()] = LOOP_BUDGET


## Gasta `amount` del presupuesto de bucles; devuelve cuánto se pudo gastar.
static func spend(api: Object, amount: int) -> int:
	var left: int = _budgets.get(api.get_instance_id(), 0)
	var granted := clampi(amount, 0, left)
	_budgets[api.get_instance_id()] = left - granted
	return granted
