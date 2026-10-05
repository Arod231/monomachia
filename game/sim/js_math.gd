class_name JsMath
extends RefCounted
## Math.hypot, Math.sin, Math.cos and Math.atan2 computed exactly as V8 (Node
## and the browsers' JavaScript engine) computes them, so the GDScript rules
## stay bit-identical to the TypeScript rules, and give the same results on
## every platform. Not a port of a file in v0.1-web-mvp:src/sim: the TS calls the JS
## built-ins, and every such call in the port goes through here
## (Math.hypot(x, z) -> JsMath.hypot(x, z), Math.sin(a) -> JsMath.sin(a)...).
##
## Why: Godot's sin, cos and atan2 call the C runtime, which differs from V8 in
## the last bit for some arguments (and on Windows by far more near multiples
## of pi/2: cos(PI / 2) is 6.1230e-17 instead of 6.1232e-17), and V8's
## Math.hypot scales by the larger magnitude, so it differs from
## sqrt(x * x + z * z) in the last bit for about a third of all pairs. Either
## difference drifts positions by an ulp at a time and can flip a threshold.
##
## Sources, transcribed in order with their comments:
## - hypot: V8 src/builtins/math.tq, MathHypot, for two arguments.
## - sin, cos, atan2: V8 src/base/ieee754.cc, its fdlibm port (from FreeBSD
##   msun): __kernel_sin, __kernel_cos, __kernel_rem_pio2, __ieee754_rem_pio2,
##   atan, atan2, and sin and cos (V8's fdlibm_sin and fdlibm_cos). Node 24's
##   Math.sin, Math.cos and Math.atan2 match these bit for bit.
##
## Port notes:
## - fdlibm reads and writes the 32-bit halves of a double (GET_HIGH_WORD,
##   INSERT_WORDS...): _hi, _lo and _from_words do that through a scratch
##   PackedByteArray. The rules run on one thread; so must these functions.
## - int32_t and uint32_t words are GDScript ints holding the same values
##   (_hi sign-extends, _lo does not), so shifts and masks give the C results.
## - Constants are built from their bits (the hex in the fdlibm comments):
##   Godot's float literal parser is not correctly rounded for long decimals.
## - fdlibm's "raise inexact" tricks (huge + x > one, pi + tiny) only set an
##   IEEE flag in C and never change a value; they return the value directly
##   here, with a comment.
## - Inside this class a bare sin(), cos() or atan2() would call Godot's
##   built-in, not these: call JsMath.sin() and so on from outside.


# ------------------------------------------------------------------ words

static var _buf: PackedByteArray = _scratch()


static func _scratch() -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(8)
	return b


## GET_HIGH_WORD into an int32_t: sign, exponent and the top of the mantissa.
static func _hi(x: float) -> int:
	_buf.encode_double(0, x)
	return _buf.decode_s32(4)


## GET_LOW_WORD into a uint32_t.
static func _lo(x: float) -> int:
	_buf.encode_double(0, x)
	return _buf.decode_u32(0)


## INSERT_WORDS: the double whose high and low words are hi and lo.
static func _from_words(hi: int, lo: int) -> float:
	_buf.encode_u32(4, hi & 0xFFFFFFFF)
	_buf.encode_u32(0, lo & 0xFFFFFFFF)
	return _buf.decode_double(0)


## scalbn(x, n) = x * 2^n, exact while the result stays a normal number, which
## it does everywhere __kernel_rem_pio2 calls it.
static func _scalbn(x: float, n: int) -> float:
	while n > 1023:
		x *= _from_words(0x7FE00000, 0) # 2^1023
		n -= 1023
	while n < -1022:
		x *= _from_words(0x00100000, 0) # 2^-1022
		n += 1022
	return x * _from_words((n + 1023) << 20, 0)


# ------------------------------------------------------------------ Math.hypot

## Math.hypot(x, z): V8's MathHypot for two arguments. Its two loops over the
## arguments are unrolled (first x, then z).
static func hypot(x: float, z: float) -> float:
	var abs_x: float = 0.0
	var abs_z: float = 0.0
	var one_arg_is_nan: bool = false
	var max_value: float = 0.0
	if is_nan(x):
		one_arg_is_nan = true
	else:
		abs_x = absf(x)
		if abs_x > max_value:
			max_value = abs_x
	if is_nan(z):
		one_arg_is_nan = true
	else:
		abs_z = absf(z)
		if abs_z > max_value:
			max_value = abs_z
	if max_value == INF:
		return INF
	elif one_arg_is_nan:
		return NAN
	elif max_value == 0.0:
		return 0.0

	# Kahan summation to avoid rounding errors.
	# Normalize the numbers to the largest one to avoid overflow.
	var sum: float = 0.0
	var compensation: float = 0.0
	var n: float = abs_x / max_value
	var summand: float = n * n - compensation
	var preliminary: float = sum + summand
	compensation = (preliminary - sum) - summand
	sum = preliminary
	n = abs_z / max_value
	summand = n * n - compensation
	preliminary = sum + summand
	compensation = (preliminary - sum) - summand
	sum = preliminary
	return sqrt(sum) * max_value


# ------------------------------------------------------------------ __kernel_sin

