extends Node
## Generates res://scenes/levels/level_ruins.tscn ("Overgrown Ruins") from code.
## Run: godot --headless --path . res://tools/build_ruins_level.tscn
##
## The generated .tscn is a normal scene and can be edited in the editor, but re-running
## this tool overwrites it. Units: meters. The level runs -Z from the start, turns to +X
## at the colonnade and continues +X to the boss arena. Player abilities it is tuned for:
## full jump ~2.6 m high / ~4.7 m far; jump + hover ~11 m far.

const OUTPUT: String = "res://scenes/levels/level_ruins.tscn"
const MATERIALS: String = "res://assets/materials/ruins/"
const SCENES: String = "res://scenes/level/"
const MOSSLING: String = "res://scenes/enemies/mossling.tscn"
const SPORELING: String = "res://scenes/enemies/sporeling.tscn"
const SNAPTHORN: String = "res://scenes/enemies/snapthorn.tscn"
const COIN: String = "res://scenes/pickups/coin.tscn"
const LOST_SPRITE: String = "res://scenes/pickups/lost_sprite.tscn"
const HEART: String = "res://scenes/pickups/health_pickup.tscn"

var root: Node3D
var _materials: Dictionary = {}
var _sprites: Node3D
var _coins: Node3D
var _entrance_gate: Node3D
var _exit_gate: Node3D
var _outer_platforms: Node3D


func _ready() -> void:
	for material_name: String in ["stone", "stone_dark", "grass", "moss", "rune_teal", "bark", "leaves", "leaves_light", "vine", "gold_accent"]:
		_materials[material_name] = load(MATERIALS + material_name + ".tres")
	_build()
	var packed: PackedScene = PackedScene.new()
	var error: Error = packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT)
	print("build_ruins_level: %s -> %s" % [OUTPUT, error_string(error)])
	root.free()
	get_tree().quit(0 if error == OK else 1)


