extends RefCounted
# All three joints share the body's local coordinate system and draw transform.
# Overlapping filled caps seal the butt-ended segment joins at every angle.
static func cap(canvas: Node2D, at: Vector2, radius: float, color: Color) -> void:
 var points := PackedVector2Array()
 for i in range(8): points.append(at+Vector2.from_angle(TAU*i/8+PI/8)*radius)
 canvas.draw_colored_polygon(points,color)

static func arm(canvas: Node2D, shoulder: Vector2, elbow: Vector2, hand: Vector2, skin: Color) -> void:
 var ink := Color("302c34")
 for layer in range(2):
  var color := ink if layer == 0 else skin
  var upper := 13.0 if layer == 0 else 10.5
  var lower := 11.0 if layer == 0 else 8.5
  canvas.draw_line(shoulder,elbow,color,upper)
  canvas.draw_line(elbow,hand,color,lower)
  cap(canvas,shoulder,upper/2,color)
  cap(canvas,elbow,upper/2,color)
  cap(canvas,hand,lower/2,color)
 var axis := (elbow-shoulder).normalized()
 var normal := Vector2(axis.y,-axis.x)
 canvas.draw_line(shoulder+normal*2,elbow+normal*2,skin.lightened(0.12),3)
 canvas.draw_line(elbow-normal*2,hand-normal*2,skin.darkened(0.16),2)
 # Wrist bindings and fist belong to this arm's pass (rear or front), never a
 # separate foreground rectangle floating over an occluded rear forearm.
 var wrist := hand.lerp(elbow,0.28)
 cap(canvas,wrist,4.8,Color("976b50"))
 cap(canvas,hand,5.3,ink)
 cap(canvas,hand,4.1,skin)
 canvas.draw_line(hand+Vector2(-2,-1),hand+Vector2(2,-1),skin.lightened(0.15),1)
