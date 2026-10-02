class_name Prof
extends RefCounted

# Frame-time accounting per system, only while profiling (--profile-save):
# otherwise every call returns at once.

static var enabled = false
static var acc: Dictionary = {}   # label -> [total µs, worst µs, calls]

static var trace: FileAccess   # --profile-trace: where the game is, line by line
static var frame: Dictionary = {}   # label -> µs spent in the current frame

static func t(label: String = "") -> int:
	if not enabled: return 0
	if trace != null and label != "":
		trace.store_line("%d > %s" % [Time.get_ticks_msec(),label])
		trace.flush()
	return Time.get_ticks_usec()

static func note(text: String) -> void:
	if trace == null: return
	trace.store_line("%d %s" % [Time.get_ticks_msec(),text])
	trace.flush()

static func add(label: String, start: int) -> void:
	if not enabled: return
	var d = Time.get_ticks_usec()-start
	if trace != null and d > 50000: note("< %s %d ms" % [label,d/1000])
	frame[label] = int(frame.get(label,0))+d
	var a: Array = acc.get(label,[0,0,0])
	a[0] += d
	a[1] = maxi(a[1],d)
	a[2] += 1
	acc[label] = a

static func frame_text() -> String:
	# what took this frame's time, heaviest first
	var keys = frame.keys()
	keys.sort_custom(func(a,b): return int(frame[a]) > int(frame[b]))
	var parts: Array = []
	for k in keys.slice(0,4): parts.append("%s %d ms" % [k,int(frame[k])/1000])
	return ", ".join(parts)

static func report(frames: int) -> String:
	# average per frame and worst single call, in milliseconds
	var parts: Array = []
	var keys = acc.keys()
	keys.sort()
	for k in keys:
		var a: Array = acc[k]
		parts.append("%s %.2f/%.1f" % [k,float(a[0])/1000.0/maxf(frames,1),float(a[1])/1000.0])
	acc.clear()
	return " ".join(parts)
