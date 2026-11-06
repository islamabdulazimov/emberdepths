extends RefCounted
# Temporary combat tuning: seconds and pixels. No player stamina resource.
const BLADE := {"windup":0.12,"active":0.10,"recovery":0.25,"damage":24,"poise":18,"reach":32.0,"arc_dot":0.45}
const ROLL := {"duration":0.44,"invulnerable_from":0.05,"invulnerable_to":0.27,"speed":225.0,"cooldown":6.0}
const PARRY := {"duration":0.58,"window_from":0.04,"window_to":0.18,"success_recovery":0.18,"boss_poise":45,"enemy_stagger":1.0}
const ASHLING := {"windup":0.48,"active":0.12,"recovery":0.68,"reach":36.0,"stop_distance":28.0}
const HURT_RECOVERY := 0.18
const SUPER_HIT_DELAY := 0.04
const SUPER_IMPACT := 0.12