## __kernel_sin(x, y, iy)
## kernel sin function on ~[-pi/4, pi/4] (except on -0), pi/4 ~ 0.7854
## Input x is assumed to be bounded by ~pi/4 in magnitude.
## Input y is the tail of x.
## Input iy indicates whether y is 0. (if iy=0, y assume to be 0).
##
## Algorithm
##   1. Since sin(-x) = -sin(x), we need only to consider positive x.
##   2. if x < 2^-27 (hx<0x3E400000 0), return x with inexact if x!=0.
##   3. sin(x) is approximated by a polynomial of degree 13 on
##      [0,pi/4]
##                        3            13
##        sin(x) ~ x + S1*x + ... + S6*x
##      where
##
##      |sin(x)         2     4     6     8     10     12  |     -58
##      |----- - (1+S1*x +S2*x +S3*x +S4*x +S5*x  +S6*x   )| <= 2
##      |  x                                               |
##
##   4. sin(x+y) = sin(x) + sin'(x')*y
##               ~ sin(x) + (1-x*x/2)*y
##      For better accuracy, let
##                3      2      2      2      2
##        r = x *(S2+x *(S3+x *(S4+x *(S5+x *S6))))
##      then                   3    2
##        sin(x) = x + (S1*x + (x *(r-y/2)+y))
static var _S1: float = _from_words(0xBFC55555, 0x55555549) # -1.66666666666666324348e-01
static var _S2: float = _from_words(0x3F811111, 0x1110F8A6) # 8.33333333332248946124e-03
static var _S3: float = _from_words(0xBF2A01A0, 0x19C161D5) # -1.98412698298579493134e-04
static var _S4: float = _from_words(0x3EC71DE3, 0x57B1FE7D) # 2.75573137070700676789e-06
static var _S5: float = _from_words(0xBE5AE5E6, 0x8A2B9CEB) # -2.50507602534068634195e-08
static var _S6: float = _from_words(0x3DE5D93A, 0x5ACFD57C) # 1.58969099521155010221e-10


static func _kernel_sin(x: float, y: float, iy: int) -> float:
	var half: float = 0.5
	var ix: int = _hi(x)
	ix &= 0x7FFFFFFF # high word of x
	if ix < 0x3E400000: # |x| < 2**-27
		if int(x) == 0:
			return x # generate inexact
	var z: float = x * x
	var v: float = z * x
	var r: float = _S2 + z * (_S3 + z * (_S4 + z * (_S5 + z * _S6)))
	if iy == 0:
		return x + v * (_S1 + z * r)
	else:
		return x - ((z * (half * y - v * r) - y) - v * _S1)


# ------------------------------------------------------------------ __kernel_cos

## __kernel_cos(x, y)
## kernel cos function on [-pi/4, pi/4], pi/4 ~ 0.785398164
## Input x is assumed to be bounded by ~pi/4 in magnitude.
## Input y is the tail of x.
##
## Algorithm
##   1. Since cos(-x) = cos(x), we need only to consider positive x.
##   2. if x < 2^-27 (hx<0x3E400000 0), return 1 with inexact if x!=0.
##   3. cos(x) is approximated by a polynomial of degree 14 on
##      [0,pi/4]
##                                    4            14
##        cos(x) ~ 1 - x*x/2 + C1*x + ... + C6*x
##      where the remez error is
##
##      |              2     4     6     8     10    12     14 |     -58
##      |cos(x)-(1-.5*x +C1*x +C2*x +C3*x +C4*x +C5*x  +C6*x  )| <= 2
##      |                                                      |
##
##                     4     6     8     10    12     14
##   4. let r = C1*x +C2*x +C3*x +C4*x +C5*x  +C6*x  , then
##        cos(x) = 1 - x*x/2 + r
##      since cos(x+y) ~ cos(x) - sin(x)*y
##                     ~ cos(x) - x*y,
##      a correction term is necessary in cos(x) and hence
##        cos(x+y) = 1 - (x*x/2 - (r - x*y))
##      For better accuracy when x > 0.3, let qx = |x|/4 with
##      the last 32 bits mask off, and if x > 0.78125, let qx = 0.28125.
##      Then
##        cos(x+y) = (1-qx) - ((x*x/2-qx) - (r-x*y)).
##      Note that 1-qx and (x*x/2-qx) is EXACT here, and the
##      magnitude of the latter is at least a quarter of x*x/2,
##      thus, reducing the rounding error in the subtraction.
static var _C1: float = _from_words(0x3FA55555, 0x5555554C) # 4.16666666666666019037e-02
static var _C2: float = _from_words(0xBF56C16C, 0x16C15177) # -1.38888888888741095749e-03
static var _C3: float = _from_words(0x3EFA01A0, 0x19CB1590) # 2.48015872894767294178e-05
static var _C4: float = _from_words(0xBE927E4F, 0x809C52AD) # -2.75573143513906633035e-07
static var _C5: float = _from_words(0x3E21EE9E, 0xBDB4B1C4) # 2.08757232129817482790e-09
static var _C6: float = _from_words(0xBDA8FAE9, 0xBE8838D4) # -1.13596475577881948265e-11


