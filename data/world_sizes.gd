extends RefCounted
const DEFINITIONS := {
 "small":{"name":"Маленький","width":512,"depth":192,"settlements":1,"dungeons":2,"description":"Более короткие путешествия: 512×192 блока, одно поселение и до двух данженов."},
 "large":{"name":"Большой","width":896,"depth":256,"settlements":2,"dungeons":4,"description":"Больше природных пространств: 896×256 блоков, два поселения и до четырёх данженов."}
}
const BORDER_GAP := 48.0
const HORIZONTAL_GAP := 24
static func border_distance(a: Rect2i,b: Rect2i) -> float:
 var x := maxi(0,maxi(a.position.x-b.end.x,b.position.x-a.end.x))
 var y := maxi(0,maxi(a.position.y-b.end.y,b.position.y-a.end.y))
 return Vector2(x,y).length()
static func separated(a: Rect2i,b: Rect2i) -> bool:
 var horizontal := maxi(0,maxi(a.position.x-b.end.x,b.position.x-a.end.x))
 return horizontal >= HORIZONTAL_GAP and border_distance(a,b) >= BORDER_GAP
