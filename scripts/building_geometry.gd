extends RefCounted
## Native port of architecture-game-55.js, settlements.js and company.js.
## height_at stays terrain-only; ground_at adds the source foundation floors.
## Rectangles use world x/z centers, local half extents hx/hz and Godot yaw.

var g
var _rect_cache: Dictionary = {}
const NON_SOLID = ["road", "farm", "campfire", "well", "dock", "mine", "tannery"]
const LEGACY_NON_SOLID = ["road", "campfire", "farm", "dock", "quarry", "mine", "well", "workbench"]
const INN_SOURCE_RECTS = [
	[0.0,-4.85,13.8,4.5], [-5.5,1.1,3.0,7.5],
	[-4.45,5.15,5.1,0.5], [4.45,5.15,5.1,0.5],
	[-1.7,5.15,0.5,0.72], [1.7,5.15,0.5,0.72],
	[5.78,1.58,1.45,4.8], [-1.1,1.2,2.25,1.9],
	[-1.0,3.4,2.25,1.9], [3.42,2.7,2.55,3.8],
	[-6.33,-0.85,0.3,0.4], [-3.18,-0.85,0.3,0.4],
	[0.0,-0.85,0.3,0.4], [3.18,-0.85,0.3,0.4],
	[6.33,-0.85,0.3,0.4]
]

func _init(game):
	g = game

func footprint(type: String) -> Vector2:
	var meta: Dictionary = g.catalog.ARCHITECTURE55.get(type, {})
	if not meta.is_empty(): return Vector2(meta.width * 0.5, meta.depth * 0.5)
	var size: float = g.catalog.BUILDING_BY_ID.get(type, {}).get("size", 0.0) * 0.72
	return Vector2(size, size)

func local_point(point: Dictionary, building: Dictionary) -> Vector2:
	return Vector2(point.x - building.x, point.z - building.z).rotated(float(building.get("yaw", 0.0)))

func world_point(point: Vector2, building: Dictionary) -> Dictionary:
	var v = point.rotated(-float(building.get("yaw", 0.0)))
	return {"x":building.x + v.x, "z":building.z + v.y}

func local_rects(type: String) -> Array:
	## Immutable source templates; do not mutate the returned array.
	if _rect_cache.has(type): return _rect_cache[type]
	var half = footprint(type)
	if type != "inn":
		_rect_cache[type] = [{"x":0.0, "z":0.0, "hx":half.x, "hz":half.y}]
		return _rect_cache[type]
	var scale: float = g.catalog.ARCHITECTURE55.inn.width / 14.931
	var result: Array = []
	for r in INN_SOURCE_RECTS:
		result.append({"x":(r[0] + 0.0645) * scale, "z":(r[1] + 1.1075) * scale, "hx":r[2] * scale * 0.5, "hz":r[3] * scale * 0.5})
	_rect_cache[type] = result
	return result

func is_solid(building: Dictionary) -> bool:
	if building.get("hp", 1.0) <= 0.0 or building.get("progress", 1.0) < 1.0: return false
	if g.catalog.ARCHITECTURE55.has(building.type): return building.type not in NON_SOLID
	return building.type not in LEGACY_NON_SOLID and not (building.type == "gate" and building.get("open", false))

func building_rects(building: Dictionary, padding = 0.0) -> Array:
	## Actual physical walls/rooms. Open gates keep their side posts.
	## padding expands each local half extent, never its center or yaw.
	if not is_solid(building): return []
	var rects = local_rects(building.type)
	if building.type == "gate" and building.get("open", false):
		var half = footprint(building.type)
		var gap = half.x * 0.27
		var post_half = (half.x - gap) * 0.5
		var post_center = (half.x + gap) * 0.5
		rects = [{"x":-post_center, "z":0.0, "hx":post_half, "hz":half.y}, {"x":post_center, "z":0.0, "hx":post_half, "hz":half.y}]
	var result: Array = []
	for r in rects:
		var point = world_point(Vector2(r.x, r.z), building)
		result.append({"x":point.x, "z":point.z, "hx":maxf(0.0, r.hx + padding), "hz":maxf(0.0, r.hz + padding), "yaw":float(building.get("yaw", 0.0))})
	return result