static func _kernel_cos(x: float, y: float) -> float:
	var one: float = 1.0
	var ix: int = _hi(x)
	ix &= 0x7FFFFFFF # ix = |x|'s high word
	if ix < 0x3E400000: # if x < 2**27
		if int(x) == 0:
			return one # generate inexact
	var z: float = x * x
	var r: float = z * (_C1 + z * (_C2 + z * (_C3 + z * (_C4 + z * (_C5 + z * _C6)))))
	if ix < 0x3FD33333: # if |x| < 0.3
		return one - (0.5 * z - (z * r - x * y))
	else:
		var qx: float
		if ix > 0x3FE90000: # x > 0.78125
			qx = 0.28125
		else:
			qx = _from_words(ix - 0x00200000, 0) # x/4
		var iz: float = 0.5 * z - qx
		var a: float = one - qx
		return a - (iz - (z * r - x * y))


# ------------------------------------------------------------------ __kernel_rem_pio2

## __kernel_rem_pio2(x, y, e0, nx, prec, ipio2)
## double x[],y[]; int e0,nx,prec; int ipio2[];
##
## __kernel_rem_pio2 return the last three digits of N with
##   y = x - N*pi/2
## so that |y| < pi/2.
##
## The method is to compute the integer (mod 8) and fraction parts of
## (2/pi)*x without doing the full multiplication. In general we
## skip the part of the product that are known to be a huge integer (
## more accurately, = 0 mod 8 ). Thus the number of operations are
## independent of the exponent of the input.
##
## (2/pi) is represented by an array of 24-bit integers in ipio2[].
##
## Input parameters:
##   x[]   The input value (must be positive) is broken into nx
##         pieces of 24-bit integers in double precision format.
##         x[i] will be the i-th 24 bit of x. The scaled exponent
##         of x[0] is given in input parameter e0 (i.e., x[0]*2^e0
##         match x's up to 24 bits.
##
##         Example of breaking a double positive z into x[0]+x[1]+x[2]:
##           e0 = ilogb(z)-23
##           z  = scalbn(z,-e0)
##         for i = 0,1,2
##           x[i] = floor(z)
##           z    = (z-x[i])*2**24
##
##   y[]   ouput result in an array of double precision numbers.
##         The dimension of y[] is:
##           24-bit  precision 1
##           53-bit  precision 2
##           64-bit  precision 2
##           113-bit precision 3
##         The actual value is the sum of them. Thus for 113-bit
##         precison, one may have to do something like:
##
##         long double t,w,r_head, r_tail;
##         t = (long double)y[2] + (long double)y[1];
##         w = (long double)y[0];
##         r_head = t+w;
##         r_tail = w - (r_head - t);
##
##   e0    The exponent of x[0]
##
##   nx    dimension of x[]
##
##   prec  an integer indicating the precision:
##           0 24  bits (single)
##           1 53  bits (double)
##           2 64  bits (extended)
##           3 113 bits (quad)
##
##   ipio2[]
##         integer array, contains the (24*i)-th to (24*i+23)-th
##         bit of 2/pi after binary point. The corresponding
##         floating value is
##
##           ipio2[i] * 2^(-24(i+1)).
##
## Here is the description of some local variables:
##
##   jk  jk+1 is the initial number of terms of ipio2[] needed
##       in the computation. The recommended value is 2,3,4,
##       6 for single, double, extended,and quad.
##
##   jz  local integer variable indicating the number of
##       terms of ipio2[] used.
##
##   jx  nx - 1
##
##   jv  index for pointing to the suitable ipio2[] for the
##       computation. In general, we want
##         ( 2^e0*x[0] * ipio2[jv-1]*2^(-24jv) )/8
##       is an integer. Thus
##         e0-3-24*jv >= 0 or (e0-3)/24 >= jv
##       Hence jv = max(0,(e0-3)/24).
##
##   jp  jp+1 is the number of terms in PIo2[] needed, jp = jk.
##
##   q[] double array with integral value, representing the
##       24-bits chunk of the product of x and 2/pi.
##
##   q0  the corresponding exponent of q[0]. Note that the
##       exponent for q[i] would be q0-24*i.
##
##   PIo2[] double precision array, obtained by cutting pi/2
##       into 24 bits chunks.
##
##   f[] ipio2[] in floating point
##
##   iq[] integer array by breaking up q[] in 24-bits chunk.
##
##   fq[] final product of x*(2/pi) in fq[0],..,fq[jk]
##
##   ih  integer. If >0 it indicates q[] is >= 0.5, hence
##       it also indicates the *sign* of the result.
##
## This port returns n & 7 and writes y[0] and y[1] into y.
const _INIT_JK: Array[int] = [2, 3, 4, 6] # initial value for jk

static var _PIO2: PackedFloat64Array = PackedFloat64Array([
	_from_words(0x3FF921FB, 0x40000000), # 1.57079625129699707031e+00
	_from_words(0x3E74442D, 0x00000000), # 7.54978941586159635335e-08
	_from_words(0x3CF84698, 0x80000000), # 5.39030252995776476554e-15
	_from_words(0x3B78CC51, 0x60000000), # 3.28200341580791294123e-22
	_from_words(0x39F01B83, 0x80000000), # 1.27065575308067607349e-29
	_from_words(0x387A2520, 0x40000000), # 1.22933308981111328932e-36
	_from_words(0x36E38222, 0x80000000), # 2.73370053816464559624e-44
	_from_words(0x3569F31D, 0x00000000), # 2.16741683877804819444e-51
])

