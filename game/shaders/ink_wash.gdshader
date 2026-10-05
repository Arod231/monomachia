// Full-screen ink-wash pass that also draws ink lines at normal breaks
// (creases inside a silhouette). InkWashPass uses it only when normal lines
// are asked for; no graphics preset asks today, since the normal buffer it
// reads cost about 3 ms per frame on the target laptop. See ink_wash.gdshaderinc.
shader_type spatial;
#define INK_NORMALS
#include "res://shaders/ink_wash.gdshaderinc"