func contains(building: Dictionary, point: Dictionary, radius = 0.0) -> bool:
	if not is_solid(building): return false
	if not g.catalog.ARCHITECTURE55.has(building.type):
		return _distance(building, point) < g.catalog.BUILDING_BY_ID[building.type].size * 0.66 + radius
	var q = local_point(point, building)
	var half = footprint(building.type)
	# Every approved inn rectangle lies inside its approved footprint. This
	# broad phase is conservative and avoids room tests for distant actors.
	if absf(q.x) > half.x + radius or absf(q.y) > half.y + radius: return false
	# Preserve the source strict open-center rule, including radius tangencies.
	if building.type == "gate" and building.get("open", false) and absf(q.x) + radius < half.x * 0.27: return false
	for r in local_rects(building.type):
		var dx = maxf(0.0, absf(q.x - r.x) - r.hx)
		var dz = maxf(0.0, absf(q.y - r.z) - r.hz)
		if dx * dx + dz * dz <= radius * radius: return true
	return false

func blocked(point: Dictionary, radius = 0.35, ignore_id = "") -> bool:
	## Buildings only: caller retains world bounds, resource and actor checks.
	for building in g.state.buildings:
		if not str(ignore_id).is_empty() and building.get("id", "") == ignore_id: continue
		if contains(building, point, radius): return true
	return false

func footprints_overlap(a: Dictionary, b: Dictionary) -> bool:
	var fa = footprint(a.type)
	var fb = footprint(b.type)
	var aa = _axes(float(a.get("yaw", 0.0)))
	var bb = _axes(float(b.get("yaw", 0.0)))
	var delta = Vector2(b.x - a.x, b.z - a.z)
	for axis in aa + bb:
		var extent = fa.x * absf(aa[0].dot(axis)) + fa.y * absf(aa[1].dot(axis)) + fb.x * absf(bb[0].dot(axis)) + fb.y * absf(bb[1].dot(axis))
		if absf(delta.dot(axis)) >= extent - 0.01: return false
	return true

func _axes(yaw: float) -> Array:
	return [Vector2(cos(yaw), -sin(yaw)), Vector2(sin(yaw), cos(yaw))]

func resource_obstacles(point: Dictionary, radius = 0.35, ignore_id = "") -> Array:
	## The source circles use scale, not the resource model's rectangular bounds.
	var result: Array = []
	# Native spatial queries include all resources within the requested radius.
	# Resource scale is arbitrary in imported saves, so filtering the authoritative
	# list also retains collisions for an unusually large obstacle.
	for resource in g.state.resources:
		if resource.get("id", "") == ignore_id and not str(ignore_id).is_empty(): continue
		if resource.get("amount", 0) <= 0 or resource.kind not in ["wood", "stone", "ore", "coal"]: continue
		var scale: float = resource.get("scale", 1.0)
		if scale == 0.0: scale = 1.0
		var reach = radius + (0.36 if resource.kind == "wood" else 0.55) * scale
		if _distance(resource, point) < reach: result.append(resource)
	return result

func ground_at(x: float, z: float) -> float:
	var y: float = g.height_at(x, z)
	for building in g.state.buildings:
		# Source groundAt is independent of visual footprint and completion.
		if building.get("hp", 0) <= 0 or building.type == "road": continue
		var floor_y = building.get("foundationY")
		if not (floor_y is float or floor_y is int) or not is_finite(float(floor_y)): continue
		var half: float = g.catalog.BUILDING_BY_ID[building.type].size * 0.72
		var local = local_point({"x":x, "z":z}, building)
		if absf(local.x) <= half and absf(local.y) <= half: y = maxf(y, float(floor_y))
	return y

func snap_placement(type: String, point: Dictionary, yaw = 0.0, enabled = true) -> Dictionary:
	if not enabled: return {"x":point.x, "z":point.z, "yaw":yaw}
	var step = 4.0 if type == "road" else 1.0
	var angle = PI * 0.5 if type == "road" else PI * 0.25
	# JavaScript Math.round chooses +infinity at negative half-step ties.
	return {"x":floorf(point.x / step + 0.5) * step, "z":floorf(point.z / step + 0.5) * step, "yaw":floorf(yaw / angle + 0.5) * angle}

func road_bonus(point: Dictionary) -> float:
	for building in g.state.buildings:
		if building.type == "road" and building.hp > 0:
			var local = local_point(point, building)
			if absf(local.x) <= 2.0 and absf(local.y) <= 2.0: return 1.2
	return 1.0