static var _TWO24: float = _from_words(0x41700000, 0x00000000) # 1.67772160000000000000e+07
static var _TWON24: float = _from_words(0x3E700000, 0x00000000) # 5.96046447753906250000e-08


static func _kernel_rem_pio2(x: PackedFloat64Array, y: PackedFloat64Array, e0: int, nx: int, prec: int, ipio2: PackedInt32Array) -> int:
	var zero: float = 0.0
	var one: float = 1.0
	var iq: PackedInt64Array = PackedInt64Array()
	iq.resize(20)
	var f: PackedFloat64Array = PackedFloat64Array()
	f.resize(20)
	var fq: PackedFloat64Array = PackedFloat64Array()
	fq.resize(20)
	var q: PackedFloat64Array = PackedFloat64Array()
	q.resize(20)
	var z: float
	var fw: float
	var i: int
	var j: int
	var k: int

	# initialize jk
	var jk: int = _INIT_JK[prec]
	var jp: int = jk

	# determine jx,jv,q0, note that 3>q0
	var jx: int = nx - 1
	@warning_ignore("integer_division")
	var jv: int = (e0 - 3) / 24 # C int division: truncates toward zero
	if jv < 0:
		jv = 0
	var q0: int = e0 - 24 * (jv + 1)

	# set up f[0] to f[jx+jk] where f[jx+jk] = ipio2[jv+jk]
	j = jv - jx
	var m: int = jx + jk
	i = 0
	while i <= m:
		f[i] = zero if j < 0 else float(ipio2[j])
		i += 1
		j += 1

	# compute q[0],q[1],...q[jk]
	for ii: int in jk + 1:
		fw = 0.0
		for jj: int in jx + 1:
			fw += x[jj] * f[jx + ii - jj]
		q[ii] = fw

	var jz: int = jk
	var n: int
	var ih: int
	while true: # recompute:
		# distill q[] into iq[] reversingly
		i = 0
		j = jz
		z = q[jz]
		while j > 0:
			fw = float(int(_TWON24 * z))
			iq[i] = int(z - _TWO24 * fw)
			z = q[j - 1] + fw
			i += 1
			j -= 1

		# compute n
		z = _scalbn(z, q0) # actual value of z
		z -= 8.0 * floorf(z * 0.125) # trim off integer >= 8
		n = int(z)
		z -= float(n)
		ih = 0
		if q0 > 0: # need iq[jz-1] to determine n
			i = iq[jz - 1] >> (24 - q0)
			n += i
			iq[jz - 1] -= i << (24 - q0)
			ih = iq[jz - 1] >> (23 - q0)
		elif q0 == 0:
			ih = iq[jz - 1] >> 23
		elif z >= 0.5:
			ih = 2

		if ih > 0: # q > 0.5
			n += 1
			var carry: int = 0
			for ii: int in jz: # compute 1-q
				j = iq[ii]
				if carry == 0:
					if j != 0:
						carry = 1
						iq[ii] = 0x1000000 - j
				else:
					iq[ii] = 0xFFFFFF - j
			if q0 > 0: # rare case: chance is 1 in 12
				match q0:
					1:
						iq[jz - 1] &= 0x7FFFFF
					2:
						iq[jz - 1] &= 0x3FFFFF
			if ih == 2:
				z = one - z
				if carry != 0:
					z -= _scalbn(one, q0)

		# check if recomputation is needed
		if z == zero:
			j = 0
			i = jz - 1
			while i >= jk:
				j |= iq[i]
				i -= 1
			if j == 0: # need recomputation
				k = 1
				while jk >= k and iq[jk - k] == 0: # k = no. of terms needed
					k += 1

				i = jz + 1
				while i <= jz + k: # add q[jz+1] to q[jz+k]
					f[jx + i] = float(ipio2[jv + i])
					fw = 0.0
					for jj: int in jx + 1:
						fw += x[jj] * f[jx + i - jj]
					q[i] = fw
					i += 1
				jz += k
				continue # goto recompute
		break

	# chop off zero terms
	if z == 0.0:
		jz -= 1
		q0 -= 24
		while iq[jz] == 0:
			jz -= 1
			q0 -= 24
	else: # break z into 24-bit if necessary
		z = _scalbn(z, -q0)
		if z >= _TWO24:
			fw = float(int(_TWON24 * z))
			iq[jz] = int(z - _TWO24 * fw)
			jz += 1
			q0 += 24
			iq[jz] = int(fw)
		else:
			iq[jz] = int(z)

	# convert integer "bit" chunk to floating-point value
	fw = _scalbn(one, q0)
	i = jz
	while i >= 0:
		q[i] = fw * float(iq[i])
		fw *= _TWON24
		i -= 1

	# compute PIo2[0,...,jp]*q[jz,...,0]
	i = jz
	while i >= 0:
		fw = 0.0
		k = 0
		while k <= jp and k <= jz - i:
			fw += _PIO2[k] * q[i + k]
			k += 1
		fq[jz - i] = fw
		i -= 1

	# compress fq[] into y[]
	match prec:
		0:
			fw = 0.0
			i = jz
			while i >= 0:
				fw += fq[i]
				i -= 1
			y[0] = fw if ih == 0 else -fw
		1, 2:
			fw = 0.0
			i = jz
			while i >= 0:
				fw += fq[i]
				i -= 1
			y[0] = fw if ih == 0 else -fw
			fw = fq[0] - fw
			i = 1
			while i <= jz:
				fw += fq[i]
				i += 1
			y[1] = fw if ih == 0 else -fw
		_:
			push_error("JsMath: __kernel_rem_pio2 precision 3 is not ported")
	return n & 7


