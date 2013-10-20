#!/usr/bin/make -f
# Makefile for Carla C++ code #
# --------------------------- #
# Created by falkTX
#

# --------------------------------------------------------------
# Modify to enable/disable specific features

# Support for LADSPA, DSSI, LV2, VST and AU plugins
CARLA_PLUGIN_SUPPORT = true

# Support for csound files (version 6)
CARLA_CSOUND_SUPPORT = true

# Support for GIG, SF2 and SFZ sample banks (through fluidsynth and linuxsampler)
CARLA_SAMPLERS_SUPPORT = true

# Use the free vestige header instead of the official VST SDK
# CARLA_VESTIGE_HEADER = true

# --------------------------------------------------------------
# DO NOT MODIFY PAST THIS POINT!

AR  ?= ar
CC  ?= gcc
CXX ?= g++
MOC ?= moc
RCC ?= rcc
UIC ?= uic

# --------------------------------------------------------------
# Fallback to Linux if no other OS defined

ifneq ($(HAIKU),true)
ifneq ($(MACOS),true)
ifneq ($(WIN32),true)
LINUX=true
endif
endif
endif

# --------------------------------------------------------------
# Common build and link flags

BASE_FLAGS = -Wall -Wextra -fPIC -DPIC -pipe -DREAL_BUILD
BASE_OPTS  = -O3 -ffast-math -mtune=generic -msse -msse2 -mfpmath=sse -fdata-sections -ffunction-sections
LINK_OPTS  = -Wl,--gc-sections

ifeq ($(RASPPI),true)
# Raspberry-Pi optimization flags
BASE_OPTS  = -O3 -ffast-math -march=armv6 -mfpu=vfp -mfloat-abi=hard
LINK_OPTS  =
endif

ifeq ($(DEBUG),true)
BASE_FLAGS += -DDEBUG -O0 -g
LINK_OPTS   =
else
BASE_FLAGS += -DNDEBUG $(BASE_OPTS) -fvisibility=hidden
CXXFLAGS   += -fvisibility-inlines-hidden
LINK_OPTS  += -Wl,--strip-all
endif

32BIT_FLAGS = -m32
64BIT_FLAGS = -m64

BUILD_C_FLAGS   = $(BASE_FLAGS) -std=gnu99 $(CFLAGS)
BUILD_CXX_FLAGS = $(BASE_FLAGS) -std=gnu++0x $(CXXFLAGS)
LINK_FLAGS      = $(LINK_OPTS) -Wl,--no-undefined $(LDFLAGS)

ifeq ($(MACOS),true)
# No C++11 support; force 32bit per default
BUILD_C_FLAGS   = $(BASE_FLAGS) $(32BIT_FLAGS) -std=gnu99 $(CFLAGS)
BUILD_CXX_FLAGS = $(BASE_FLAGS) $(32BIT_FLAGS) $(CXXFLAGS)
LINK_FLAGS      = $(32BIT_FLAGS) $(LDFLAGS)
endif

# --------------------------------------------------------------
# Check for required libs

ifneq ($(shell pkg-config --exists liblo && echo true),true)
$(error liblo missing, cannot continue)
endif

ifeq ($(LINUX),true)
ifneq ($(shell pkg-config --exists x11 && echo true),true)
$(error X11 missing, cannot continue)
endif
ifneq ($(shell pkg-config --exists xinerama && echo true),true)
$(error Xinerama missing, cannot continue)
endif
ifneq ($(shell pkg-config --exists xext && echo true),true)
$(error Xext missing, cannot continue)
endif
ifneq ($(shell pkg-config --exists xcursor && echo true),true)
$(error Xcursor missing, cannot continue)
endif
ifneq ($(shell pkg-config --exists freetype2 && echo true),true)
$(error FreeType2 missing, cannot continue)
endif
endif

# --------------------------------------------------------------
# Check for optional libs (required by backend or bridges)

HAVE_FFMPEG       = $(shell pkg-config --exists libavcodec libavformat libavutil && pkg-config --max-version=1.9 libavcodec && echo true)

