// Full-screen ink-wash pass with ink lines at depth breaks only: it doesn't
// read the normal buffer, so the depth prepass stays cheap. InkWashPass uses
// it unless normal lines are asked for. See ink_wash.gdshaderinc.
shader_type spatial;
#include "res://shaders/ink_wash.gdshaderinc"
