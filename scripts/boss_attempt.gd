extends RefCounted
# Durable world-owned journal. Connection IDs never identify participants.
var altar := Vector2.ZERO
var free_used := false
var sequence := 0
var last:Dictionary = {}
func snapshot() -> Dictionary:
 return {"altar":altar,"free_used":free_used,"sequence":sequence,"last":last.duplicate(true)}
func apply(data:Dictionary,from_disk:bool=false) -> void:
 altar=data.get("altar",Vector2.ZERO);free_used=data.get("free_used",false);sequence=int(data.get("sequence",0));last=data.get("last",{}).duplicate(true)
 # This substage does not persist the running actor. Restart ends, never refunds.
 if from_disk and last.get("status","")=="active":last.status="interrupted"
func begin(profiles:Array) -> void:
 sequence+=1;free_used=true
 last={"id":"andrew:%d"%sequence,"boss":"andrew","status":"active","participants":profiles.duplicate()}
static func valid(data:Variant,width:int,depth:int) -> bool:
 if not data is Dictionary or not data.has_all(["altar","free_used","sequence","last"]):return false
 if not data.altar is Vector2 or not is_finite(data.altar.x) or not is_finite(data.altar.y) or data.altar.x<0 or data.altar.x>width*16 or data.altar.y<0 or data.altar.y>depth*16:return false
 if not data.free_used is bool or not (data.sequence is int or data.sequence is float) or not is_finite(float(data.sequence)) or data.sequence!=floor(data.sequence) or data.sequence<0 or data.sequence>1000000000 or not data.last is Dictionary:return false
 if data.sequence==0:return not data.free_used and data.last.is_empty()
 if not data.free_used or not data.last.has_all(["id","boss","status","participants"]) or data.last.id!="andrew:%d"%int(data.sequence) or data.last.boss!="andrew" or data.last.status not in ["active","defeated","player_died","no_players","loaded","interrupted"]:return false
 var profiles:Variant=data.last.participants
 if not profiles is Array or profiles.is_empty() or profiles.size()>4:return false
 var seen:={}
 for profile in profiles:
  if not profile is String or profile.length()!=32 or seen.has(profile):return false
  for c in profile:
   if c not in "0123456789abcdef":return false
  seen[profile]=true
 return true
