extends Node2D
class_name RainEffect

# Rain effect that provides water to players standing under it
# Automatically despawns after timer expires

func _ready() -> void:
	# Add the rain area to the "rain_zones" group so players can detect it
	var rain_area = $RainArea
	if rain_area:
		rain_area.add_to_group("rain_zones")
		print("[Rain Debug] Rain effect created at ", global_position, " - RainArea added to rain_zones group")
	else:
		print("[Rain Debug ERROR] RainArea not found!")
