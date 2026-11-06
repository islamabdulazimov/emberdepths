shader_type canvas_item;
// Retain hair/glasses detail under a nearby additive torch. Ambient stays shared.
void light() {
 LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY * 0.35, LIGHT_COLOR.a);
}
