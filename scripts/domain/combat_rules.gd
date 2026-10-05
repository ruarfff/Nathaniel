class_name CombatRules
extends RefCounted
## Target retention, original threat scores, projectiles and timed weapons.

static func acquire(sim: GameSimulation, unit: Dictionary) -> void:
	if int(unit.hp) <= 0:
		unit.target_id = -1
		return
	if unit.weapon == "heal":
		unit.target_id = -1
		return
	var current: Dictionary = sim.entity(int(unit.target_id))
	if unit.enemy:
		if alive(current):
			return
		unit.target_id = -1
		# Original acquisition intentionally lets the last eligible ally win.
		for ally: Dictionary in sim.opponents(true):
			if not alive(ally):
				continue
			if distance(unit, ally) < float(unit.vision) or int(ally.target_id) == int(unit.id):
				unit.target_id = ally.id
		return
	var manual: Dictionary = sim.entity(int(unit.manual_target_id))
	if alive(manual):
		unit.target_id = manual.id
		return
	unit.manual_target_id = -1
	var anchored: bool = unit.kind == "hermes" and unit.get("anchored", false)
	var search_range: float = float(unit.range) if unit.tower or anchored else float(unit.vision)
	if alive(current) and distance(unit, current) <= (search_range if anchored else float(unit.vision)):
		return
	unit.target_id = -1
	var best_score: float = -INF
	for enemy: Dictionary in sim.opponents(false):
		if not alive(enemy):
			continue
		var separation: float = distance(unit, enemy)
		if separation > search_range:
			continue
		var score: float = 1.0 - separation / search_range
		var hp_ratio: float = float(enemy.hp) / float(enemy.max_hp)
		if hp_ratio <= 0.25:
			score += (1.0 - hp_ratio / 0.25) * 0.5
		var victim: Dictionary = sim.entity(int(enemy.target_id))
		if alive(victim) and not victim.enemy:
			# Towers include themselves before the two players in getAllies.
			if victim.kind == "nathaniel" or victim.kind == "hermes" or (unit.tower and int(victim.id) == int(unit.id)):
				score += 5.0 if unit.kind == "hermes" and sim.hermes_mode == "following" and victim.kind == "nathaniel" else 3.0
		if score > best_score:
			best_score = score
			unit.target_id = enemy.id

static func update_unit(sim: GameSimulation, unit: Dictionary, delta: float) -> void:
	# Player shots resolve before enemy shots, as in GameScene.update. This
	# preserves boss-victory priority if an enemy arrow also lands this frame.
	_update_projectiles(sim, delta, int(unit.id))
	if not alive(unit):
		return
	acquire(sim, unit)
	var target: Dictionary = sim.entity(int(unit.target_id))
	if unit.weapon == "heal":
		_heal(sim, unit, delta)
		return
	if unit.weapon == "laser" or unit.weapon == "spawner_laser":
		_laser(sim, unit, target, delta)
		return
	if unit.weapon == "pulse_laser":
		_pulse_laser(sim, unit, target, delta)
		return
	unit.cooldown = float(unit.cooldown) + delta
	if unit.kind == "nathaniel":
		_update_player_weapon(sim, unit, target, delta)
		return
	if alive(target) and distance(unit, target) <= float(unit.range):
		unit.facing = (Vector2(target.position) - Vector2(unit.position)).normalized()
		shoot(sim, unit, target.position)

static func _pulse_laser(sim: GameSimulation, unit: Dictionary, target: Dictionary, delta: float) -> void:
	unit.cooldown = float(unit.cooldown) + delta
	unit.burst = float(unit.burst) + delta
	unit.firing = bool(unit.firing) and float(unit.burst) < GameBalance.LASER_PULSE_SECONDS
	if not alive(target) or distance(unit, target) > float(unit.range):
		return
	unit.facing = (Vector2(target.position) - Vector2(unit.position)).normalized()
	if float(unit.cooldown) + 0.00000001 < float(unit.delay):
		return
	unit.cooldown = 0.0
	unit.burst = 0.0
	unit.firing = true
	sim.emit_event("laser", {"owner_id": unit.id, "position": unit.position, "pulse": true,
		"target_id": target.id, "target_position": target.position, "target_kind": target.kind})
	sim.damage_entity(int(target.id), int(unit.damage), int(unit.id))

static func ready_to_shoot(unit: Dictionary) -> bool:
	if not alive(unit) or unit.weapon not in ["gun", "blaster", "bow"]:
		return false
	var delay: float = float(unit.delay)
	if unit.kind == "nathaniel":
		if float(unit.equip_ready_remaining) > 0.00000001:
			return false
		delay = maxf(delay, float(unit.recovery_delay))
	return float(unit.cooldown) + 0.00000001 >= delay

static func _update_player_weapon(sim: GameSimulation, unit: Dictionary, target: Dictionary, delta: float) -> void:
	unit.equip_ready_remaining = maxf(0.0, float(unit.equip_ready_remaining) - delta)
	var aim_point: Variant = unit.manual_fire_target
	if aim_point != null and Vector2(unit.position).distance_to(aim_point) > float(unit.range):
		unit.manual_fire_target = null
		aim_point = null
	if aim_point == null and alive(target) and distance(unit, target) <= float(unit.range):
		aim_point = target.position
	var desired: Vector2 = unit.aim_direction
	if aim_point != null:
		desired = (Vector2(aim_point) - Vector2(unit.position)).normalized()
		if desired == Vector2.ZERO:
			desired = Vector2(0, -1)
	elif unit.moving:
		desired = unit.facing
	var current: Vector2 = unit.aim_direction
	unit.aim_direction = current.rotated(clampf(current.angle_to(desired), -GameBalance.WEAPON_AIM_SPEED * delta, GameBalance.WEAPON_AIM_SPEED * delta)).normalized()
	if aim_point != null and shoot(sim, unit, aim_point):
		unit.manual_fire_target = null

