extends RefCounted

signal completed(result: Dictionary)

var _thread: Thread
var _native: Object
var _busy := false
var _closing := false

func available() -> bool:
	return ClassDB.class_exists("JanggiNative")

func busy() -> bool:
	return _busy

func start(initial_fen: String, moves: PackedStringArray) -> bool:
	if _busy or not available():
		return false
	_native = ClassDB.instantiate("JanggiNative")
	if _native == null or not _native.prepare():
		_native = null
		return false
	_thread = Thread.new()
	_busy = true
	var error := _thread.start(_analyze.bind(initial_fen, moves))
	if error != OK:
		_native.abandon()
		_native = null
		_thread = null
		_busy = false
		return false
	return true

func cancel() -> void:
	if _busy and _native != null:
		_native.cancel()

func shutdown() -> void:
	_closing = true
	cancel()
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	_native = null
	_busy = false

func _analyze(initial_fen: String, moves: PackedStringArray) -> void:
	var result: Dictionary = _native.analyze(initial_fen, moves)
	call_deferred("_finish", result)

func _finish(result: Dictionary) -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	_native = null
	_busy = false
	if not _closing:
		completed.emit(result)
