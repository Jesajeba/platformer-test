@tool
class_name RailCameraKey
extends Marker3D
## Camera settings for one segment of a camera rail.
##
## Place keys as children of the rail's Path3D, on (or near) the rail where the
## segment starts. Their position along the path is the closest point on the curve.
## The camera blends from the previous key into this one over `blend_in_distance`
## meters before reaching it.
##
## Offsets are relative to the rail direction at the camera's point:
## x = right of the rail, y = up, z = back (behind the direction of travel).

@export_group("Framing")
@export var offset: Vector3 = Vector3(0.0, 5.5, 9.0)
@export_range(20.0, 120.0) var fov: float = 60.0
## Height above the player's feet the camera looks at.
@export var look_height: float = 1.0
## Shifts the framing this many meters ahead along the rail (camera and look point move together).
@export var look_ahead: float = 2.0
## Extra pitch after aiming at the look point (positive = tilt up).
@export_range(-45.0, 45.0) var pitch_offset_degrees: float = 0.0

@export_group("Follow")
## How much the camera slides sideways to follow the player off the rail (0..1).
@export_range(0.0, 1.0) var lateral_follow: float = 0.8
## How much the camera rises/falls with the player's height above the rail (0..1).
@export_range(0.0, 1.0) var vertical_follow: float = 0.5

@export_group("Blend")
## Distance before this key over which the camera blends into it. 0 = whole span from the previous key.
@export var blend_in_distance: float = 6.0

@export_group("Orbit")
## Orbit keys circle `orbit_center`, staying behind the player and looking toward the center
## (e.g. a boss arena: the boss stays in view wherever the player runs).
@export var orbit: bool = false
@export var orbit_center: Node3D
## Horizontal distance of the camera from the center.
@export var orbit_distance: float = 19.0
@export var orbit_height: float = 12.0
## Height above the center the camera aims at.
@export var orbit_look_height: float = 1.5
## 0 = aim at the center, 1 = aim at the player.
@export_range(0.0, 1.0) var orbit_player_look_weight: float = 0.35
## How quickly the camera swings around to stay behind the player (higher = faster).
@export var orbit_turn_rate: float = 2.5
## Inside this radius around the center the camera stops turning (avoids whipping around).
@export var orbit_deadzone: float = 2.5

@export_group("Lock")
## Locked keys hold the camera at `lock_camera_point` (e.g. a boss arena).
@export var locked: bool = false
@export var lock_camera_point: Node3D
## What the locked camera looks at (defaults to the rail point if unset).
@export var lock_look_point: Node3D
## 0 = look only at lock_look_point, 1 = look only at the player.
@export_range(0.0, 1.0) var lock_player_look_weight: float = 0.35