static func shoot(sim: GameSimulation, unit: Dictionary, target: Vector2) -> bool:
	if not target.is_finite() or not ready_to_shoot(unit) or Vector2(unit.position).distance_to(target) > float(unit.range):
		return false
	var direction: Vector2 = (target - Vector2(unit.position)).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(0, -1)
	if unit.kind == "nathaniel":
		if absf(Vector2(unit.aim_direction).angle_to(direction)) > GameBalance.WEAPON_AIM_TOLERANCE:
			return false
		unit.aim_direction = direction
		unit.recovery_delay = unit.delay
	unit.cooldown = 0.0
	if unit.kind != "nathaniel" or not unit.moving:
		unit.facing = direction
	var weapon_id: String = unit.get("equipped_weapon_id", unit.weapon)
	var texture: String = "arrow" if unit.weapon == "bow" else ("redbullet" if unit.weapon == "blaster" else "bullet")
	var projectile: Dictionary = {"id": sim.allocate_id(), "owner_id": unit.id,
		"position": unit.position, "direction": direction, "damage": unit.damage,
		"speed": unit.shot_speed, "remaining": 500.0 if unit.weapon == "bow" else 600.0,
		"enemy": unit.enemy, "kind": texture, "weapon_id": weapon_id,
		"radius": 15.0 if texture == "arrow" else (10.0 if texture == "redbullet" else 12.0)}
	# Swift pool keeps at most twenty active shots for each owner.
	var owned: Array[Dictionary] = sim.shots_for_owner(int(unit.id))
	if owned.size() >= 20:
		sim.remove_projectile(owned[0])
	sim.add_projectile(projectile)
	sim.emit_event("shot", {"position": unit.position, "kind": texture, "owner_id": unit.id,
		"shot_id": projectile.id, "direction": direction, "target_position": target, "weapon_id": weapon_id})
	return true

static func _update_projectiles(sim: GameSimulation, delta: float, owner_id: int) -> void:
	for shot: Dictionary in sim.shots_for_owner(owner_id).duplicate():
		shot.position = Vector2(shot.position) + Vector2(shot.direction) * float(shot.speed) * delta
		shot.remaining = float(shot.remaining) - float(shot.speed) * delta
		if float(shot.remaining) <= 0:
			sim.remove_projectile(shot)
			continue
		for target: Dictionary in sim.opponents(bool(shot.enemy)):
			if not alive(target):
				continue
			if Vector2(shot.position).distance_to(target.position) < float(shot.radius) + float(target.radius):
				sim.damage_entity(int(target.id), int(shot.damage), int(shot.owner_id))
				sim.remove_projectile(shot)
				break

static func _laser(sim: GameSimulation, unit: Dictionary, target: Dictionary, delta: float) -> void:
	var spawner: bool = unit.weapon == "spawner_laser"
	var in_range: bool = alive(target) and distance(unit, target) <= float(unit.range)
	if not unit.firing and (not spawner or in_range):
		unit.cooldown = float(unit.cooldown) + delta
	if not in_range:
		unit.firing = false
		if spawner:
			unit.burst = 0.0
		return
	unit.facing = (Vector2(target.position) - Vector2(unit.position)).normalized()
	if not unit.firing and float(unit.cooldown) + 0.00000001 >= float(unit.delay):
		unit.firing = true
		unit.burst = 0.0
		unit.cooldown = 0.0
		sim.emit_event("laser", {"owner_id": unit.id, "position": unit.position})
	if not unit.firing:
		return
	var active_time: float = minf(delta, maxf(0.0, 1.5 - float(unit.burst)))
	unit.burst = float(unit.burst) + active_time
	# Spawners apply whole seconds; Hermes and towers carry fractional damage.
	unit.pending_damage = float(unit.pending_damage) + active_time * (1.0 if spawner else float(unit.damage))
	var amount: int = floori(float(unit.pending_damage) + 0.00000001)
	unit.pending_damage = float(unit.pending_damage) - amount
	if amount > 0:
		sim.damage_entity(int(target.id), amount * int(unit.damage) if spawner else amount, int(unit.id))
	if float(unit.burst) + 0.00000001 >= 1.5:
		unit.firing = false

static func _heal(sim: GameSimulation, unit: Dictionary, delta: float) -> void:
	unit.cooldown = float(unit.cooldown) + delta
	if float(unit.cooldown) + 0.00000001 < 1.0:
		return
	var healed: bool = false
	for target: Dictionary in [sim.nathaniel, sim.hermes]:
		if alive(target) and int(target.hp) < int(target.max_hp) and distance(unit, target) < float(unit.range):
			target.hp = mini(int(target.max_hp), int(target.hp) + 5)
			healed = true
			sim.emit_event("heal", {"position": target.position, "target_id": target.id, "owner_id": unit.id})
	if healed:
		unit.cooldown = 0.0

static func alive(unit: Dictionary) -> bool:
	return not unit.is_empty() and int(unit.get("hp", 0)) > 0 and unit.get("active", true)

static func distance(first: Dictionary, second: Dictionary) -> float:
	return Vector2(first.position).distance_to(second.position)