func _build() -> void:
	root = Node3D.new()
	root.name = "LevelRuins"
	root.set_script(load("res://scripts/level/level.gd"))

	_build_environment()
	var player: Node3D = _instance("res://scenes/player/player.tscn", root, "Player", Vector3(0, 0.05, 2))
	var start: Marker3D = _own(Marker3D.new(), root, "StartPoint") as Marker3D
	start.position = Vector3(0, 0.05, 2)
	root.set("player", player)
	root.set("start_point", start)

	var geometry: Node3D = _group(root, "Geometry")
	_sprites = _group(root, "LostSprites")
	_build_courtyard(_group(geometry, "S1_Courtyard"))
	_build_colonnade(_group(geometry, "S2_Colonnade"))
	_build_stairway(_group(geometry, "S3_Stairway"))
	_build_garden(_group(geometry, "S4_SunkenGarden"))
	_build_arena(_group(geometry, "S5_ThroneArena"))
	_build_enemies(_group(root, "Enemies"))
	_build_pickups(_group(root, "Pickups"))
	_own((load("res://scenes/ui/hud.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), root, "Hud")
	_build_backdrop(_group(root, "Backdrop"))

	var camera: Camera3D = _build_camera_rail(player)
	root.set("camera", camera)
	_build_boss_arena(player, camera)

	_instance(SCENES + "kill_plane.tscn", root, "KillPlane", Vector3(150, -8, -60))


#region Segments

## Segment 1: sunny courtyard. Teaches walking, jumping, a breakable secret, a first gap and the hover.
func _build_courtyard(parent: Node3D) -> void:
	_ground(parent, "Plaza", -10, 10, 8, -24, 0.0)
	# Teaching steps on the right.
	_box(parent, "StepLow", Vector3(4, 0, -8), Vector3(7, 1, -11), "stone", "moss")
	_box(parent, "StepHigh", Vector3(4, 0, -12), Vector3(7, 2, -15), "stone", "moss")

	# Secret alcove on the left, behind a breakable wall (Lost Sprite 1).
	_ground(parent, "AlcoveFloor", -16, -10, -9, -16, 0.0)
	_box(parent, "AlcoveWallBack", Vector3(-16.5, 0, -8.5), Vector3(-16, 4, -16.5), "stone_dark", "moss")
	_box(parent, "AlcoveWallNear", Vector3(-16, 0, -8.5), Vector3(-10, 4, -9.5), "stone_dark", "moss")
	_box(parent, "AlcoveWallFar", Vector3(-16, 0, -15.5), Vector3(-10, 4, -16.5), "stone_dark", "moss")
	_box(parent, "AlcoveRoof", Vector3(-16.5, 4, -8.5), Vector3(-9, 4.6, -16.5), "stone_dark", "moss")
	_instance(SCENES + "breakable_wall.tscn", parent, "SecretWall1", Vector3(-9.5, 1.75, -12.5), {"size": Vector3(1, 3.5, 6)})
	_sprite_spot("SpriteSpot1", Vector3(-13.5, 1.0, -12.5))

	# Ramp up to the terrace.
	_ramp(parent, "Ramp", Vector3(0, 0, -24), Vector3(0, 2, -32), 8.0)
	_ground(parent, "Terrace", -6, 6, -32, -46, 2.0, 8.0)
	# Gap 1: 3 m (easy jump).
	_ground(parent, "LedgeB", -4, 4, -49, -57, 2.0, 8.0)
	_instance(SCENES + "thorn_patch.tscn", parent, "ThornsB", Vector3(-2.5, 2, -53), {"size": Vector3(3, 0.8, 2)})
	# Gap 2: 7 m - needs the hover.
	_ground(parent, "LedgeC", -5, 5, -64, -75, 2.0, 8.0)
	_checkpoint(parent, "Checkpoint1", 1, Vector3(3, 2, -69), 0.0)

	for p: Vector3 in [Vector3(-8, 0, 5), Vector3(8.5, 0, 4), Vector3(-8.5, 0, -20), Vector3(8.5, 0, -21)]:
		_pillar(parent, p, 1.2, 4.5 if int(p.z) % 2 == 0 else 2.5)
	_pillar(parent, Vector3(-5, 2, -44), 1.0, 3.0)
	_pillar(parent, Vector3(5, 2, -44), 1.0, 1.8)


## Segment 2: side-scrolling colonnade heading +X. Thorns, a moving platform, crumbling platforms,
## a breakable wall blocking the path, then checkpoint 2.
func _build_colonnade(parent: Node3D) -> void:
	_ground(parent, "Corner", -5, 14, -75, -84, 2.0, 8.0)
	_ground(parent, "WalkA", 14, 24, -78, -82, 2.0, 8.0)
	_instance(SCENES + "thorn_patch.tscn", parent, "ThornsA", Vector3(19.75, 2, -80), {"size": Vector3(1.5, 0.9, 4)})
	# Gap: 3 m.
	_ground(parent, "WalkB", 27, 33, -78, -82, 2.0, 8.0)
	# 12 m pit crossed by a moving platform.
	_instance(SCENES + "moving_platform.tscn", parent, "MovingPlatformA", Vector3(35.5, 1.7, -80),
		{"size": Vector3(3, 0.6, 4), "travel": Vector3(7, 0, 0), "cycle_time": 4.5, "pause_time": 0.7})
	_ground(parent, "WalkC", 45, 58, -78, -82, 2.0, 8.0)
	_pillar(parent, Vector3(49, 2, -80), 1.4, 1.4)
	_pillar(parent, Vector3(54, 2, -80), 1.4, 1.8)
	# Crumbling bridge: four platforms over a pit.
	var crumble_x: Array[float] = [60.5, 64.5, 68.5, 72.5]
	for i: int in crumble_x.size():
		_instance(SCENES + "crumbling_platform.tscn", parent, "Crumbling%d" % (i + 1), Vector3(crumble_x[i], 1.7, -80),
			{"size": Vector3(2.5, 0.6, 3)})
	_ground(parent, "WalkD", 76, 100, -78, -82, 2.0, 8.0)
	_instance(SCENES + "breakable_wall.tscn", parent, "BlockingWall", Vector3(84, 3.75, -80), {"size": Vector3(1, 3.5, 4)})
	_checkpoint(parent, "Checkpoint2", 2, Vector3(94, 2, -81.6), -90.0)

	# Colonnade backdrop: pillars with lintels behind the path, a low back wall and hanging vines.
	_box(parent, "BackWall", Vector3(10, -6, -88), Vector3(100, 4, -89), "stone_dark", "moss")
	# Pillars rise from the abyss so the pits stay open.
	var x: float = 16.0
	var index: int = 0
	while x < 98.0:
		var tall: bool = index % 3 != 2
		_pillar(parent, Vector3(x, -6, -85), 1.2, 14.0 if tall else 10.8)
		if tall and index % 3 == 0 and x + 7.0 < 98.0:
			_box(parent, "Lintel%d" % index, Vector3(x - 0.8, 8, -84.3), Vector3(x + 7.8, 8.9, -85.7), "stone", "moss")
			_vine(parent, Vector3(x + 3.5, 8, -85), 2.5)
			_vine(parent, Vector3(x + 4.4, 8, -85.2), 1.6)
		x += 7.0
		index += 1


## Segment 3: angled 3/4 climb. Stairs with thorns, a ramp, a vertical lift, a secret behind a wall
## (Lost Sprite 3) and a crumbling bridge.
func _build_stairway(parent: Node3D) -> void:
	_ground(parent, "Base", 100, 104, -74, -86, 2.0, 8.0)
	for i: int in 5:
		var x0: float = 104.0 + 2.5 * i
		_ground(parent, "Stair%d" % (i + 1), x0, x0 + 2.5, -76, -84, 3.0 + i, 9.0 + i, "moss")
	_instance(SCENES + "thorn_patch.tscn", parent, "ThornsStair2", Vector3(107.75, 4, -83), {"size": Vector3(2.5, 0.8, 2)})
	_instance(SCENES + "thorn_patch.tscn", parent, "ThornsStair4", Vector3(112.75, 6, -77), {"size": Vector3(2.5, 0.8, 2)})
	_ground(parent, "Landing", 116.5, 122, -74, -86, 7.0, 13.0)
	_ramp(parent, "Ramp", Vector3(122, 7, -80), Vector3(132, 10, -80), 8.0)
	_ground(parent, "Ledge1", 132, 138, -76, -84, 10.0, 16.0)
	# Vertical lift: 4 m up the cliff face.
	_instance(SCENES + "moving_platform.tscn", parent, "Lift", Vector3(139.5, 9.7, -80),
		{"size": Vector3(3, 0.6, 3), "travel": Vector3(0, 4, 0), "cycle_time": 5.0, "pause_time": 1.0})
	_ground(parent, "Ledge2", 141, 156, -76, -84, 14.0, 20.0)
	# Secret alcove behind the ledge (Lost Sprite 3).
	_ground(parent, "AlcoveFloor", 146, 150, -84, -90, 14.0, 20.0)
	_box(parent, "AlcoveWallL", Vector3(145.5, 14, -84.5), Vector3(146, 18, -90.5), "stone_dark", "moss")
	_box(parent, "AlcoveWallR", Vector3(150, 14, -84.5), Vector3(150.5, 18, -90.5), "stone_dark", "moss")
	_box(parent, "AlcoveWallBack", Vector3(145.5, 14, -90), Vector3(150.5, 18, -90.5), "stone_dark", "moss")
	_instance(SCENES + "breakable_wall.tscn", parent, "SecretWall3", Vector3(148, 15.75, -84.5), {"size": Vector3(4, 3.5, 1)})
	_sprite_spot("SpriteSpot3", Vector3(148, 15, -87.5))
	# Crumbling bridge to the next ledge.
	for i: int in 3:
		_instance(SCENES + "crumbling_platform.tscn", parent, "Crumbling%d" % (i + 1), Vector3(157.9 + 3.3 * i, 13.7, -80),
			{"size": Vector3(2.5, 0.6, 3)})
	_ground(parent, "Ledge3", 166, 170, -76, -84, 14.0, 20.0)
	_checkpoint(parent, "Checkpoint3", 3, Vector3(167.5, 14, -81.6), -90.0)

	_pillar(parent, Vector3(118, 7, -85), 1.2, 5.0)
	_pillar(parent, Vector3(135, 10, -83), 1.0, 3.0)
	_pillar(parent, Vector3(153, 14, -83), 1.2, 4.5)
	_vine(parent, Vector3(141.2, 14, -82), 3.5)
	_vine(parent, Vector3(141.2, 14, -78.5), 2.5)


## Segment 4: pulled-back view over floating islands. A moving platform, a hover gap, thorns,
## crumbling platforms, a breakable-wall shortcut corridor and a high secret (Lost Sprite 2).
func _build_garden(parent: Node3D) -> void:
	_ramp(parent, "DropRamp", Vector3(178, 10, -80), Vector3(170, 14, -80), 8.0)
	_ground(parent, "IslandA", 178, 186, -76, -90, 10.0, 12.0)
	# Main route: moving platform A -> B.
	_instance(SCENES + "moving_platform.tscn", parent, "MovingPlatformB", Vector3(187.5, 9.7, -80),
		{"size": Vector3(3, 0.6, 3), "travel": Vector3(7, 0, 0), "cycle_time": 4.0, "pause_time": 0.8})
	_ground(parent, "IslandB", 196, 202, -76, -84, 10.0, 12.0)
	# Hover gap: 8 m.
	_ground(parent, "IslandC", 210, 216, -76, -90, 10.0, 12.0)
	# Gap: 4 m. Island D has thorns down the middle.
	_ground(parent, "IslandD", 220, 226, -76, -84, 10.0, 12.0)
	_instance(SCENES + "thorn_patch.tscn", parent, "ThornsD", Vector3(223, 10, -80), {"size": Vector3(2, 0.9, 3.2)})
	for i: int in 2:
		_instance(SCENES + "crumbling_platform.tscn", parent, "Crumbling%d" % (i + 1), Vector3(228.5 + 3.5 * i, 9.7, -80),
			{"size": Vector3(2.5, 0.6, 3)})
	_ground(parent, "ApproachE", 233.5, 257, -77, -83, 10.0, 12.0)
	_checkpoint(parent, "Checkpoint4", 4, Vector3(240, 10, -82.2), -90.0)

	# Shortcut: a walled corridor from island A straight to island C, sealed by a breakable wall.
	_ground(parent, "Corridor", 186, 210, -87, -89, 10.0, 3.0, "moss")
	_box(parent, "CorridorWallNear", Vector3(187, 10, -86.5), Vector3(209, 13.5, -87), "stone_dark", "moss")
	_box(parent, "CorridorWallFar", Vector3(186, 10, -89), Vector3(210, 13.5, -89.5), "stone_dark", "moss")
	_instance(SCENES + "breakable_wall.tscn", parent, "ShortcutWall", Vector3(186.5, 11.5, -87.75), {"size": Vector3(1, 3, 2.5)})

	# Secret: a lift beside island B up to a floating platform (Lost Sprite 2).
	_instance(SCENES + "moving_platform.tscn", parent, "SecretLift", Vector3(199, 9.7, -73.5),
		{"size": Vector3(3, 0.6, 3), "travel": Vector3(0, 4.5, 0), "cycle_time": 4.0, "pause_time": 1.2})
	_box(parent, "SecretPlatform", Vector3(204.5, 13.5, -72), Vector3(207, 15, -75), "stone", "moss")
	_sprite_spot("SpriteSpot2", Vector3(205.75, 16, -73.5))

	_tree(parent, Vector3(180, 10, -88), 5.0, 2.2)
	_tree(parent, Vector3(215, 10, -89.3), 6.0, 2.6)
	_pillar(parent, Vector3(200.5, 10, -83), 1.0, 2.5)
	_pillar(parent, Vector3(250, 10, -82.5), 1.2, 5.0)


## Segment 5: circular throne arena with entrance/exit gates, pillars and outer platforms.
func _build_arena(parent: Node3D) -> void:
	var center: Vector3 = Vector3(270, 10, -80)
	var arena: GreyboxBlock = _box(parent, "ArenaFloor", Vector3(257, 4, -93), Vector3(283, 10, -67), "stone", "moss")
	arena.shape_type = GreyboxBlock.ShapeType.CYLINDER
	_entrance_gate = _instance(SCENES + "gate.tscn", parent, "EntranceGate", Vector3(254, 10, -80), {"start_open": true})
	_entrance_gate.rotation_degrees.y = 90.0
	_ground(parent, "ExitWalk", 283, 292, -77, -83, 10.0, 6.0)
	_exit_gate = _instance(SCENES + "gate.tscn", parent, "ExitGate", Vector3(287, 10, -80), {"start_open": false})
	_exit_gate.rotation_degrees.y = 90.0
	_ground(parent, "GoalPlatform", 292, 302, -74, -86, 10.0, 6.0)
	var goal: Node3D = _instance(SCENES + "level_goal.tscn", parent, "LevelGoal", Vector3(297, 10, -80))
	goal.rotation_degrees.y = 90.0

	# Pillars the boss can crash into (Stage 6), and outer platforms that crumble in phase 3.
	var pillars: Node3D = _group(parent, "ArenaPillars")
	var outer: Node3D = _group(parent, "OuterPlatforms")
	_outer_platforms = outer
	for i: int in 4:
		var angle: float = PI * 0.25 + i * PI * 0.5
		var dir: Vector3 = Vector3(cos(angle), 0, sin(angle))
		# Kept short (3.5 m) so they block little of the locked camera's view.
		_pillar(pillars, center + dir * 8.0, 1.6, 3.5).add_to_group("boss_pillar", true)
		var p: Vector3 = center + dir * 16.0
		_box(outer, "Outer%d" % (i + 1), Vector3(p.x - 2, 6, p.z - 2), Vector3(p.x + 2, 10, p.z + 2), "stone", "moss")

	# Throne at the back of the arena.
	_box(parent, "ThroneDais", Vector3(266, 10, -91), Vector3(274, 10.6, -94), "stone_dark", "moss")
	_box(parent, "ThroneSeat", Vector3(268, 10.6, -92), Vector3(272, 12, -94), "stone_dark", "").add_to_group("boss_pillar", true)
	_box(parent, "ThroneBack", Vector3(267.5, 10.6, -93.5), Vector3(272.5, 16, -94.5), "stone_dark", "moss").add_to_group("boss_pillar", true)
	_box(parent, "ThroneGemSocket", Vector3(269.4, 14.4, -93.4), Vector3(270.6, 15.6, -93.6), "gold_accent", "")

#endregion


#region Enemies

## Encounter design: each type is introduced alone (Mossling in the courtyard, Sporeling in the
## colonnade, Snapthorn on the stairway landing) before they are mixed later on.
## Yaw: 0 faces -Z, 180 faces +Z (toward the start), 90 faces -X (toward an approaching player on +X paths).
func _build_enemies(parent: Node3D) -> void:
	var s1: Node3D = _group(parent, "S1_Courtyard")
	_enemy(MOSSLING, s1, "Mossling1", Vector3(0, 0.1, -14), 180.0)
	_enemy(MOSSLING, s1, "Mossling2", Vector3(2, 2.1, -40), 180.0)
	_enemy(MOSSLING, s1, "Mossling3", Vector3(2, 2.1, -54), 180.0)

	var s2: Node3D = _group(parent, "S2_Colonnade")
	_enemy(MOSSLING, s2, "Mossling1", Vector3(30, 2.1, -80), 90.0)
	_enemy(SPORELING, s2, "Sporeling1", Vector3(52, 2.1, -80), 90.0)
	_enemy(MOSSLING, s2, "Mossling2", Vector3(79, 2.1, -80), 90.0)
	_enemy(SPORELING, s2, "Sporeling2", Vector3(90, 2.1, -80), 90.0)

	var s3: Node3D = _group(parent, "S3_Stairway")
	_enemy(SNAPTHORN, s3, "Snapthorn1", Vector3(119, 7.1, -76.8), 90.0)
	_enemy(SPORELING, s3, "Sporeling1", Vector3(136, 10.1, -82), 90.0)
	_enemy(MOSSLING, s3, "Mossling1", Vector3(145, 14.1, -79), 90.0)
	_enemy(MOSSLING, s3, "Mossling2", Vector3(152, 14.1, -81), 90.0)
	_enemy(SNAPTHORN, s3, "Snapthorn2", Vector3(155, 14.1, -83), 90.0)

	var s4: Node3D = _group(parent, "S4_SunkenGarden")
	_enemy(MOSSLING, s4, "Mossling1", Vector3(182, 10.1, -80), 90.0)
	_enemy(SPORELING, s4, "Sporeling1", Vector3(199, 10.1, -81), 90.0)
	_enemy(MOSSLING, s4, "Mossling2", Vector3(213, 10.1, -79), 90.0)
	_enemy(SNAPTHORN, s4, "Snapthorn1", Vector3(224.5, 10.1, -83), 90.0)
	_enemy(MOSSLING, s4, "Mossling3", Vector3(242, 10.1, -79), 90.0)
	_enemy(SNAPTHORN, s4, "Snapthorn2", Vector3(246, 10.1, -77.5), 90.0)
	_enemy(SPORELING, s4, "Sporeling2", Vector3(250, 10.1, -81), 90.0)


func _enemy(path: String, parent: Node, node_name: String, pos: Vector3, yaw_degrees: float) -> void:
	var enemy: Node3D = _instance(path, parent, node_name, pos)
	enemy.rotation_degrees.y = yaw_degrees

#endregion


#region Pickups

## Coins trace the route (y = surface + 0.9) and arc over gaps to show the jump; the shortcut
## corridor is lined with coins as a reward. Hearts sit before the harder stretches and the boss.
func _build_pickups(parent: Node3D) -> void:
	_coins = _group(parent, "Coins")
	# Courtyard.
	_coin_line(Vector3(0, 0.9, -2), Vector3(0, 0.9, -20), 6)
	_coin_line(Vector3(5.5, 2.9, -12.5), Vector3(5.5, 2.9, -14.5), 3)
	for p: Vector3 in [Vector3(-12, 0.9, -12.5), Vector3(-13.5, 0.9, -11), Vector3(-13.5, 0.9, -14), Vector3(-15, 0.9, -12.5)]:
		_coin(p)
	_coin_line(Vector3(0, 1.4, -25.5), Vector3(0, 2.6, -30.5), 3)
	_coin_line(Vector3(0, 2.9, -34), Vector3(0, 2.9, -43), 4)
	_coin_arc(Vector3(0, 2.9, -45), Vector3(0, 2.9, -50), 1.8, 4)
	_coin_arc(Vector3(0, 2.9, -56.5), Vector3(0, 2.9, -64.5), 1.5, 6)
	# Colonnade.
	_coin_line(Vector3(15, 2.9, -80), Vector3(17.5, 2.9, -80), 3)
	_coin_arc(Vector3(18.5, 2.9, -80), Vector3(21, 2.9, -80), 1.5, 3)
	_coin_arc(Vector3(23.5, 2.9, -80), Vector3(27.5, 2.9, -80), 1.5, 4)
	_coin_line(Vector3(35, 3.0, -80), Vector3(43, 3.0, -80), 5)
	for x: float in [46.0, 47.5, 51.5, 56.5]:
		_coin(Vector3(x, 2.9, -80))
	for x: float in [60.5, 64.5, 68.5, 72.5]:
		_coin(Vector3(x, 2.9, -80))
	_coin_line(Vector3(77, 2.9, -80), Vector3(82, 2.9, -80), 4)
	_coin_line(Vector3(86, 2.9, -80), Vector3(91, 2.9, -80), 4)
	# Stairway.
	for i: int in 5:
		_coin(Vector3(105.25 + 2.5 * i, 3.9 + i, -80))
	_coin_line(Vector3(123.5, 8.35, -80), Vector3(130.5, 10.45, -80), 4)
	_coin(Vector3(135, 10.9, -80))
	_coin_line(Vector3(142, 14.9, -80), Vector3(155, 14.9, -80), 5)
	for p: Vector3 in [Vector3(147, 14.9, -86.5), Vector3(149, 14.9, -86.5), Vector3(148, 14.9, -89.2)]:
		_coin(p)
	for x: float in [157.9, 161.2, 164.5]:
		_coin(Vector3(x, 14.9, -80))
	# Sunken garden.
	_coin_line(Vector3(179, 10.9, -80), Vector3(185, 10.9, -80), 4)
	_coin_line(Vector3(188, 10.9, -80), Vector3(195, 10.9, -80), 4)
	_coin_line(Vector3(197, 10.9, -80), Vector3(201, 10.9, -80), 2)
	_coin_arc(Vector3(202.5, 10.9, -80), Vector3(209.5, 10.9, -80), 1.5, 6)
	_coin_line(Vector3(211, 10.9, -80), Vector3(215, 10.9, -80), 2)
	_coin(Vector3(221, 10.9, -77))
	_coin(Vector3(225, 10.9, -77))
	_coin(Vector3(228.5, 10.9, -80))
	_coin(Vector3(232, 10.9, -80))
	_coin_line(Vector3(188, 10.9, -88), Vector3(208, 10.9, -88), 10)
	_coin(Vector3(205, 15.9, -74.5))
	_coin(Vector3(206.5, 15.9, -72.5))
	_coin_line(Vector3(236, 10.9, -80), Vector3(252, 10.9, -80), 5)

	var hearts: Node3D = _group(parent, "Hearts")
	_instance(HEART, hearts, "Heart1", Vector3(78, 2.7, -78.6))
	_instance(HEART, hearts, "Heart2", Vector3(150, 14.7, -77.2))
	_instance(HEART, hearts, "Heart3", Vector3(237, 10.7, -81.5))


func _coin(pos: Vector3) -> void:
	_instance(COIN, _coins, "Coin", pos)


func _coin_line(a: Vector3, b: Vector3, count: int) -> void:
	for i: int in count:
		_coin(a.lerp(b, float(i) / maxf(count - 1, 1)))


## Coins along a parabola from a to b, peaking apex meters above the straight line.
func _coin_arc(a: Vector3, b: Vector3, apex: float, count: int) -> void:
	for i: int in count:
		var t: float = float(i) / maxf(count - 1, 1)
		_coin(a.lerp(b, t) + Vector3.UP * apex * 4.0 * t * (1.0 - t))

#endregion


#region Boss arena

## King Mossback and the BossArena controller that runs the fight.
func _build_boss_arena(player: Node3D, camera: Camera3D) -> void:
	var arena: Node3D = Node3D.new()
	arena.set_script(load("res://scripts/boss/boss_arena.gd"))
	_own(arena, root, "BossArena")

	var boss: Node3D = _instance("res://scenes/boss/king_mossback.tscn", arena, "KingMossback", Vector3(270, 10.1, -86))
	boss.rotation_degrees.y = 90.0  # Faces the entrance (-X).

	var trigger: Area3D = _own(Area3D.new(), arena, "Trigger") as Area3D
	trigger.position = Vector3(259.5, 12, -80)
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	trigger.monitorable = false
	var trigger_shape: CollisionShape3D = _own(CollisionShape3D.new(), trigger, "CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 5, 8)
	trigger_shape.shape = box

	var markers: Array[Marker3D] = []
	for entry: Array in [["EntranceSpawn", Vector3(259.5, 10.05, -80), -90.0], ["ArenaCenterPoint", Vector3(270, 10, -80), 0.0],
			["IntroCamera", Vector3(263.5, 13.0, -84.0), 0.0], ["IntroLook", Vector3(270, 12.8, -86), 0.0]]:
		var marker: Marker3D = _own(Marker3D.new(), arena, entry[0]) as Marker3D
		marker.position = entry[1]
		marker.rotation_degrees.y = entry[2]
		markers.append(marker)

	arena.set("boss", boss)
	arena.set("player", player)
	arena.set("camera", camera)
	arena.set("entrance_gate", _entrance_gate)
	arena.set("exit_gate", _exit_gate)
	arena.set("trigger", trigger)
	arena.set("entrance_spawn", markers[0])
	arena.set("arena_center", markers[1])
	arena.set("intro_camera_point", markers[2])
	arena.set("intro_look_point", markers[3])
	arena.set("outer_platforms", _outer_platforms)
	arena.set("rock_scene", load("res://scenes/boss/falling_rock.tscn"))

#endregion


#region Camera rail

func _build_camera_rail(player: Node3D) -> Camera3D:
	var rail: Path3D = _own(Path3D.new(), root, "CameraRail") as Path3D
	var curve: Curve3D = Curve3D.new()
	curve.bake_interval = 0.5
	var arc: float = 10.0 * 0.5523  # Bezier handle length for a 90-degree arc of radius 10.
	curve.add_point(Vector3(0, 0, 6))
	curve.add_point(Vector3(0, 0, -24))
	curve.add_point(Vector3(0, 2, -32))
	curve.add_point(Vector3(0, 2, -70), Vector3.ZERO, Vector3(0, 0, -arc))
	curve.add_point(Vector3(10, 2, -80), Vector3(-arc, 0, 0), Vector3.ZERO)
	for p: Vector3 in [Vector3(104, 2, -80), Vector3(116.5, 7, -80), Vector3(122, 7, -80), Vector3(132, 10, -80),
			Vector3(139.5, 10, -80), Vector3(141, 14, -80), Vector3(170, 14, -80), Vector3(178, 10, -80),
			Vector3(300, 10, -80)]:
		curve.add_point(p)
	rail.curve = curve

	_key(rail, "Courtyard", Vector3(0, 0, 6), {"offset": Vector3(2.5, 6.0, 10.0), "look_ahead": 2.0, "lateral_follow": 0.8})
	_key(rail, "CourtyardGaps", Vector3(0, 2, -42), {"offset": Vector3(6.0, 7.5, 10.0), "fov": 58.0, "look_ahead": 3.0,
		"blend_in_distance": 8.0})
	_key(rail, "Colonnade", Vector3(14, 2, -80), {"offset": Vector3(13.0, 3.5, 0.0), "fov": 50.0, "look_ahead": 3.0,
		"lateral_follow": 0.15, "vertical_follow": 0.45, "blend_in_distance": 10.0})
	_key(rail, "Stairway", Vector3(101, 2, -80), {"offset": Vector3(9.0, 8.0, 9.0), "fov": 58.0, "look_ahead": 2.5,
		"lateral_follow": 0.6, "vertical_follow": 0.6, "blend_in_distance": 8.0})
	_key(rail, "SunkenGarden", Vector3(171, 14, -80), {"offset": Vector3(5.0, 14.0, 13.0), "fov": 55.0, "look_ahead": 4.0,
		"lateral_follow": 0.5, "vertical_follow": 0.3, "blend_in_distance": 8.0})

	var points: Node3D = _group(root, "CameraPoints")
	var arena_center: Marker3D = _own(Marker3D.new(), points, "ArenaCenter") as Marker3D
	arena_center.position = Vector3(270, 10, -80)
	# Orbit camera: circles the arena behind the player, looking toward the center (and the boss).
	_key(rail, "ThroneArena", Vector3(257, 10, -80), {"orbit": true, "orbit_center": arena_center, "orbit_distance": 19.0,
		"orbit_height": 11.0, "orbit_look_height": 1.5, "orbit_player_look_weight": 0.35, "fov": 60.0, "blend_in_distance": 5.0})
	_key(rail, "Exit", Vector3(284, 10, -80), {"offset": Vector3(12.0, 4.0, 0.0), "fov": 55.0, "look_ahead": 3.0,
		"lateral_follow": 0.2, "blend_in_distance": 3.0})

	var camera: Camera3D = Camera3D.new()
	camera.set_script(load("res://scripts/camera/rail_camera.gd"))
	camera.set("rail", rail)
	camera.set("target", player)
	camera.position = Vector3(0, 6, 12)
	_own(camera, root, "RailCamera")

	var overlay: Node = Node.new()
	overlay.set_script(load("res://scripts/camera/rail_debug_overlay.gd"))
	overlay.set("camera", camera)
	_own(overlay, root, "RailDebugOverlay")
	return camera


func _key(rail: Path3D, key_name: String, pos: Vector3, props: Dictionary) -> void:
	var key: Marker3D = Marker3D.new()
	key.set_script(load("res://scripts/camera/rail_camera_key.gd"))
	for prop: String in props:
		key.set(prop, props[prop])
	key.position = pos
	_own(key, rail, key_name)

#endregion


#region Environment and backdrop

func _build_environment() -> void:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.42, 0.62, 0.86)
	sky_material.sky_horizon_color = Color(0.86, 0.85, 0.72)
	sky_material.ground_horizon_color = Color(0.62, 0.68, 0.5)
	sky_material.ground_bottom_color = Color(0.2, 0.28, 0.16)
	sky_material.sun_angle_max = 20.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material

	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.8, 0.85, 0.76)
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.15

	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	_own(world, root, "WorldEnvironment")

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.rotation_degrees = Vector3(-52, 35, 0)
	_own(sun, root, "Sun")


## Abyss floor far below the pits, distant tree line and hills to frame the level.
func _build_backdrop(parent: Node3D) -> void:
	var abyss_material: StandardMaterial3D = StandardMaterial3D.new()
	abyss_material.albedo_color = Color(0.12, 0.2, 0.1)
	abyss_material.roughness = 1.0
	var abyss_mesh: PlaneMesh = PlaneMesh.new()
	abyss_mesh.size = Vector2(700, 400)
	abyss_mesh.material = abyss_material
	var abyss: MeshInstance3D = MeshInstance3D.new()
	abyss.mesh = abyss_mesh
	abyss.position = Vector3(140, -18, -60)
	_own(abyss, parent, "AbyssFloor")

	# Courtyard trees (kept out of the camera's way).
	for p: Vector3 in [Vector3(-14, 0, 2), Vector3(13, 0, -2), Vector3(14, 0, -18), Vector3(-13, 0, -21)]:
		_tree(parent, p, 7.0, 3.0)
	# Forest line behind the colonnade and stairway.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var x: float = 0.0
	while x < 300.0:
		var height: float = rng.randf_range(10.0, 16.0)
		var z: float = rng.randf_range(-102.0, -96.0)
		_tree(parent, Vector3(x, height * -0.25 + 2.0, z), height, rng.randf_range(3.5, 5.0), false)
		x += rng.randf_range(7.0, 11.0)
	# Rolling hills.
	var hill_material: Material = _materials["leaves"]
	for hill: Vector4 in [Vector4(-40, -14, -40, 30), Vector4(60, -16, -130, 40), Vector4(180, -16, -135, 45),
			Vector4(300, -14, -120, 40), Vector4(330, -14, -60, 35)]:
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = hill.w
		mesh.height = hill.w * 1.2
		mesh.material = hill_material
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = Vector3(hill.x, hill.y, hill.z)
		_own(instance, parent, "Hill")

#endregion


#region Building helpers

func _own(node: Node, parent: Node, node_name: String) -> Node:
	node.name = node_name
	parent.add_child(node, true)
	node.owner = root
	return node


func _group(parent: Node, group_name: String) -> Node3D:
	return _own(Node3D.new(), parent, group_name) as Node3D


func _instance(path: String, parent: Node, node_name: String, pos: Vector3, props: Dictionary = {}) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	for prop: String in props:
		node.set(prop, props[prop])
	node.position = pos
	return _own(node, parent, node_name) as Node3D


## Box between two opposite corners.
func _box(parent: Node, node_name: String, a: Vector3, b: Vector3, material_name: String = "stone",
		cap: String = "grass") -> GreyboxBlock:
	var lo: Vector3 = a.min(b)
	var hi: Vector3 = a.max(b)
	var block: GreyboxBlock = GreyboxBlock.new()
	block.size = hi - lo
	block.material = _materials[material_name]
	if cap != "":
		block.top_material = _materials[cap]
	block.position = (lo + hi) * 0.5
	# Walls and lintels fade out when they hide the player instead of pulling the camera in.
	block.camera_fade = material_name == "stone_dark" or node_name.begins_with("Lintel") or node_name.begins_with("Throne")
	return _own(block, parent, node_name) as GreyboxBlock


## Solid terrain with its top at `top`, extending `depth` meters down.
func _ground(parent: Node, node_name: String, x0: float, x1: float, z0: float, z1: float, top: float,
		depth: float = 6.0, cap: String = "grass") -> GreyboxBlock:
	return _box(parent, node_name, Vector3(x0, top - depth, z0), Vector3(x1, top, z1), "stone", cap)


## Sloped block whose top surface runs from `low` to `high` (top-surface center points).
func _ramp(parent: Node, node_name: String, low: Vector3, high: Vector3, width: float, thickness: float = 3.0) -> GreyboxBlock:
	var d: Vector3 = high - low
	var horizontal: float = Vector2(d.x, d.z).length()
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, horizontal)
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var block: GreyboxBlock = GreyboxBlock.new()
	block.size = Vector3(width, thickness, d.length())
	block.material = _materials["stone"]
	block.top_material = _materials["moss"]
	block.transform = Transform3D(basis, (low + high) * 0.5 - basis.y * thickness * 0.5)
	return _own(block, parent, node_name) as GreyboxBlock


## Stone pillar standing on `base` (bottom center).
func _pillar(parent: Node, base: Vector3, diameter: float, height: float) -> GreyboxBlock:
	var block: GreyboxBlock = GreyboxBlock.new()
	block.shape_type = GreyboxBlock.ShapeType.CYLINDER
	block.size = Vector3(diameter, height, diameter)
	block.material = _materials["stone"]
	block.top_material = _materials["moss"]
	block.position = base + Vector3(0, height * 0.5, 0)
	block.camera_fade = true
	return _own(block, parent, "Pillar") as GreyboxBlock


## Tree: solid trunk plus leafy canopy spheres (canopy has no collision).
func _tree(parent: Node, base: Vector3, height: float, canopy: float, solid: bool = true) -> void:
	var tree: Node3D = _group(parent, "Tree")
	tree.position = base
	if solid:
		var trunk: GreyboxBlock = GreyboxBlock.new()
		trunk.shape_type = GreyboxBlock.ShapeType.CYLINDER
		trunk.size = Vector3(0.8, height, 0.8)
		trunk.material = _materials["bark"]
		trunk.position = Vector3(0, height * 0.5, 0)
		trunk.camera_fade = true
		_own(trunk, tree, "Trunk")
	else:
		var trunk_mesh: CylinderMesh = CylinderMesh.new()
		trunk_mesh.top_radius = 0.4
		trunk_mesh.bottom_radius = 0.5
		trunk_mesh.height = height
		trunk_mesh.material = _materials["bark"]
		var trunk_visual: MeshInstance3D = MeshInstance3D.new()
		trunk_visual.mesh = trunk_mesh
		trunk_visual.position = Vector3(0, height * 0.5, 0)
		_own(trunk_visual, tree, "Trunk")
	var offsets: Array[Vector3] = [Vector3(0, 0, 0), Vector3(canopy * 0.6, -canopy * 0.3, 0.3), Vector3(-canopy * 0.5, -canopy * 0.2, -0.4)]
	for i: int in offsets.size():
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = canopy * (1.0 if i == 0 else 0.7)
		mesh.height = mesh.radius * 1.7
		mesh.material = _materials["leaves" if i != 1 else "leaves_light"]
		var leaf: MeshInstance3D = MeshInstance3D.new()
		leaf.mesh = mesh
		leaf.position = Vector3(0, height, 0) + offsets[i]
		_own(leaf, tree, "Canopy")


## Hanging vine from `top` down `length` meters.
func _vine(parent: Node, top: Vector3, length: float) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.14, length, 0.14)
	mesh.material = _materials["vine"]
	var vine: MeshInstance3D = MeshInstance3D.new()
	vine.mesh = mesh
	vine.position = top - Vector3(0, length * 0.5, 0)
	vine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(vine, parent, "Vine")


func _checkpoint(parent: Node, node_name: String, id: int, pos: Vector3, yaw_degrees: float) -> void:
	var checkpoint: Node3D = _instance(SCENES + "checkpoint.tscn", parent, node_name, pos, {"checkpoint_id": id})
	checkpoint.rotation_degrees.y = yaw_degrees


## Lost Sprite collectible; spot_name ends in its id (1-3).
func _sprite_spot(spot_name: String, pos: Vector3) -> void:
	var sprite_id: int = int(spot_name.right(1))
	_instance(LOST_SPRITE, _sprites, "LostSprite%d" % sprite_id, pos, {"sprite_id": sprite_id})

#endregion
