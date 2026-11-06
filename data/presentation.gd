extends RefCounted
# Developer-only overlay. Not a saved setting and never enabled by normal play.
static var combat_debug := OS.get_cmdline_user_args().has("--debug-combat")