# ------------------------------------------------------------------ __ieee754_rem_pio2

## __ieee754_rem_pio2(x,y)
##
## return the remainder of x rem pi/2 in y[0]+y[1]
## use __kernel_rem_pio2()
##
## Table of constants for 2/pi, 396 Hex digits (476 decimal) of 2/pi
static var _TWO_OVER_PI: PackedInt32Array = PackedInt32Array([
	0xA2F983, 0x6E4E44, 0x1529FC, 0x2757D1, 0xF534DD, 0xC0DB62, 0x95993C,
	0x439041, 0xFE5163, 0xABDEBB, 0xC561B7, 0x246E3A, 0x424DD2, 0xE00649,
	0x2EEA09, 0xD1921C, 0xFE1DEB, 0x1CB129, 0xA73EE8, 0x8235F5, 0x2EBB44,
	0x84E99C, 0x7026B4, 0x5F7E41, 0x3991D6, 0x398353, 0x39F49C, 0x845F8B,
	0xBDF928, 0x3B1FF8, 0x97FFDE, 0x05980F, 0xEF2F11, 0x8B5A0A, 0x6D1F6D,
	0x367ECF, 0x27CB09, 0xB74F46, 0x3F669E, 0x5FEA2D, 0x7527BA, 0xC7EBE5,
	0xF17B3D, 0x0739F7, 0x8A5292, 0xEA6BFB, 0x5FB11F, 0x8D5D08, 0x560330,
	0x46FC7B, 0x6BABF0, 0xCFBC20, 0x9AF436, 0x1DA9E3, 0x91615E, 0xE61B08,
	0x659985, 0x5F14A0, 0x68408D, 0xFFD880, 0x4D7327, 0x310606, 0x1556CA,
	0x73A8C9, 0x60E27B, 0xC08C6B,
])

const _NPIO2_HW: Array[int] = [
	0x3FF921FB, 0x400921FB, 0x4012D97C, 0x401921FB, 0x401F6A7A, 0x4022D97C,
	0x4025FDBB, 0x402921FB, 0x402C463A, 0x402F6A7A, 0x4031475C, 0x4032D97C,
	0x40346B9C, 0x4035FDBB, 0x40378FDB, 0x403921FB, 0x403AB41B, 0x403C463A,
	0x403DD85A, 0x403F6A7A, 0x40407E4C, 0x4041475C, 0x4042106C, 0x4042D97C,
	0x4043A28C, 0x40446B9C, 0x404534AC, 0x4045FDBB, 0x4046C6CB, 0x40478FDB,
	0x404858EB, 0x404921FB,
]

## invpio2:  53 bits of 2/pi
## pio2_1:   first  33 bit of pi/2
## pio2_1t:  pi/2 - pio2_1
## pio2_2:   second 33 bit of pi/2
## pio2_2t:  pi/2 - (pio2_1+pio2_2)
## pio2_3:   third  33 bit of pi/2
## pio2_3t:  pi/2 - (pio2_1+pio2_2+pio2_3)
static var _INVPIO2: float = _from_words(0x3FE45F30, 0x6DC9C883) # 6.36619772367581382433e-01
static var _PIO2_1: float = _from_words(0x3FF921FB, 0x54400000) # 1.57079632673412561417e+00
static var _PIO2_1T: float = _from_words(0x3DD0B461, 0x1A626331) # 6.07710050650619224932e-11
static var _PIO2_2: float = _from_words(0x3DD0B461, 0x1A600000) # 6.07710050630396597660e-11
static var _PIO2_2T: float = _from_words(0x3BA3198A, 0x2E037073) # 2.02226624879595063154e-21
static var _PIO2_3: float = _from_words(0x3BA3198A, 0x2E000000) # 2.02226624871116645580e-21
static var _PIO2_3T: float = _from_words(0x397B839A, 0x252049C1) # 8.47842766036889956997e-32


