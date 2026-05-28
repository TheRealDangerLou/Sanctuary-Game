extends Node
## Logger: Structured debug logger. Autoloaded as Logger.
## Writes to both stdout and user://sanctuary_debug.log.
## Usage: Logger.info("msg"), Logger.warn("msg"), Logger.error("msg")

enum Level { INFO, WARN, ERROR }

var _log_file: FileAccess = null

func _ready() -> void:
	_log_file = FileAccess.open("user://sanctuary_debug.log", FileAccess.WRITE)
	if _log_file:
		_log_file.store_line("=== Sanctuary Debug Log: %s ===" % Time.get_datetime_string_from_system())
		_log_file.flush()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close()

func info(message: String) -> void:
	_write(Level.INFO, message)

func warn(message: String) -> void:
	_write(Level.WARN, message)

func error(message: String) -> void:
	_write(Level.ERROR, message)

func _write(level: Level, message: String) -> void:
	var prefix: String
	match level:
		Level.INFO:  prefix = "[INFO] "
		Level.WARN:  prefix = "[WARN] "
		Level.ERROR: prefix = "[ERROR]"
	var line: String = "%s %s %s" % [Time.get_time_string_from_system(), prefix, message]
	print(line)
	if _log_file:
		_log_file.store_line(line)
		_log_file.flush()

func _close() -> void:
	if _log_file:
		_log_file.flush()
		_log_file.close()
		_log_file = null
