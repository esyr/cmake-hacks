# Contains variable names which should be used as include dirs/libraries for
# different packages/components.

## X11
set(DEP_DISCOVERY_HACK_X11_Xext_INCLUDE_DIR)
foreach(_comp "dpms" "XShm"  "Xshape" "XSync")
    list(APPEND DEP_DISCOVERY_HACK_X11_Xext_INCLUDE_DIR
        "X11_${_comp}_INCLUDE_PATH")
    set(DEP_DISCOVERY_HACK_X11_${_comp}_LIB "X11_Xext_LIB")
endforeach ()
set(DEP_DISCOVERY_HACK_X11_Xlib_LIB "X11_X11_LIB")
set(DEP_DISCOVERY_HACK_X11_xf86misc_LIB "X11_Xxf86misc_LIB")
set(DEP_DISCOVERY_HACK_X11_xf86vmode_LIB "X11_Xxf86vm_LIB")

# Threads
set(DEP_DISCOVERY_HACK_Threads_LIB "CMAKE_THREADS_LIB_INIT")