static func _rem_pio2(x: float, y: PackedFloat64Array) -> int:
	var zero: float = 0.0
	var half: float = 0.5
	var z: float = 0.0
	var w: float
	var t: float
	var r: float
	var fn: float
	var n: int
	var hx: int = _hi(x) # high word of x
	var ix: int = hx & 0x7FFFFFFF
	if ix <= 0x3FE921FB: # |x| ~<= pi/4 , no need for reduction
		y[0] = x
		y[1] = 0.0
		return 0
	if ix < 0x4002D97C: # |x| < 3pi/4, special case with n=+-1
		if hx > 0:
			z = x - _PIO2_1
			if ix != 0x3FF921FB: # 33+53 bit pi is good enough
				y[0] = z - _PIO2_1T
				y[1] = (z - y[0]) - _PIO2_1T
			else: # near pi/2, use 33+33+53 bit pi
				z -= _PIO2_2
				y[0] = z - _PIO2_2T
				y[1] = (z - y[0]) - _PIO2_2T
			return 1
		else: # negative x
			z = x + _PIO2_1
			if ix != 0x3FF921FB: # 33+53 bit pi is good enough
				y[0] = z + _PIO2_1T
				y[1] = (z - y[0]) + _PIO2_1T
			else: # near pi/2, use 33+33+53 bit pi
				z += _PIO2_2
				y[0] = z + _PIO2_2T
				y[1] = (z - y[0]) + _PIO2_2T
			return -1
	if ix <= 0x413921FB: # |x| ~<= 2^19*(pi/2), medium size
		t = absf(x)
		n = int(t * _INVPIO2 + half)
		fn = float(n)
		r = t - fn * _PIO2_1
		w = fn * _PIO2_1T # 1st round good to 85 bit
		if n < 32 and ix != _NPIO2_HW[n - 1]:
			y[0] = r - w # quick check no cancellation
		else:
			var j: int = ix >> 20
			y[0] = r - w
			var high: int = _hi(y[0])
			var i: int = j - ((high >> 20) & 0x7FF)
			if i > 16: # 2nd iteration needed, good to 118
				t = r
				w = fn * _PIO2_2
				r = t - w
				w = fn * _PIO2_2T - ((t - r) - w)
				y[0] = r - w
				high = _hi(y[0])
				i = j - ((high >> 20) & 0x7FF)
				if i > 49: # 3rd iteration need, 151 bits acc
					t = r # will cover all possible cases
					w = fn * _PIO2_3
					r = t - w
					w = fn * _PIO2_3T - ((t - r) - w)
					y[0] = r - w
		y[1] = (r - y[0]) - w
		if hx < 0:
			y[0] = -y[0]
			y[1] = -y[1]
			return -n
		else:
			return n
	# all other (large) arguments
	if ix >= 0x7FF00000: # x is inf or NaN
		y[0] = x - x
		y[1] = x - x
		return 0
	# set z = scalbn(|x|,ilogb(x)-23)
	var low: int = _lo(x)
	var e0: int = (ix >> 20) - 1046 # e0 = ilogb(z)-23;
	z = _from_words(ix - (e0 << 20), low)
	var tx: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	for i: int in 2:
		tx[i] = float(int(z))
		z = (z - tx[i]) * _TWO24
	tx[2] = z
	var nx: int = 3
	while tx[nx - 1] == zero: # skip zero term
		nx -= 1
	n = _kernel_rem_pio2(tx, y, e0, nx, 2, _TWO_OVER_PI)
	if hx < 0:
		y[0] = -y[0]
		y[1] = -y[1]
		return -n
	return n


# ------------------------------------------------------------------ Math.sin, Math.cos

## y[0] and y[1] of __ieee754_rem_pio2 (a scratch array, like _buf).
static var _y: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])


## Math.sin(x) (V8's fdlibm_sin).
##
## Kernel function:
##   __kernel_sin  ... sine function on [-pi/4,pi/4]
##   __kernel_cos  ... cose function on [-pi/4,pi/4]
##   __ieee754_rem_pio2 ... argument reduction routine
##
## Method.
##   Let S,C and T denote the sin, cos and tan respectively on
##   [-PI/4, +PI/4]. Reduce the argument x to y1+y2 = x-k*pi/2
##   in [-pi/4 , +pi/4], and let n = k mod 4.
##   We have
##
##     n        sin(x)      cos(x)        tan(x)
##   ----------------------------------------------------------
##     0          S           C             T
##     1          C          -S            -1/T
##     2         -S          -C             T
##     3         -C           S            -1/T
##   ----------------------------------------------------------
##
## Special cases:
##   Let trig be any of sin, cos, or tan.
##   trig(+-INF)  is NaN, with signals;
##   trig(NaN)    is that NaN;
##
## Accuracy:
##   TRIG(x) returns trig(x) nearly rounded
static func sin(x: float) -> float:
	var z: float = 0.0
	# High word of x.
	var ix: int = _hi(x)

	# |x| ~< pi/4
	ix &= 0x7FFFFFFF
	if ix <= 0x3FE921FB:
		return _kernel_sin(x, z, 0)
	elif ix >= 0x7FF00000:
		# sin(Inf or NaN) is NaN
		return x - x
	else:
		# argument reduction needed
		var y: PackedFloat64Array = _y
		var n: int = _rem_pio2(x, y)
		match n & 3:
			0:
				return _kernel_sin(y[0], y[1], 1)
			1:
				return _kernel_cos(y[0], y[1])
			2:
				return -_kernel_sin(y[0], y[1], 1)
			_:
				return -_kernel_cos(y[0], y[1])


