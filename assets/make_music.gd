extends SceneTree
# Original, synthesized placeholder music. No external recordings are used.
func _initialize() -> void:
	var sample_rate := 22050
	var duration := 16.0
	var samples := int(sample_rate * duration)
	var chords := [[110.0,130.81,164.81],[98.0,123.47,146.83],[87.31,110.0,130.81],[98.0,123.47,146.83],[110.0,130.81,164.81],[130.81,164.81,196.0],[116.54,146.83,174.61],[98.0,123.47,146.83]]
	var lead := [220.0,261.63,329.63,261.63, 246.94,293.66,369.99,293.66, 220.0,261.63,349.23,261.63, 196.0,246.94,293.66,246.94, 220.0,261.63,329.63,392.0, 261.63,329.63,392.0,329.63, 233.08,293.66,349.23,293.66, 246.94,293.66,329.63,196.0]
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / sample_rate
		var chord: Array = chords[int(t/2.0) % chords.size()]
		var note: float = lead[int(t/0.5) % lead.size()]
		var beat := fmod(t,0.5)
		var phrase := fmod(t,2.0)
		var pad_env: float = minf(1.0, minf(phrase/0.12,(2.0-phrase)/0.18))
		var pad := (sin(TAU*chord[1]*t) + sin(TAU*chord[2]*t))*0.045*pad_env
		var bass := sin(TAU*chord[0]*t)*0.10*exp(-2.7*beat)
		var pluck := (sin(TAU*note*t) + 0.24*sin(TAU*note*2*t))*0.12*exp(-5.0*beat)
		var fade: float = minf(1.0,minf(t/0.3,(duration-t)/0.3))
		var value := clampi(int((pad+bass+pluck)*fade*32767),-32768,32767)
		data.encode_s16(i*2,value)
	var file := FileAccess.open("res://assets/dungeon_theme.wav",FileAccess.WRITE)
	file.big_endian = false
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data.size())
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(sample_rate)
	file.store_32(sample_rate*2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data.size())
	file.store_buffer(data)
	print("Generated original placeholder music (%d samples)" % samples)
	quit()
