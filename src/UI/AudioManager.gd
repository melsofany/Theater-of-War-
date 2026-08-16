extends Node
## AudioManager (autoload) — Phase 10b (audio)
##
## Plays sound effects and music by name. Audio streams are loaded from
## `res://assets/audio/sfx/` and `res://assets/audio/music/` on demand and
## cached. When an asset is missing the call is a no-op (logged once), so the
## game runs without assets. This is the hook; actual SFX/music assets are added
## in a later art pass.

var _sfx: Dictionary = {}       # name -> AudioStream
var _sfx_players: Array = []    # pool of AudioStreamPlayer
var _music_player: AudioStreamPlayer = null
var _missing_logged: Dictionary = {}
@export var sfx_pool_size: int = 8


func _ready() -> void:
	for i in range(sfx_pool_size):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)


func play_sfx(name: String) -> void:
	if not _sfx.has(name):
		var stream := load("res://assets/audio/sfx/%s.ogg" % name)
		if stream == null:
			if not _missing_logged.has(name):
				_missing_logged[name] = true
			return
		_sfx[name] = stream
	var p := _next_player()
	if p:
		p.stream = _sfx[name]
		p.play()


func play_music(name: String) -> void:
	if _music_player.stream != null and _music_player.playing:
		_music_player.stop()
	var stream := load("res://assets/audio/music/%s.ogg" % name)
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	if _music_player:
		_music_player.stop()


func _next_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0] if not _sfx_players.is_empty() else null
