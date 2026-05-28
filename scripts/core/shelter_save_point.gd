class_name ShelterSavePoint
## ShelterSavePoint: Data record for a single player-built shelter that serves as a save point.
## Quality tiers: 1 = bedroll/camp, 2 = tent, 3 = permanent shelter (bed + walls + roof).
## Serialises to/from Dictionary for JSON persistence inside each save slot.

var shelter_id: String
var display_name: String
var world_position: Vector3
var quality: int
var save_slot: int
var created_day: int

func _init(
	p_id: String,
	p_name: String,
	p_pos: Vector3,
	p_quality: int,
	p_slot: int,
	p_day: int,
) -> void:
	shelter_id     = p_id
	display_name   = p_name
	world_position = p_pos
	quality        = p_quality
	save_slot      = p_slot
	created_day    = p_day

func to_dict() -> Dictionary:
	return {
		"shelter_id":   shelter_id,
		"display_name": display_name,
		"position":     {"x": world_position.x, "y": world_position.y, "z": world_position.z},
		"quality":      quality,
		"save_slot":    save_slot,
		"created_day":  created_day,
	}

static func from_dict(d: Dictionary) -> ShelterSavePoint:
	var pd: Dictionary = d.get("position", {})
	return ShelterSavePoint.new(
		str(d.get("shelter_id", "")),
		str(d.get("display_name", "Camp")),
		Vector3(float(pd.get("x", 0.0)), float(pd.get("y", 0.0)), float(pd.get("z", 0.0))),
		int(d.get("quality", 1)),
		int(d.get("save_slot", -1)),
		int(d.get("created_day", 1)),
	)
