extends Node
## Efectos de sonido cartoon generados por código (fase 1, docs/ARTE.md): no hay archivos de
## audio que licenciar y pesan cero. Cada sonido es una envolvente corta de tonos y ruido.
## Uso: Sfx.play("grab"). Se desactiva con set_enabled(false) (opción del menú).

const RATE := 22050
const VOICES := 8
const SOUNDS := ["grab", "drop", "dice", "card", "ui", "turn", "pop"]

var enabled := true
var settings_path := "user://diceon_controls.cfg"
var streams := {}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}


func _ready() -> void:
	_load_settings()
	streams["grab"] = _tone([620.0, 880.0], 0.07, 0.35, 0.0)
	streams["drop"] = _knock(170.0, 0.11, 0.55)
	streams["dice"] = _clatter()
	streams["card"] = _swish(0.12, 0.3)
	streams["ui"] = _tone([1150.0, 1150.0], 0.03, 0.22, 0.0)
	streams["turn"] = _chime()
	streams["pop"] = _tone([500.0, 1100.0], 0.09, 0.32, 0.0)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		_players.append(player)


## Reproduce un efecto. Ignora repeticiones del mismo sonido en menos de 40 ms (una pila de
## fichas soltada a la vez no debe sonar como una ráfaga).
func play(sound: String, volume_db := 0.0) -> void:
	if not enabled or not streams.has(sound) or _players.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 40:
		return
	_last_played[sound] = now
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = streams[sound]
	player.volume_db = volume_db - 6.0
	player.pitch_scale = randf_range(0.93, 1.07)
	player.play()


func set_enabled(value: bool) -> void:
	enabled = value
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("audio", "effects", value)
	config.save(settings_path)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var saved: Variant = config.get_value("audio", "effects", true)
	if saved is bool:
		enabled = saved


# --- Síntesis -------------------------------------------------------------

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


# Tono con barrido de frecuencia (de from a to) y caída rápida: "pop", clic.
func _tone(sweep: Array, length: float, gain: float, noise: float) -> AudioStreamWAV:
	var count := int(RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var freq := lerpf(sweep[0], sweep[1], t)
		phase += TAU * freq / RATE
		var envelope := minf(t * 30.0, 1.0) * pow(1.0 - t, 2.0)
		samples[i] = (sin(phase) + randf_range(-1.0, 1.0) * noise) * envelope * gain
	return _wav(samples)


# Golpe de madera: tono grave que cae más ruido muy corto al principio.
func _knock(freq: float, length: float, gain: float) -> AudioStreamWAV:
	var count := int(RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * freq * (1.0 - t * 0.35) / RATE
		var body := sin(phase) * pow(1.0 - t, 3.0)
		var click := randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - t * 12.0)
		samples[i] = (body * 0.8 + click * 0.35) * gain
	return _wav(samples)


# Dados: tres choques cortos de plástico.
func _clatter() -> AudioStreamWAV:
	var length := 0.28
	var count := int(RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for hit in [0.0, 0.09, 0.17]:
		var start := int(hit * RATE)
		var phase := 0.0
		for i in int(RATE * 0.05):
			if start + i >= count:
				break
			var t := float(i) / (RATE * 0.05)
			phase += TAU * (1900.0 - hit * 2000.0) / RATE
			var value := (sin(phase) * 0.6 + randf_range(-1.0, 1.0) * 0.4) * pow(1.0 - t, 3.0)
			samples[start + i] += value * (0.45 - hit)
	return _wav(samples)


# Carta: soplido de ruido que sube y baja.
func _swish(length: float, gain: float) -> AudioStreamWAV:
	var count := int(RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var smooth := 0.0
	for i in count:
		var t := float(i) / count
		# Filtro paso bajo simple: un ruido más suave, como papel.
		smooth = lerpf(smooth, randf_range(-1.0, 1.0), 0.25 + t * 0.4)
		samples[i] = smooth * sin(t * PI) * gain
	return _wav(samples)


# Turno: dos notas alegres (do–sol).
func _chime() -> AudioStreamWAV:
	var note := 0.13
	var count := int(RATE * note * 2.4)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for n in 2:
		var freq: float = [784.0, 1175.0][n]
		var start := int(n * note * RATE)
		var phase := 0.0
		for i in count - start:
			var t := float(i) / (count - start)
			phase += TAU * freq / RATE
			samples[start + i] += (sin(phase) + sin(phase * 2.0) * 0.25) * pow(1.0 - t, 2.5) * 0.22
	return _wav(samples)