## Math.cos(x) (V8's fdlibm_cos). Method and accuracy as in sin().
static func cos(x: float) -> float:
	var z: float = 0.0
	# High word of x.
	var ix: int = _hi(x)

	# |x| ~< pi/4
	ix &= 0x7FFFFFFF
	if ix <= 0x3FE921FB:
		return _kernel_cos(x, z)
	elif ix >= 0x7FF00000:
		# cos(Inf or NaN) is NaN
		return x - x
	else:
		# argument reduction needed
		var y: PackedFloat64Array = _y
		var n: int = _rem_pio2(x, y)
		match n & 3:
			0:
				return _kernel_cos(y[0], y[1])
			1:
				return -_kernel_sin(y[0], y[1], 1)
			2:
				return -_kernel_cos(y[0], y[1])
			_:
				return _kernel_sin(y[0], y[1], 1)


# ------------------------------------------------------------------ atan

## atan(x)
## Method
##   1. Reduce x to positive by atan(x) = -atan(-x).
##   2. According to the integer k=4t+0.25 chopped, t=x, the argument
##      is further reduced to one of the following intervals and the
##      arctangent of t is evaluated by the corresponding formula:
##
##      [0,7/16]      atan(x) = t-t^3*(a1+t^2*(a2+...(a10+t^2*a11)...)
##      [7/16,11/16]  atan(x) = atan(1/2) + atan( (t-0.5)/(1+t/2) )
##      [11/16.19/16] atan(x) = atan( 1 ) + atan( (t-1)/(1+t) )
##      [19/16,39/16] atan(x) = atan(3/2) + atan( (t-1.5)/(1+1.5t) )
##      [39/16,INF]   atan(x) = atan(INF) + atan( -1/t )
static var _ATANHI: PackedFloat64Array = PackedFloat64Array([
	_from_words(0x3FDDAC67, 0x0561BB4F), # 4.63647609000806093515e-01 atan(0.5)hi
	_from_words(0x3FE921FB, 0x54442D18), # 7.85398163397448278999e-01 atan(1.0)hi
	_from_words(0x3FEF730B, 0xD281F69B), # 9.82793723247329054082e-01 atan(1.5)hi
	_from_words(0x3FF921FB, 0x54442D18), # 1.57079632679489655800e+00 atan(inf)hi
])
static var _ATANLO: PackedFloat64Array = PackedFloat64Array([
	_from_words(0x3C7A2B7F, 0x222F65E2), # 2.26987774529616870924e-17 atan(0.5)lo
	_from_words(0x3C81A626, 0x33145C07), # 3.06161699786838301793e-17 atan(1.0)lo
	_from_words(0x3C700788, 0x7AF0CBBD), # 1.39033110312309984516e-17 atan(1.5)lo
	_from_words(0x3C91A626, 0x33145C07), # 6.12323399573676603587e-17 atan(inf)lo
])
static var _AT: PackedFloat64Array = PackedFloat64Array([
	_from_words(0x3FD55555, 0x5555550D), # 3.33333333333329318027e-01
	_from_words(0xBFC99999, 0x9998EBC4), # -1.99999999998764832476e-01
	_from_words(0x3FC24924, 0x920083FF), # 1.42857142725034663711e-01
	_from_words(0xBFBC71C6, 0xFE231671), # -1.11111104054623557880e-01
	_from_words(0x3FB745CD, 0xC54C206E), # 9.09088713343650656196e-02
	_from_words(0xBFB3B0F2, 0xAF749A6D), # -7.69187620504482999495e-02
	_from_words(0x3FB10D66, 0xA0D03D51), # 6.66107313738753120669e-02
	_from_words(0xBFADDE2D, 0x52DEFD9A), # -5.83357013379057348645e-02
	_from_words(0x3FA97B4B, 0x24760DEB), # 4.97687799461593236017e-02
	_from_words(0xBFA2B444, 0x2C6A6C2F), # -3.65315727442169155270e-02
	_from_words(0x3F90AD3A, 0xE322DA11), # 1.62858201153657823623e-02
])
static var _HUGE: float = _from_words(0x7E37E43C, 0x8800759C) # 1.0e300


static func _atan(x: float) -> float:
	var one: float = 1.0
	var w: float
	var s1: float
	var s2: float
	var z: float
	var id: int

	var hx: int = _hi(x)
	var ix: int = hx & 0x7FFFFFFF
	if ix >= 0x44100000: # if |x| >= 2^66
		var low: int = _lo(x)
		if ix > 0x7FF00000 or (ix == 0x7FF00000 and low != 0):
			return x + x # NaN
		if hx > 0:
			return _ATANHI[3] + _ATANLO[3]
		else:
			return -_ATANHI[3] - _ATANLO[3]
	if ix < 0x3FDC0000: # |x| < 0.4375
		if ix < 0x3E400000: # |x| < 2^-27
			if _HUGE + x > one:
				return x # raise inexact
		id = -1
	else:
		x = absf(x)
		if ix < 0x3FF30000: # |x| < 1.1875
			if ix < 0x3FE60000: # 7/16 <=|x|<11/16
				id = 0
				x = (2.0 * x - one) / (2.0 + x)
			else: # 11/16<=|x|< 19/16
				id = 1
				x = (x - one) / (x + one)
		else:
			if ix < 0x40038000: # |x| < 2.4375
				id = 2
				x = (x - 1.5) / (one + 1.5 * x)
			else: # 2.4375 <= |x| < 2^66
				id = 3
				x = -1.0 / x
	# end of argument reduction
	z = x * x
	w = z * z
	# break sum from i=0 to 10 aT[i]z**(i+1) into odd and even poly
	s1 = z * (_AT[0] + w * (_AT[2] + w * (_AT[4] + w * (_AT[6] + w * (_AT[8] + w * _AT[10])))))
	s2 = w * (_AT[1] + w * (_AT[3] + w * (_AT[5] + w * (_AT[7] + w * _AT[9]))))
	if id < 0:
		return x - x * (s1 + s2)
	else:
		z = _ATANHI[id] - ((x * (s1 + s2) - _ATANLO[id]) - x)
		return -z if hx < 0 else z


