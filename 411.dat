extends SkeletonModifier3D
## Bounded two-bone contact corrections, evaluated after animation by Godot.
var actor: Node3D
var state: Dictionary={}
var targets: Array=[]
var previous_targets: Array=[]
var ground_height: Callable
var grip_weight=0.0
var last_errors: Dictionary={}

func _process_modification_with_delta(delta: float):
	var sk=get_skeleton()
	if sk==null or not is_instance_valid(actor): return
	grip_weight=move_toward(grip_weight,1.0 if targets.size()==2 else 0.0,max(0,delta)*8)
	last_errors.clear()
	if targets.size()==2: previous_targets=targets.duplicate()
	if previous_targets.size()==2 and grip_weight>0.0:
		for i in 2:
			var side="l" if i==0 else "r"
			var pole=actor.to_global(Vector3(0.6 if i==0 else -0.6,1.15,-0.6))
			last_errors[side]=solve_limb("upperarm_"+side,"lowerarm_"+side,"hand_"+side,previous_targets[i],pole,grip_weight)
	if not ground_height.is_valid() or state.get("dead",false) or state.get("sailing",false) or state.get("swimming",false) or state.get("jump",0)>0.01: return
	for side in ["l","r"]:
		var foot=sk.find_bone("foot_"+side)
		if foot<0: continue
		var now=sk.to_global(sk.get_bone_global_pose(foot).origin)
		var ground=float(ground_height.call(now.x,now.z))+0.09
		# Preserve raised swing feet; adjust only small terrain discrepancies.
		if now.y-ground>0.18 or abs(ground-now.y)>0.28: continue
		var target=now; target.y=ground
		solve_limb("thigh_"+side,"calf_"+side,"foot_"+side,target,actor.to_global(Vector3(0.15 if side=="l" else -0.15,0.5,0.8)),0.8)

func aim_bone(sk: Skeleton3D,index: int,from: Vector3,to: Vector3):
	if from.length_squared()<0.000001 or to.length_squared()<0.000001: return
	var pose=sk.get_bone_global_pose(index)
	pose.basis=Basis(Quaternion(from.normalized(),to.normalized()))*pose.basis
	sk.set_bone_global_pose(index,pose)

func solve_limb(upper_name: String,lower_name: String,end_name: String,world_target: Vector3,world_pole: Vector3,weight=1.0) -> float:
	var sk=get_skeleton()
	var upper=sk.find_bone(upper_name); var lower=sk.find_bone(lower_name); var end=sk.find_bone(end_name)
	if upper<0 or lower<0 or end<0 or not world_target.is_finite(): return INF
	var old_upper=sk.get_bone_pose_rotation(upper); var old_lower=sk.get_bone_pose_rotation(lower)
	var a=sk.get_bone_global_pose(upper).origin
	var b=sk.get_bone_global_pose(lower).origin
	var c=sk.get_bone_global_pose(end).origin
	var l1=a.distance_to(b); var l2=b.distance_to(c)
	var wanted=sk.to_local(world_target)
	var direction=wanted-a
	if direction.length()<0.0001 or min(l1,l2)<0.0001: return INF
	var distance=clamp(direction.length(),abs(l1-l2)+0.001,l1+l2-0.001)
	var axis=direction.normalized()
	var target=a+axis*distance
	var pole=sk.to_local(world_pole)-a
	pole-=axis*pole.dot(axis)
	if pole.length_squared()<0.0001: pole=axis.cross(Vector3.UP if abs(axis.y)<0.9 else Vector3.RIGHT)
	pole=pole.normalized()
	var x=(l1*l1+distance*distance-l2*l2)/(2*distance)
	var elbow=a+axis*x+pole*sqrt(max(0,l1*l1-x*x))
	aim_bone(sk,upper,b-a,elbow-a)
	b=sk.get_bone_global_pose(lower).origin; c=sk.get_bone_global_pose(end).origin
	aim_bone(sk,lower,c-b,target-b)
	# This is the contact fade, independent of the engine's modifier influence.
	sk.set_bone_pose_rotation(upper,old_upper.slerp(sk.get_bone_pose_rotation(upper),weight))
	sk.set_bone_pose_rotation(lower,old_lower.slerp(sk.get_bone_pose_rotation(lower),weight))
	return sk.to_global(sk.get_bone_global_pose(end).origin).distance_to(world_target)
