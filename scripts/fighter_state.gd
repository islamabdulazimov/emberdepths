extends RefCounted
const Tuning = preload("res://data/battle.gd")
var mode := "idle"
var elapsed := 0.0
var duration := 0.0
var direction := Vector2.RIGHT
var profile: Dictionary = {}
var hits: Dictionary = {}

func reset() -> void:
 mode = "idle"
 elapsed = 0
 duration = 0
 profile.clear()
 hits.clear()

func begin(value: String, aim: Vector2, seconds: float, attack: Dictionary = {}) -> bool:
 if mode != "idle": return false
 mode = value
 elapsed = 0
 duration = seconds
 direction = aim.normalized() if aim.length_squared() > 0.01 else Vector2.RIGHT
 profile = attack.duplicate(true)
 hits.clear()
 return true

func phase() -> String:
 if mode != "attack": return mode
 if elapsed < Tuning.BLADE.windup: return "attack_windup"
 if elapsed < Tuning.BLADE.windup+Tuning.BLADE.active: return "attack_active"
 return "attack_recovery"

func roll_invulnerable() -> bool:
 return mode == "roll" and elapsed >= Tuning.ROLL.invulnerable_from and elapsed < Tuning.ROLL.invulnerable_to
func parry_open() -> bool:
 return mode == "parry" and elapsed >= Tuning.PARRY.window_from and elapsed < Tuning.PARRY.window_to

func advance(delta: float) -> bool:
 if mode == "idle": return false
 var previous := elapsed
 elapsed += maxf(0,delta)
 return mode == "attack" and previous < Tuning.BLADE.windup and elapsed >= Tuning.BLADE.windup

func complete_tick() -> bool:
 if mode!="block" and mode != "idle" and elapsed >= duration:
  reset()
  return true
 return false

func interrupt() -> void:
 reset()
 begin("hurt",Vector2.ZERO,Tuning.HURT_RECOVERY)

func parried() -> void:
 reset()
 begin("parry_success",Vector2.ZERO,Tuning.PARRY.success_recovery)

func snapshot() -> Dictionary:
 return {"mode":mode,"elapsed":elapsed,"duration":duration,"direction":direction}
func apply(data: Dictionary) -> void:
 mode = data.get("mode","idle")
 elapsed = float(data.get("elapsed",0))
 duration = float(data.get("duration",0))
 direction = data.get("direction",Vector2.RIGHT)
 profile.clear()
 hits.clear()
