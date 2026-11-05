obj-m += typec_displayport.o
obj-m += fsa4480.o
obj-m += ps5169.o
# Select real prototypes in the private DP header, not disabled-config stubs.
# This affects only this external translation unit, not the kernel config.
CFLAGS_typec_displayport.o += -DCONFIG_TYPEC_DP_ALTMODE_MODULE=1
CFLAGS_ps5169.o += -include $(src)/compat-6.12.h
