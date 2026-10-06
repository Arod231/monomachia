class_name FrameTimes
extends RefCounted
## The frame-time maths of the performance harness (milestone-1 task 28,
## story 201): "holds 60 fps" means 99% of the frames take 16.7 ms or less,
## so the gate reads the 99th percentile. The harness
## (tools/bench/frame_time_bench.gd) times the frames; this sums them up and
## writes them out.

## The longest a frame may take (ms), and the share of frames that must take
## no longer.
const GATE_MS: float = 16.7
const GATE_SHARE: float = 0.99


## The nearest-rank p-th percentile: p% of the values are at most this. 0 for
## no values.
static func percentile(values: PackedFloat64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	# p * n first: exact for whole-number p, where p / 100 * n can come out a hair high
	var rank: int = clampi(ceili(p * sorted.size() / 100.0), 1, sorted.size())
	return sorted[rank - 1]


static func mean(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / maxf(values.size(), 1)


## What the gate reads from a run's frame times (ms): frames, mean_ms, p99_ms,
## worst_ms and worst_frame (its index, the first of the slowest), within
## (the share of frames at GATE_MS or less) and holds (within reaches
## GATE_SHARE).
static func summary(frame_ms: PackedFloat64Array) -> Dictionary:
	var worst: float = 0.0
	var worst_frame: int = -1
	var within: int = 0
	for i: int in frame_ms.size():
		if frame_ms[i] > worst:
			worst = frame_ms[i]
			worst_frame = i
		if frame_ms[i] <= GATE_MS:
			within += 1
	var share: float = float(within) / frame_ms.size() if not frame_ms.is_empty() else 0.0
	return {
		"frames": frame_ms.size(),
		"mean_ms": mean(frame_ms),
		"p99_ms": percentile(frame_ms, 99.0),
		"worst_ms": worst,
		"worst_frame": worst_frame,
		"within": share,
		"holds": not frame_ms.is_empty() and share >= GATE_SHARE,
	}


## The frame-times file: a header, then one row per timed frame (numbered from
## 1) with the rules step it showed and its times in ms.
static func csv(frame_ms: PackedFloat64Array, gpu_ms: PackedFloat64Array, cpu_ms: PackedFloat64Array, steps: PackedInt32Array) -> String:
	var lines := PackedStringArray(["frame,step,frame_ms,gpu_ms,cpu_ms"])
	for i: int in frame_ms.size():
		lines.append("%d,%d,%.3f,%.3f,%.3f" % [i + 1, steps[i], frame_ms[i], gpu_ms[i], cpu_ms[i]])
	return "\n".join(lines) + "\n"
