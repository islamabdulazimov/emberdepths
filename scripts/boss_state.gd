extends RefCounted
const Rules = preload("res://data/combat_rules.gd")
var boss_name := ""
var base_health := 1
var max_health := 1
var health := 1
var max_poise := 0
var poise := 0
var show_poise := false
var scaling_players := 1
var active := false
var initialized := false

func begin(definition: Dictionary, players: int) -> bool:
 if initialized: return false
 initialized = true
 boss_name = definition.name
 base_health = definition.health
 scaling_players = clampi(players, 1, 4)
 max_health = Rules.scaled_health(base_health, scaling_players)
 health = max_health
 max_poise = int(definition.get("poise", 0))
 poise = max_poise
 show_poise = bool(definition.get("show_poise", max_poise > 0))
 active = true
 return true

func admit(players:int) -> void:
 # Explicit entry is the only path that changes a running boss's health scale.
 scaling_players=maxi(scaling_players,clampi(players,1,4))
 max_health=Rules.scaled_health(base_health,scaling_players)
 health=max_health

func snapshot() -> Dictionary:
 return {"name": boss_name, "base_health": base_health, "max_health": max_health, "health": health, "max_poise": max_poise, "poise": poise, "show_poise": show_poise, "players": scaling_players, "active": active}

func apply(data: Dictionary) -> void:
 initialized = true
 boss_name = data.name
 base_health = data.base_health
 max_health = data.max_health
 health = data.health
 max_poise = data.max_poise
 poise = data.poise
 show_poise = data.show_poise
 scaling_players = data.players
 active = data.active