# ------------------------------------------------------------------ Math.atan2

## Math.atan2(y, x)
## Method :
##   1. Reduce y to positive by atan2(y,x)=-atan2(-y,x).
##   2. Reduce x to positive by (if x and y are unexceptional):
##      ARG (x+iy) = arctan(y/x)       ... if x > 0,
##      ARG (x+iy) = pi - arctan[y/(-x)]   ... if x < 0,
##
## Special cases:
##
##   ATAN2((anything), NaN ) is NaN;
##   ATAN2(NAN , (anything) ) is NaN;
##   ATAN2(+-0, +(anything but NaN)) is +-0  ;
##   ATAN2(+-0, -(anything but NaN)) is +-pi ;
##   ATAN2(+-(anything but 0 and NaN), 0) is +-pi/2;
##   ATAN2(+-(anything but INF and NaN), +INF) is +-0 ;
##   ATAN2(+-(anything but INF and NaN), -INF) is +-pi;
##   ATAN2(+-INF,+INF ) is +-pi/4 ;
##   ATAN2(+-INF,-INF ) is +-3pi/4;
##   ATAN2(+-INF, (anything but,0,NaN, and INF)) is +-pi/2;
static var _PI_O_4: float = _from_words(0x3FE921FB, 0x54442D18) # 7.8539816339744827900E-01
static var _PI_O_2: float = _from_words(0x3FF921FB, 0x54442D18) # 1.5707963267948965580E+00
static var _PI: float = _from_words(0x400921FB, 0x54442D18) # 3.1415926535897931160E+00
static var _PI_LO: float = _from_words(0x3CA1A626, 0x33145C07) # 1.2246467991473531772E-16


static func atan2(y: float, x: float) -> float:
	# a variable, not a literal: GDScript reads the literal -0.0 as +0.0
	var zero: float = 0.0
	var z: float
	var hx: int = _hi(x)
	var lx: int = _lo(x)
	var ix: int = hx & 0x7FFFFFFF
	var hy: int = _hi(y)
	var ly: int = _lo(y)
	var iy: int = hy & 0x7FFFFFFF
	# ((ix | ((lx | -lx) >> 31)) > 0x7FF00000) || ((iy | ((ly | -ly) >> 31)) > 0x7FF00000)
	if is_nan(x) or is_nan(y):
		return x + y # x or y is NaN
	if ((hx - 0x3FF00000) | lx) == 0:
		return _atan(y) # x=1.0
	var m: int = ((hy >> 31) & 1) | ((hx >> 30) & 2) # 2*sign(x)+sign(y)

	# when y = 0
	if (iy | ly) == 0:
		match m:
			0, 1:
				return y # atan(+-0,+anything)=+-0
			2:
				return _PI # pi + tiny: atan(+0,-anything) = pi
			3:
				return -_PI # -pi - tiny: atan(-0,-anything) =-pi
	# when x = 0
	if (ix | lx) == 0:
		return -_PI_O_2 if hy < 0 else _PI_O_2 # -+pi_o_2 -+ tiny

	# when x is INF
	if ix == 0x7FF00000:
		if iy == 0x7FF00000:
			match m:
				0:
					return _PI_O_4 # + tiny: atan(+INF,+INF)
				1:
					return -_PI_O_4 # - tiny: atan(-INF,+INF)
				2:
					return 3.0 * _PI_O_4 # + tiny: atan(+INF,-INF)
				3:
					return -3.0 * _PI_O_4 # - tiny: atan(-INF,-INF)
		else:
			match m:
				0:
					return zero # atan(+...,+INF)
				1:
					return -zero # atan(-...,+INF)
				2:
					return _PI # + tiny: atan(+...,-INF)
				3:
					return -_PI # - tiny: atan(-...,-INF)
	# when y is INF
	if iy == 0x7FF00000:
		return -_PI_O_2 if hy < 0 else _PI_O_2 # -+pi_o_2 -+ tiny

	# compute y/x
	var k: int = (iy - ix) >> 20
	if k > 60: # |y/x| >  2**60
		z = _PI_O_2 + 0.5 * _PI_LO
		m &= 1
	elif hx < 0 and k < -60:
		z = 0.0 # 0 > |y|/x > -2**-60
	else:
		z = _atan(absf(y / x)) # safe to do y/x
	match m:
		0:
			return z # atan(+,+)
		1:
			return -z # atan(-,+)
		2:
			return _PI - (z - _PI_LO) # atan(+,-)
		_: # case 3
			return (z - _PI_LO) - _PI # atan(-,-)