ifeq ($(LINUX),true)
HAVE_ALSA         = $(shell pkg-config --exists alsa && echo true)
HAVE_GTK2         = $(shell pkg-config --exists gtk+-2.0 && echo true)
HAVE_GTK3         = $(shell pkg-config --exists gtk+-3.0 && echo true)
HAVE_PULSEAUDIO   = $(shell pkg-config --exists libpulse-simple && echo true)
HAVE_QT4          = $(shell pkg-config --exists QtCore QtGui && echo true)
HAVE_QT5          = $(shell pkg-config --exists Qt5Core Qt5Gui Qt5Widgets && echo true)
HAVE_OPENGL       = $(shell pkg-config --exists gl && echo true)
else
HAVE_OPENGL       = true
endif

ifeq ($(CARLA_SAMPLERS_SUPPORT),true)
HAVE_FLUIDSYNTH   = $(shell pkg-config --exists fluidsynth && echo true)
HAVE_LINUXSAMPLER = $(shell pkg-config --exists linuxsampler && echo true)
endif

# --------------------------------------------------------------
# Check for optional libs (required by internal plugins)

HAVE_AF_DEPS       = $(shell pkg-config --exists sndfile && echo true)
HAVE_MF_DEPS       = $(shell pkg-config --exists smf && echo true)
HAVE_ZYN_DEPS      = $(shell pkg-config --exists fftw3 mxml zlib && echo true)
HAVE_ZYN_UI_DEPS   = $(shell pkg-config --exists ntk ntk_images && echo true)

# --------------------------------------------------------------
# Set Juce flags

ifeq ($(HAIKU),true)
endif

ifeq ($(LINUX),true)
ifeq ($(HAVE_OPENGL),true)
DGL_FLAGS                = $(shell pkg-config --cflags gl x11)
DGL_LIBS                 = $(shell pkg-config --libs gl x11)
endif
LILV_LIBS                = -lrt -ldl
JUCE_CORE_LIBS           = -lrt -ldl -lpthread
JUCE_EVENTS_FLAGS        = $(shell pkg-config --cflags x11)
JUCE_EVENTS_LIBS         = $(shell pkg-config --libs x11)
JUCE_GRAPHICS_FLAGS      = $(shell pkg-config --cflags x11 xinerama xext freetype2)
JUCE_GRAPHICS_LIBS       = $(shell pkg-config --libs x11 xinerama xext freetype2)
JUCE_GUI_BASICS_FLAGS    = $(shell pkg-config --cflags x11 xinerama xext xcursor)
JUCE_GUI_BASICS_LIBS     = $(shell pkg-config --libs x11 xinerama xext xcursor) -ldl
endif

ifeq ($(MACOS),true)
DGL_LIBS                = -framework OpenGL -framework Cocoa
LILV_LIBS               = -ldl
JUCE_AUDIO_BASICS_LIBS  = -framework Accelerate
JUCE_AUDIO_DEVICES_LIBS = -framework CoreAudio -framework CoreMIDI -framework DiscRecording
JUCE_AUDIO_FORMATS_LIBS = -framework CoreAudio -framework CoreMIDI -framework QuartzCore -framework AudioToolbox
JUCE_CORE_LIBS          = -framework Cocoa -framework IOKit
JUCE_GRAPHICS_LIBS      = -framework Cocoa -framework QuartzCore
JUCE_GUI_BASICS_LIBS    = -framework Cocoa -framework Carbon -framework QuartzCore
endif

ifeq ($(WIN32),true)
DGL_LIBS                = -lopengl32 -lgdi32
JUCE_AUDIO_DEVICES_LIBS = -lwinmm -lole32
JUCE_CORE_LIBS          = -luuid -lwsock32 -lwininet -lversion -lole32 -lws2_32 -loleaut32 -limm32 -lcomdlg32 -lshlwapi -lrpcrt4 -lwinmm
JUCE_EVENTS_LIBS        = -lole32
JUCE_GRAPHICS_LIBS      = -lgdi32
JUCE_GUI_BASICS_LIBS    = -lgdi32 -limm32 -lcomdlg32 -lole32
endif

# --------------------------------------------------------------
# Set Qt4 tools

ifeq ($(HAVE_QT4),true)
MOC_QT4 ?= $(shell pkg-config --variable=moc_location QtCore)
RCC_QT4 ?= $(shell pkg-config --variable=rcc_location QtCore)
UIC_QT4 ?= $(shell pkg-config --variable=uic_location QtCore)
endif

# --------------------------------------------------------------
