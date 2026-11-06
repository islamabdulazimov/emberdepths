extends RefCounted
static var rig:Dictionary=preload("res://assets/recast/hero_rig.gd").DATA
static var textures:Dictionary={}
static func texture(path:String) -> Texture2D:
 if not textures.has(path):textures[path]=load(path)
 return textures[path]
static func draw_actor(body:Node2D) -> void:
 var row:="idle";var progress:=fposmod(body.visual_idle_clock*0.7,1.0)
 var mode:String=body.fighter.mode
 var face:int=body.facing
 var gait:=fposmod(body.visual_clock/TAU*(-1 if body.visual_speed*face<0 else 1),1.0)
 if body.dead:row="death";progress=clampf(body.visual_death_age/0.5,0,0.999)
 elif mode=="attack":
  var t:float=body.visual_action_time
  if t<0.12:row="windup";progress=t/0.12
  elif t<0.22:row="active";progress=(t-0.12)/0.1
  else:row="recovery";progress=(t-0.22)/0.25
 elif mode=="roll":row="roll";progress=body.visual_action_time/0.44
 elif mode in ["parry","parry_success"]:
  row="parry";progress=body.visual_action_time/maxf(body.fighter.duration,0.01)
  if mode=="parry_success":progress=.25+.75*progress
 elif mode=="block":row="block"
 elif mode in ["hurt","guard_break"]:row=mode;progress=body.fighter.elapsed/maxf(body.fighter.duration,0.01)
 elif body.work_remaining>0:row="place" if body.work_kind=="place" else "mine";progress=1-body.work_remaining/0.3
 elif body.swing_remaining>0:row="mine";progress=1-body.swing_remaining/0.24
 elif not body.visual_grounded:
  row="jump" if body.velocity.y<0 else "fall";progress=clampf(absf(body.velocity.y)/300,0,0.999)
  if row=="jump":progress*=minf(1,body.visual_air_time/0.12)
 elif body.visual_landing>0.1:row="land";progress=1-body.visual_landing
 elif absf(body.visual_speed)>6:row="run";progress=gait
 var ri:int=rig.rows.find(row);var frame:=clampi(int(progress*24),0,23)
 var src:=Rect2(frame*64,ri*64,64,64);var dst:=Rect2(-32,-41,64,64)
 var a:Dictionary=preload("res://data/appearance.gd").clean(body.appearance)
 var bare:bool=body.visual_death_unclothed if body.dead else body.unclothed
 var path:="res://assets/recast/hero_%s_%s_%d_%s.png"%[a.gender,a.hair,a.skin,"bare" if bare else "coat"]
 body.draw_set_transform(Vector2.ZERO,0,Vector2(face,1))
 var tint:=Color.WHITE.lerp(Color("ffd5a1"),minf(0.5,body.visual_hurt*3))
 var moving_legs:bool=body.visual_grounded and absf(body.visual_speed)>6 and row in ["windup","active","recovery","mine","place","block","parry"]
 var leg_src:=Rect2(clampi(int(gait*24),0,23)*64,64+39,64,25)
 if moving_legs:
  body.draw_texture_rect_region(texture(path),Rect2(-32,-2,64,25),leg_src,tint)
  body.draw_texture_rect_region(texture(path),Rect2(-32,-41,64,41),Rect2(src.position,Vector2(64,41)),tint)
 else:body.draw_texture_rect_region(texture(path),dst,src,tint)
 if not body.dead:
  for part in ["legs","body","head"]:
   if body.equipment.get(part,"")!="":
    if moving_legs and part=="legs":body.draw_texture_rect_region(texture("res://assets/recast/armor_legs.png"),Rect2(-32,-2,64,25),leg_src,tint)
    else:body.draw_texture_rect_region(texture("res://assets/recast/armor_%s.png"%part),dst,src,tint)
 var pose:Dictionary=rig.poses[ri][frame]
 var right:=Vector2(pose.right[0],pose.right[1]+10)
 var left:=Vector2(pose.left[0],pose.left[1]+10)
 var roll_angle:float=-float(pose.get("rotation",0))
 if row=="roll":
  var pivot:=Vector2(0,1)
  right=(right-pivot).rotated(roll_angle)+pivot+Vector2(0,float(pose.get("roll_shift",0)))
  left=(left-pivot).rotated(roll_angle)+pivot+Vector2(0,float(pose.get("roll_shift",0)))
 if body.equipment.shield!="" and not body.dead  :
  body.draw_set_transform(left*Vector2(face,1),roll_angle*face,Vector2(face,1))
  body.draw_texture_rect(texture("res://assets/recast/held_wood_shield.png"),Rect2(-7,-8,14,17),false,tint)
 var item:String=body.held_item if mode=="attack" else body.equipment.weapon
 var main:=body.get_parent().get_parent()
 if mode!="attack" and is_instance_valid(main.get("items")) and main.get("player")==body:
  var selected:String=main.items.local_inventory().item_at(main.interaction.selected_slot)
  if selected!="":item=selected
 if row=="mine":item="" if body.work_kind=="punch" or body.swing_unarmed else ("stone_axe" if body.work_kind=="axe" or body.swing_tool else "stone_pick")
 if item!="" and not body.dead and preload("res://data/items.gd").DEFINITIONS.get(item,{}).get("kind","") in ["weapon","tool","axe","torch"]:
  var tool:bool=item in ["stone_pick","stone_axe"]
  body.draw_set_transform(right*Vector2(face,1),(float(pose.weapon)+roll_angle+(0.8 if tool else 0.0))*face,Vector2(face,1))
  body.draw_texture_rect(texture("res://assets/recast/held_%s.png"%item),Rect2(-5 if tool else -4,-19 if tool else -12,24,24),false)
 body.draw_set_transform(Vector2.ZERO,0,Vector2(face,1))
 if row=="active":body.draw_texture_rect_region(preload("res://assets/recast/sword_trace.png"),Rect2(8,-27,24,24),Rect2(clampi(int(progress*4),0,3)*24,0,24,24),Color(1,1,1,0.65))
 body.draw_set_transform_matrix(Transform2D.IDENTITY)
 if body.fighter.parry_open():body.draw_line(Vector2(face*12,-20),Vector2(face*15,-17),Color("f3d3a0"),1)
