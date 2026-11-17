# TimerComponent.gd
# Reloj con cuenta atrás: se puede arrancar, parar, reiniciar y consultar el tiempo restante.
# Guardable y rebobinable con la mesa.
class_name TimerComponent
extends BehaviorComponent

@export var label: String = "Reloj"
@export var duration_seconds: float = 60.0
@export var running: bool = false
@export var time_left: float = 60.0
@export var on_finish_message: String = "¡Tiempo agotado!"

var _elapsed_at_pause: float = 0.0
var _last_tick: float = 0.0

func _serialize_extra(data: Dictionary) -> void:
	data["label"] = label
	data["duration_seconds"] = duration_seconds
	data["running"] = running
	data["time_left"] = time_left
	data["on_finish_message"] = on_finish_message

func _deserialize_extra(data: Dictionary) -> void:
	label = str(data.get("label", label))
	duration_seconds = clampf(float(data.get("duration_seconds", duration_seconds)), 0.0, 3600.0)
	running = data.get("running", running) == true
	time_left = clampf(float(data.get("time_left", time_left)), 0.0, duration_seconds)
	on_finish_message = str(data.get("on_finish_message", on_finish_message))
	_elapsed_at_pause = 0.0
	_last_tick = Time.get_ticks_msec()

## Arranca la cuenta atrás (o la reanuda si estaba en pausa).
func start() -> void:
	running = true
	_last_tick = Time.get_ticks_msec()

## Para la cuenta atrás (la deja en pausa).
func stop() -> void:
	running = false

## Reinicia el temporizador a su duración completa.
func reset() -> void:
	time_left = duration_seconds
	running = false
	_elapsed_at_pause = 0.0

## Pone el temporizador a cero.
func zero() -> void:
	time_left = 0.0
	running = false

## Avanza el temporizador (debe llamarse cada frame mientras se prueba).
func _process_timer(delta: float) -> bool:
	if not running or time_left <= 0.0:
		return false
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		running = false
		return true  # terminó
	return false

## Devuelve true si el temporizador llegó a cero.
func finished() -> bool:
	return time_left <= 0.0 and not running

## Devuelve el tiempo restante en segundos.
func remaining() -> float:
	return maxf(0.0, time_left)

## Devuelve el tiempo restante como texto "MM:SS".
func remaining_text() -> String:
	var total := maxf(0.0, int(time_left))
	var minutos := int(total / 60)
	var segundos := int(total) % 60
	return "%02d:%02d" % [minutos, segundos]
