"""Offscreen GPU clear/readback; no window, modeset, or persistent changes."""
import ctypes as c
import os
os.environ['EGL_PLATFORM'] = 'surfaceless'
os.environ.pop('LIBGL_ALWAYS_SOFTWARE', None)
egl = c.CDLL('libEGL.so.1')
gl = c.CDLL('libGLESv2.so.2')
P, I = c.c_void_p, c.c_int
def bind(lib, name, restype, *args):
    f = getattr(lib, name)
    f.restype, f.argtypes = restype, args
    return f
getdisplay = bind(egl, 'eglGetDisplay', P, P)
init = bind(egl, 'eglInitialize', I, P, c.POINTER(I), c.POINTER(I))
choose = bind(egl, 'eglChooseConfig', I, P, c.POINTER(I), c.POINTER(P), I, c.POINTER(I))
api = bind(egl, 'eglBindAPI', I, c.c_uint)
surface = bind(egl, 'eglCreatePbufferSurface', P, P, P, c.POINTER(I))
context = bind(egl, 'eglCreateContext', P, P, P, P, c.POINTER(I))
current = bind(egl, 'eglMakeCurrent', I, P, P, P, P)
getstr = bind(gl, 'glGetString', c.c_char_p, c.c_uint)
clearcolor = bind(gl, 'glClearColor', None, c.c_float, c.c_float, c.c_float, c.c_float)
clear = bind(gl, 'glClear', None, c.c_uint)
finish = bind(gl, 'glFinish', None)
read = bind(gl, 'glReadPixels', None, I, I, I, I, c.c_uint, c.c_uint, P)
error = bind(gl, 'glGetError', c.c_uint)
d = getdisplay(None)
major, minor = I(), I()
assert init(d, c.byref(major), c.byref(minor)), 'eglInitialize'
cfg, count = P(), I()
attrs = (I * 13)(0x3033, 1, 0x3040, 4, 0x3024, 8, 0x3023, 8, 0x3022, 8, 0x3021, 8, 0x3038)
assert choose(d, attrs, c.byref(cfg), 1, c.byref(count)) and count.value, 'config'
assert api(0x30A0)
s = surface(d, cfg, (I * 5)(0x3057, 16, 0x3056, 16, 0x3038))
ctx = context(d, cfg, None, (I * 3)(0x3098, 2, 0x3038))
assert s and ctx and current(d, s, s, ctx), 'context'
renderer = getstr(0x1F01).decode()
print('RENDERER', renderer, flush=True)
assert 'FD650' in renderer, 'not the intended hardware renderer'
for index, color in enumerate(((1, 0, 0, 1), (0, 1, 0, 1), (0, 0, 1, 1))):
    clearcolor(*color)
    clear(0x4000)
    finish()
    pixel = (c.c_ubyte * 4)()
    read(0, 0, 1, 1, 0x1908, 0x1401, pixel)
    err = error()
    expected = tuple(int(v * 255) for v in color)
    print('READBACK', index, tuple(pixel), 'error', hex(err), flush=True)
    assert err == 0 and tuple(pixel) == expected, 'GPU readback failed'
print('PASS: three GPU clears and exact pixel readbacks', flush=True)