func placement(type: String, point: Dictionary, yaw = 0.0, ignore_cost = false) -> Dictionary:
	if not g.catalog.BUILDING_BY_ID.has(type) or not _finite_point(point) or not is_finite(float(yaw)):
		return {"ok":false, "reason":"Неизвестная постройка"}
	var d: Dictionary = g.catalog.BUILDING_BY_ID[type]
	var size: float = d.size
	var road = type == "road"
	var h: float = g.height_at(point.x, point.z)
	if absf(point.x) > g.catalog.LIMITS.world or absf(point.z) > g.catalog.LIMITS.world:
		return {"ok":false, "reason":"За границей архипелага"}
	var edge = 1.0 if road else 0.75
	var heights: Array = [h]
	for a in [-edge, edge]:
		for b in [-edge, edge]:
			var v = Vector2(a, b).rotated(-float(yaw)) * size
			heights.append(g.height_at(point.x + v.x, point.z + v.y))
	var coast: bool = d.get("coast", false)
	if (h < -0.7 or h > 4.0) if coast else heights.min() < 0.65:
		return {"ok":false, "reason":"Нужен пологий берег" if coast else "Площадка должна быть целиком на суше"}
	var slope: float = heights.max() - heights.min()
	if slope > (1.6 if road else 3.2): return {"ok":false, "reason":"Склон слишком крутой для фундамента"}
	var candidate = {"type":type, "x":point.x, "z":point.z, "yaw":yaw}
	for building in g.state.buildings:
		if building.hp <= 0: continue
		var overlaps = false
		if road and building.type == "road":
			overlaps = absf(building.x - point.x) < 3.9 and absf(building.z - point.z) < 3.9
		elif not road and building.type == "road": continue
		elif road: overlaps = _distance(building, point) < g.catalog.BUILDING_BY_ID[building.type].size * 0.72 + 1.8
		else: overlaps = footprints_overlap(candidate, building)
		if overlaps: return {"ok":false, "reason":"Границы пересекают другую постройку"}
	for resource in g.state.resources:
		if resource.kind == "wood" and resource.amount > 0 and _distance(resource, point) < size * 0.72 + 0.5:
			return {"ok":false, "reason":"Сначала срубите дерево"}
	if _distance(point, g.player) > 16.0: return {"ok":false, "reason":"Подойдите ближе"}
	var foundation = not coast and not road and type not in ["campfire", "farm", "quarry", "mine"]
	var extra = int(ceil(slope * size)) if foundation and slope > 0.32 else 0
	var cost: Dictionary = d.cost.duplicate()
	if extra > 0: cost.stone = cost.get("stone", 0) + extra
	if not ignore_cost and not g.can_afford(cost, point):
		return {"ok":false, "reason":"Не хватает материалов, включая " + str(extra) + " камня на фундамент" if extra > 0 else "Не хватает материалов", "cost":cost}
	# company.js wraps successful settlement placement before architecture-55.
	for project in g.state.get("projects", []):
		if not project.get("done", false) and _distance(project, point) < (g.catalog.BUILDING_BY_ID[project.type].size + size) * 0.82:
			return {"ok":false, "reason":"Здесь уже строит ваш отряд"}
	# The final architecture override also checks roads against rotated models.
	for building in g.state.buildings:
		if building.hp > 0 and building.type != "road" and footprints_overlap(candidate, building):
			return {"ok":false, "reason":"Границы пересекают другую постройку"}
	var depth = slope + 0.12 if foundation else 0.0
	return {"ok":true, "reason":"Выравнивание фундаментом · +" + str(extra) + " камня" if extra > 0 else "Площадка готова", "height":heights.max() + 0.04 if foundation else h, "depth":depth, "foundationDepth":depth, "cost":cost, "yaw":yaw}

func building_clearance(x: float, z: float) -> float:
	var clearance = INF
	for building in g.state.buildings:
		if not is_solid(building) or (building.type == "gate" and building.get("open", false)): continue
		var local = local_point({"x":x, "z":z}, building)
		for r in local_rects(building.type):
			var dx = absf(local.x - r.x) - r.hx
			var dz = absf(local.y - r.z) - r.hz
			clearance = minf(clearance, Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length() + minf(maxf(dx, dz), 0.0) - 0.4)
	return clearance

func building_approach(building: Dictionary, from: Dictionary) -> Dictionary:
	if not g.catalog.BUILDING_BY_ID.has(building.get("type", "")): return building
	var local = local_point(from, building)
	var half = footprint(building.type)
	var pad = 1.15
	var faces = [Vector2(-half.x-pad, clampf(local.y, -half.y, half.y)), Vector2(half.x+pad, clampf(local.y, -half.y, half.y)), Vector2(clampf(local.x, -half.x, half.x), -half.y-pad), Vector2(clampf(local.x, -half.x, half.x), half.y+pad)]
	var points: Array = []
	for face in faces: points.append(world_point(face, building))
	points.sort_custom(func(a, b): return _distance(a, from) < _distance(b, from))
	for point in points:
		if g.height_at(point.x, point.z) > 0.4 and not blocked(point, 0.45) and resource_obstacles(point, 0.4).is_empty(): return point
	return points[0]

func _distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _finite_point(point: Dictionary) -> bool:
	for key in ["x", "z"]:
		var value = point.get(key)
		if not (value is float or value is int) or not is_finite(float(value)): return false
	return true
