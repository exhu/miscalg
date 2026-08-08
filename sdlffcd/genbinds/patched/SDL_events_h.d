/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2026 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/

/**
 * # CategoryEvents
 *
 * Event queue management.
 *
 * It's extremely common--often required--that an app deal with SDL's event
 * queue. Almost all useful information about interactions with the real world
 * flow through here: the user interacting with the computer and app, hardware
 * coming and going, the system changing in some way, etc.
 *
 * An app generally takes a moment, perhaps at the start of a new frame, to
 * examine any events that have occurred since the last time and process or
 * ignore them. This is generally done by calling SDL_PollEvent() in a loop
 * until it returns false (or, if using the main callbacks, events are
 * provided one at a time in calls to SDL_AppEvent() before the next call to
 * SDL_AppIterate(); in this scenario, the app does not call SDL_PollEvent()
 * at all).
 *
 * There is other forms of control, too: SDL_PeepEvents() has more
 * functionality at the cost of more complexity, and SDL_WaitEvent() can block
 * the process until something interesting happens, which might be beneficial
 * for certain types of programs on low-power hardware. One may also call
 * SDL_AddEventWatch() to set a callback when new events arrive.
 *
 * The app is free to generate their own events, too: SDL_PushEvent allows the
 * app to put events onto the queue for later retrieval; SDL_RegisterEvents
 * can guarantee that these events have a type that isn't in use by other
 * parts of the system.
 */

extern (C):

/* Set up for C function definitions, even when using C++ */

/* General keyboard/mouse/pen state definitions */

/**
 * The types of events that can be delivered.
 *
 * \since This enum is available since SDL 3.2.0.
 */
enum SDL_EventType
{
    SDL_EVENT_FIRST = 0, /**< Unused (do not remove) */

    /* Application events */
    SDL_EVENT_QUIT = 0x100, /**< User-requested quit */

    /* These application events have special meaning on iOS and Android, see README-ios.md and README-android.md for details */
    SDL_EVENT_TERMINATING = 257, /**< The application is being terminated by the OS. This event must be handled in a callback set with SDL_AddEventWatch().
         Called on iOS in applicationWillTerminate()
         Called on Android in onDestroy()
    */
    SDL_EVENT_LOW_MEMORY = 258, /**< The application is low on memory, free memory if possible. This event must be handled in a callback set with SDL_AddEventWatch().
         Called on iOS in applicationDidReceiveMemoryWarning()
         Called on Android in onTrimMemory()
    */
    SDL_EVENT_WILL_ENTER_BACKGROUND = 259, /**< The application is about to enter the background. This event must be handled in a callback set with SDL_AddEventWatch().
         Called on iOS in applicationWillResignActive()
         Called on Android in onPause()
    */
    SDL_EVENT_DID_ENTER_BACKGROUND = 260, /**< The application did enter the background and may not get CPU for some time. This event must be handled in a callback set with SDL_AddEventWatch().
         Called on iOS in applicationDidEnterBackground()
         Called on Android in onPause()
    */
    SDL_EVENT_WILL_ENTER_FOREGROUND = 261, /**< The application is about to enter the foreground. This event must be handled in a callback set with SDL_AddEventWatch().
         Called on iOS in applicationWillEnterForeground()
         Called on Android in onResume()
    */
    SDL_EVENT_DID_ENTER_FOREGROUND = 262, /**< The application is now interactive. This event must be handled in a callback set with SDL_AddEventWatch().
         Called on iOS in applicationDidBecomeActive()
         Called on Android in onResume()
    */

    SDL_EVENT_LOCALE_CHANGED = 263, /**< The user's locale preferences have changed. */

    SDL_EVENT_SYSTEM_THEME_CHANGED = 264, /**< The system theme changed */

    /* Display events */
    /* 0x150 was SDL_DISPLAYEVENT, reserve the number for sdl2-compat */
    SDL_EVENT_DISPLAY_ORIENTATION = 0x151, /**< Display orientation has changed to data1 */
    SDL_EVENT_DISPLAY_ADDED = 338, /**< Display has been added to the system */
    SDL_EVENT_DISPLAY_REMOVED = 339, /**< Display has been removed from the system */
    SDL_EVENT_DISPLAY_MOVED = 340, /**< Display has changed position */
    SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED = 341, /**< Display has changed desktop mode */
    SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED = 342, /**< Display has changed current mode */
    SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED = 343, /**< Display has changed content scale */
    SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED = 344, /**< Display has changed usable bounds */
    SDL_EVENT_DISPLAY_FIRST = SDL_EVENT_DISPLAY_ORIENTATION,
    SDL_EVENT_DISPLAY_LAST = SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED,

    /* Window events */
    /* 0x200 was SDL_WINDOWEVENT, reserve the number for sdl2-compat */
    /* 0x201 was SDL_SYSWMEVENT, reserve the number for sdl2-compat */
    SDL_EVENT_WINDOW_SHOWN = 0x202, /**< Window has been shown */
    SDL_EVENT_WINDOW_HIDDEN = 515, /**< Window has been hidden */
    SDL_EVENT_WINDOW_EXPOSED = 516, /**< Window has been exposed and should be redrawn, and can be redrawn directly from event watchers for this event.
         data1 is 1 for live-resize expose events, 0 otherwise. */
    SDL_EVENT_WINDOW_MOVED = 517, /**< Window has been moved to data1, data2 */
    SDL_EVENT_WINDOW_RESIZED = 518, /**< Window has been resized to data1xdata2 */
    SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED = 519, /**< The pixel size of the window has changed to data1xdata2 */
    SDL_EVENT_WINDOW_METAL_VIEW_RESIZED = 520, /**< The pixel size of a Metal view associated with the window has changed */
    SDL_EVENT_WINDOW_MINIMIZED = 521, /**< Window has been minimized */
    SDL_EVENT_WINDOW_MAXIMIZED = 522, /**< Window has been maximized */
    SDL_EVENT_WINDOW_RESTORED = 523, /**< Window has been restored to normal size and position */
    SDL_EVENT_WINDOW_MOUSE_ENTER = 524, /**< Window has gained mouse focus */
    SDL_EVENT_WINDOW_MOUSE_LEAVE = 525, /**< Window has lost mouse focus */
    SDL_EVENT_WINDOW_FOCUS_GAINED = 526, /**< Window has gained keyboard focus */
    SDL_EVENT_WINDOW_FOCUS_LOST = 527, /**< Window has lost keyboard focus */
    SDL_EVENT_WINDOW_CLOSE_REQUESTED = 528, /**< The window manager requests that the window be closed */
    SDL_EVENT_WINDOW_HIT_TEST = 529, /**< Window had a hit test that wasn't SDL_HITTEST_NORMAL */
    SDL_EVENT_WINDOW_ICCPROF_CHANGED = 530, /**< The ICC profile of the window's display has changed */
    SDL_EVENT_WINDOW_DISPLAY_CHANGED = 531, /**< Window has been moved to display data1 */
    SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED = 532, /**< Window display scale has been changed */
    SDL_EVENT_WINDOW_SAFE_AREA_CHANGED = 533, /**< The window safe area has been changed */
    SDL_EVENT_WINDOW_OCCLUDED = 534, /**< The window has been occluded */
    SDL_EVENT_WINDOW_ENTER_FULLSCREEN = 535, /**< The window has entered fullscreen mode */
    SDL_EVENT_WINDOW_LEAVE_FULLSCREEN = 536, /**< The window has left fullscreen mode */
    SDL_EVENT_WINDOW_DESTROYED = 537, /**< The window with the associated ID is being or has been destroyed. If this message is being handled
         in an event watcher, the window handle is still valid and can still be used to retrieve any properties
         associated with the window. Otherwise, the handle has already been destroyed and all resources
         associated with it are invalid */
    SDL_EVENT_WINDOW_HDR_STATE_CHANGED = 538, /**< Window HDR properties have changed */
    SDL_EVENT_WINDOW_FIRST = SDL_EVENT_WINDOW_SHOWN,
    SDL_EVENT_WINDOW_LAST = SDL_EVENT_WINDOW_HDR_STATE_CHANGED,

    /* Keyboard events */
    SDL_EVENT_KEY_DOWN = 0x300, /**< Key pressed */
    SDL_EVENT_KEY_UP = 769, /**< Key released */
    SDL_EVENT_TEXT_EDITING = 770, /**< Keyboard text editing (composition) */
    SDL_EVENT_TEXT_INPUT = 771, /**< Keyboard text input */
    SDL_EVENT_KEYMAP_CHANGED = 772, /**< Keymap changed due to a system event such as an
         input language or keyboard layout change. */
    SDL_EVENT_KEYBOARD_ADDED = 773, /**< A new keyboard has been inserted into the system */
    SDL_EVENT_KEYBOARD_REMOVED = 774, /**< A keyboard has been removed */
    SDL_EVENT_TEXT_EDITING_CANDIDATES = 775, /**< Keyboard text editing candidates */
    SDL_EVENT_SCREEN_KEYBOARD_SHOWN = 776, /**< The on-screen keyboard has been shown */
    SDL_EVENT_SCREEN_KEYBOARD_HIDDEN = 777, /**< The on-screen keyboard has been hidden */

    /* Mouse events */
    SDL_EVENT_MOUSE_MOTION = 0x400, /**< Mouse moved */
    SDL_EVENT_MOUSE_BUTTON_DOWN = 1025, /**< Mouse button pressed */
    SDL_EVENT_MOUSE_BUTTON_UP = 1026, /**< Mouse button released */
    SDL_EVENT_MOUSE_WHEEL = 1027, /**< Mouse wheel motion */
    SDL_EVENT_MOUSE_ADDED = 1028, /**< A new mouse has been inserted into the system */
    SDL_EVENT_MOUSE_REMOVED = 1029, /**< A mouse has been removed */

    /* Joystick events */
    SDL_EVENT_JOYSTICK_AXIS_MOTION = 0x600, /**< Joystick axis motion */
    SDL_EVENT_JOYSTICK_BALL_MOTION = 1537, /**< Joystick trackball motion */
    SDL_EVENT_JOYSTICK_HAT_MOTION = 1538, /**< Joystick hat position change */
    SDL_EVENT_JOYSTICK_BUTTON_DOWN = 1539, /**< Joystick button pressed */
    SDL_EVENT_JOYSTICK_BUTTON_UP = 1540, /**< Joystick button released */
    SDL_EVENT_JOYSTICK_ADDED = 1541, /**< A new joystick has been inserted into the system */
    SDL_EVENT_JOYSTICK_REMOVED = 1542, /**< An opened joystick has been removed */
    SDL_EVENT_JOYSTICK_BATTERY_UPDATED = 1543, /**< Joystick battery level change */
    SDL_EVENT_JOYSTICK_UPDATE_COMPLETE = 1544, /**< Joystick update is complete */

    /* Gamepad events */
    SDL_EVENT_GAMEPAD_AXIS_MOTION = 0x650, /**< Gamepad axis motion */
    SDL_EVENT_GAMEPAD_BUTTON_DOWN = 1617, /**< Gamepad button pressed */
    SDL_EVENT_GAMEPAD_BUTTON_UP = 1618, /**< Gamepad button released */
    SDL_EVENT_GAMEPAD_ADDED = 1619, /**< A new gamepad has been inserted into the system */
    SDL_EVENT_GAMEPAD_REMOVED = 1620, /**< A gamepad has been removed */
    SDL_EVENT_GAMEPAD_REMAPPED = 1621, /**< The gamepad mapping was updated */
    SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN = 1622, /**< Gamepad touchpad was touched */
    SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION = 1623, /**< Gamepad touchpad finger was moved */
    SDL_EVENT_GAMEPAD_TOUCHPAD_UP = 1624, /**< Gamepad touchpad finger was lifted */
    SDL_EVENT_GAMEPAD_SENSOR_UPDATE = 1625, /**< Gamepad sensor was updated */
    SDL_EVENT_GAMEPAD_UPDATE_COMPLETE = 1626, /**< Gamepad update is complete */
    SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED = 1627, /**< Gamepad Steam handle has changed */

    /* Touch events */
    SDL_EVENT_FINGER_DOWN = 0x700,
    SDL_EVENT_FINGER_UP = 1793,
    SDL_EVENT_FINGER_MOTION = 1794,
    SDL_EVENT_FINGER_CANCELED = 1795,

    /* Pinch events */
    SDL_EVENT_PINCH_BEGIN = 0x710, /**< Pinch gesture started */
    SDL_EVENT_PINCH_UPDATE = 1809, /**< Pinch gesture updated */
    SDL_EVENT_PINCH_END = 1810, /**< Pinch gesture ended */

    /* 0x800, 0x801, and 0x802 were the Gesture events from SDL2. Do not reuse these values! sdl2-compat needs them! */

    /* Clipboard events */
    SDL_EVENT_CLIPBOARD_UPDATE = 0x900, /**< The clipboard changed */

    /* Drag and drop events */
    SDL_EVENT_DROP_FILE = 0x1000, /**< The system requests a file open */
    SDL_EVENT_DROP_TEXT = 4097, /**< text/plain drag-and-drop event */
    SDL_EVENT_DROP_BEGIN = 4098, /**< A new set of drops is beginning (NULL filename) */
    SDL_EVENT_DROP_COMPLETE = 4099, /**< Current set of drops is now complete (NULL filename) */
    SDL_EVENT_DROP_POSITION = 4100, /**< Position while moving over the window */

    /* Audio hotplug events */
    SDL_EVENT_AUDIO_DEVICE_ADDED = 0x1100, /**< A new audio device is available */
    SDL_EVENT_AUDIO_DEVICE_REMOVED = 4353, /**< An audio device has been removed. */
    SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED = 4354, /**< An audio device's format has been changed by the system. */

    /* Sensor events */
    SDL_EVENT_SENSOR_UPDATE = 0x1200, /**< A sensor was updated */

    /* Pressure-sensitive pen events */
    SDL_EVENT_PEN_PROXIMITY_IN = 0x1300, /**< Pressure-sensitive pen has become available */
    SDL_EVENT_PEN_PROXIMITY_OUT = 4865, /**< Pressure-sensitive pen has become unavailable */
    SDL_EVENT_PEN_DOWN = 4866, /**< Pressure-sensitive pen touched drawing surface */
    SDL_EVENT_PEN_UP = 4867, /**< Pressure-sensitive pen stopped touching drawing surface */
    SDL_EVENT_PEN_BUTTON_DOWN = 4868, /**< Pressure-sensitive pen button pressed */
    SDL_EVENT_PEN_BUTTON_UP = 4869, /**< Pressure-sensitive pen button released */
    SDL_EVENT_PEN_MOTION = 4870, /**< Pressure-sensitive pen is moving on the tablet */
    SDL_EVENT_PEN_AXIS = 4871, /**< Pressure-sensitive pen angle/pressure/etc changed */

    /* Camera hotplug events */
    SDL_EVENT_CAMERA_DEVICE_ADDED = 0x1400, /**< A new camera device is available */
    SDL_EVENT_CAMERA_DEVICE_REMOVED = 5121, /**< A camera device has been removed. */
    SDL_EVENT_CAMERA_DEVICE_APPROVED = 5122, /**< A camera device has been approved for use by the user. */
    SDL_EVENT_CAMERA_DEVICE_DENIED = 5123, /**< A camera device has been denied for use by the user. */

    /* Render events */
    SDL_EVENT_RENDER_TARGETS_RESET = 0x2000, /**< The render targets have been reset and their contents need to be updated */
    SDL_EVENT_RENDER_DEVICE_RESET = 8193, /**< The device has been reset and all textures need to be recreated */
    SDL_EVENT_RENDER_DEVICE_LOST = 8194, /**< The device has been lost and can't be recovered. */

    /* Reserved events for private platforms */
    SDL_EVENT_PRIVATE0 = 0x4000,
    SDL_EVENT_PRIVATE1 = 16385,
    SDL_EVENT_PRIVATE2 = 16386,
    SDL_EVENT_PRIVATE3 = 16387,

    /* Internal events */
    SDL_EVENT_POLL_SENTINEL = 0x7F00, /**< Signals the end of an event poll cycle */

    /** Events SDL_EVENT_USER through SDL_EVENT_LAST are for your use,
     *  and should be allocated with SDL_RegisterEvents()
     */
    SDL_EVENT_USER = 0x8000,

    /**
     *  This last event is only for bounding internal arrays
     */
    SDL_EVENT_LAST = 0xFFFF,

    /* This just makes sure the enum is the size of Uint32 */
    SDL_EVENT_ENUM_PADDING = 0x7FFFFFFF
}

/**
 * Fields shared by every event
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_CommonEvent
{
    Uint32 type; /**< Event type, shared with all events, Uint32 to cover user events which are not in the SDL_EventType enumeration */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
}

/**
 * Display state change event data (event.display.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_DisplayEvent
{
    SDL_EventType type; /**< SDL_EVENT_DISPLAY_* */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_DisplayID displayID; /**< The associated display */
    Sint32 data1; /**< event dependent data */
    Sint32 data2; /**< event dependent data */
}

/**
 * Window state change event data (event.window.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_WindowEvent
{
    SDL_EventType type; /**< SDL_EVENT_WINDOW_* */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The associated window */
    Sint32 data1; /**< event dependent data */
    Sint32 data2; /**< event dependent data */
}

/**
 * Keyboard device event structure (event.kdevice.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_KeyboardDeviceEvent
{
    SDL_EventType type; /**< SDL_EVENT_KEYBOARD_ADDED or SDL_EVENT_KEYBOARD_REMOVED */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_KeyboardID which; /**< The keyboard instance id */
}

/**
 * Keyboard button event structure (event.key.*)
 *
 * The `key` is the base SDL_Keycode generated by pressing the `scancode`
 * using the current keyboard layout, applying any options specified in
 * SDL_HINT_KEYCODE_OPTIONS. You can get the SDL_Keycode corresponding to the
 * event scancode and modifiers directly from the keyboard layout, bypassing
 * SDL_HINT_KEYCODE_OPTIONS, by calling SDL_GetKeyFromScancode().
 *
 * \since This struct is available since SDL 3.2.0.
 *
 * \sa SDL_GetKeyFromScancode
 * \sa SDL_HINT_KEYCODE_OPTIONS
 */
struct SDL_KeyboardEvent
{
    SDL_EventType type; /**< SDL_EVENT_KEY_DOWN or SDL_EVENT_KEY_UP */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with keyboard focus, if any */
    SDL_KeyboardID which; /**< The keyboard instance id, or 0 if unknown or virtual */
    SDL_Scancode scancode; /**< SDL physical key code */
    SDL_Keycode key; /**< SDL virtual key code */
    SDL_Keymod mod; /**< current key modifiers */
    Uint16 raw; /**< The platform dependent scancode for this event */
    bool down; /**< true if the key is pressed */
    bool repeat; /**< true if this is a key repeat */
}

/**
 * Keyboard text editing event structure (event.edit.*)
 *
 * The start cursor is the position, in UTF-8 characters, where new typing
 * will be inserted into the editing text. The length is the number of UTF-8
 * characters that will be replaced by new typing.
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_TextEditingEvent
{
    SDL_EventType type; /**< SDL_EVENT_TEXT_EDITING */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with keyboard focus, if any */
    const(char)* text; /**< The editing text */
    Sint32 start; /**< The start cursor of selected editing text, or -1 if not set */
    Sint32 length; /**< The length of selected editing text, or -1 if not set */
}

/**
 * Keyboard IME candidates event structure (event.edit_candidates.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_TextEditingCandidatesEvent
{
    SDL_EventType type; /**< SDL_EVENT_TEXT_EDITING_CANDIDATES */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with keyboard focus, if any */
    const(char*)* candidates; /**< The list of candidates, or NULL if there are no candidates available */
    Sint32 num_candidates; /**< The number of strings in `candidates` */
    Sint32 selected_candidate; /**< The index of the selected candidate, or -1 if no candidate is selected */
    bool horizontal; /**< true if the list is horizontal, false if it's vertical */
    Uint8 padding1;
    Uint8 padding2;
    Uint8 padding3;
}

/**
 * Keyboard text input event structure (event.text.*)
 *
 * This event will never be delivered unless text input is enabled by calling
 * SDL_StartTextInput(). Text input is disabled by default!
 *
 * \since This struct is available since SDL 3.2.0.
 *
 * \sa SDL_StartTextInput
 * \sa SDL_StopTextInput
 */
struct SDL_TextInputEvent
{
    SDL_EventType type; /**< SDL_EVENT_TEXT_INPUT */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with keyboard focus, if any */
    const(char)* text; /**< The input text, UTF-8 encoded */
}

/**
 * Mouse device event structure (event.mdevice.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_MouseDeviceEvent
{
    SDL_EventType type; /**< SDL_EVENT_MOUSE_ADDED or SDL_EVENT_MOUSE_REMOVED */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_MouseID which; /**< The mouse instance id */
}

/**
 * Mouse motion event structure (event.motion.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_MouseMotionEvent
{
    SDL_EventType type; /**< SDL_EVENT_MOUSE_MOTION */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with mouse focus, if any */
    SDL_MouseID which; /**< The mouse instance id in relative mode, SDL_TOUCH_MOUSEID for touch events, SDL_PEN_MOUSEID for pen events, or 0 */
    SDL_MouseButtonFlags state; /**< The current button state */
    float x; /**< X coordinate, relative to window */
    float y; /**< Y coordinate, relative to window */
    float xrel; /**< The relative motion in the X direction */
    float yrel; /**< The relative motion in the Y direction */
}

/**
 * Mouse button event structure (event.button.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_MouseButtonEvent
{
    SDL_EventType type; /**< SDL_EVENT_MOUSE_BUTTON_DOWN or SDL_EVENT_MOUSE_BUTTON_UP */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with mouse focus, if any */
    SDL_MouseID which; /**< The mouse instance id in relative mode, SDL_TOUCH_MOUSEID for touch events, or 0 */
    Uint8 button; /**< The mouse button index */
    bool down; /**< true if the button is pressed */
    Uint8 clicks; /**< 1 for single-click, 2 for double-click, etc. */
    Uint8 padding;
    float x; /**< X coordinate, relative to window */
    float y; /**< Y coordinate, relative to window */
}

/**
 * Mouse wheel event structure (event.wheel.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_MouseWheelEvent
{
    SDL_EventType type; /**< SDL_EVENT_MOUSE_WHEEL */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with mouse focus, if any */
    SDL_MouseID which; /**< The mouse instance id in relative mode or 0 */
    float x; /**< The amount scrolled horizontally, positive to the right and negative to the left */
    float y; /**< The amount scrolled vertically, positive away from the user and negative toward the user */
    SDL_MouseWheelDirection direction; /**< Set to one of the SDL_MOUSEWHEEL_* defines. When FLIPPED the values in X and Y will be opposite. Multiply by -1 to change them back */
    float mouse_x; /**< X coordinate, relative to window */
    float mouse_y; /**< Y coordinate, relative to window */
    Sint32 integer_x; /**< The amount scrolled horizontally, accumulated to whole scroll "ticks" (added in 3.2.12) */
    Sint32 integer_y; /**< The amount scrolled vertically, accumulated to whole scroll "ticks" (added in 3.2.12) */
}

/**
 * Joystick axis motion event structure (event.jaxis.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_JoyAxisEvent
{
    SDL_EventType type; /**< SDL_EVENT_JOYSTICK_AXIS_MOTION */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    Uint8 axis; /**< The joystick axis index */
    Uint8 padding1;
    Uint8 padding2;
    Uint8 padding3;
    Sint16 value; /**< The axis value (range: -32768 to 32767) */
    Uint16 padding4;
}

/**
 * Joystick trackball motion event structure (event.jball.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_JoyBallEvent
{
    SDL_EventType type; /**< SDL_EVENT_JOYSTICK_BALL_MOTION */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    Uint8 ball; /**< The joystick trackball index */
    Uint8 padding1;
    Uint8 padding2;
    Uint8 padding3;
    Sint16 xrel; /**< The relative motion in the X direction */
    Sint16 yrel; /**< The relative motion in the Y direction */
}

/**
 * Joystick hat position change event structure (event.jhat.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_JoyHatEvent
{
    SDL_EventType type; /**< SDL_EVENT_JOYSTICK_HAT_MOTION */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    Uint8 hat; /**< The joystick hat index */
    Uint8 value; /**< The hat position value.
     *   \sa SDL_HAT_LEFTUP SDL_HAT_UP SDL_HAT_RIGHTUP
     *   \sa SDL_HAT_LEFT SDL_HAT_CENTERED SDL_HAT_RIGHT
     *   \sa SDL_HAT_LEFTDOWN SDL_HAT_DOWN SDL_HAT_RIGHTDOWN
     *
     *   Note that zero means the POV is centered.
     */
    Uint8 padding1;
    Uint8 padding2;
}

/**
 * Joystick button event structure (event.jbutton.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_JoyButtonEvent
{
    SDL_EventType type; /**< SDL_EVENT_JOYSTICK_BUTTON_DOWN or SDL_EVENT_JOYSTICK_BUTTON_UP */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    Uint8 button; /**< The joystick button index */
    bool down; /**< true if the button is pressed */
    Uint8 padding1;
    Uint8 padding2;
}

/**
 * Joystick device event structure (event.jdevice.*)
 *
 * SDL will send JOYSTICK_ADDED events for devices that are already plugged in
 * during SDL_Init.
 *
 * \since This struct is available since SDL 3.2.0.
 *
 * \sa SDL_GamepadDeviceEvent
 */
struct SDL_JoyDeviceEvent
{
    SDL_EventType type; /**< SDL_EVENT_JOYSTICK_ADDED or SDL_EVENT_JOYSTICK_REMOVED or SDL_EVENT_JOYSTICK_UPDATE_COMPLETE */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
}

/**
 * Joystick battery level change event structure (event.jbattery.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_JoyBatteryEvent
{
    SDL_EventType type; /**< SDL_EVENT_JOYSTICK_BATTERY_UPDATED */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    SDL_PowerState state; /**< The joystick battery state */
    int percent; /**< The joystick battery percent charge remaining */
}

/**
 * Gamepad axis motion event structure (event.gaxis.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_GamepadAxisEvent
{
    SDL_EventType type; /**< SDL_EVENT_GAMEPAD_AXIS_MOTION */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    Uint8 axis; /**< The gamepad axis (SDL_GamepadAxis) */
    Uint8 padding1;
    Uint8 padding2;
    Uint8 padding3;
    Sint16 value; /**< The axis value (range: -32768 to 32767) */
    Uint16 padding4;
}

/**
 * Gamepad button event structure (event.gbutton.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_GamepadButtonEvent
{
    SDL_EventType type; /**< SDL_EVENT_GAMEPAD_BUTTON_DOWN or SDL_EVENT_GAMEPAD_BUTTON_UP */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    Uint8 button; /**< The gamepad button (SDL_GamepadButton) */
    bool down; /**< true if the button is pressed */
    Uint8 padding1;
    Uint8 padding2;
}

/**
 * Gamepad device event structure (event.gdevice.*)
 *
 * Joysticks that are supported gamepads receive both an SDL_JoyDeviceEvent
 * and an SDL_GamepadDeviceEvent.
 *
 * SDL will send GAMEPAD_ADDED events for joysticks that are already plugged
 * in during SDL_Init() and are recognized as gamepads. It will also send
 * events for joysticks that get gamepad mappings at runtime.
 *
 * \since This struct is available since SDL 3.2.0.
 *
 * \sa SDL_JoyDeviceEvent
 */
struct SDL_GamepadDeviceEvent
{
    SDL_EventType type; /**< SDL_EVENT_GAMEPAD_ADDED, SDL_EVENT_GAMEPAD_REMOVED, or SDL_EVENT_GAMEPAD_REMAPPED, SDL_EVENT_GAMEPAD_UPDATE_COMPLETE or SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
}

/**
 * Gamepad touchpad event structure (event.gtouchpad.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_GamepadTouchpadEvent
{
    SDL_EventType type; /**< SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN or SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION or SDL_EVENT_GAMEPAD_TOUCHPAD_UP */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    Sint32 touchpad; /**< The index of the touchpad */
    Sint32 finger; /**< The index of the finger on the touchpad */
    float x; /**< Normalized in the range 0...1 with 0 being on the left */
    float y; /**< Normalized in the range 0...1 with 0 being at the top */
    float pressure; /**< Normalized in the range 0...1 */
}

/**
 * Gamepad sensor event structure (event.gsensor.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_GamepadSensorEvent
{
    SDL_EventType type; /**< SDL_EVENT_GAMEPAD_SENSOR_UPDATE */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    Sint32 sensor; /**< The type of the sensor, one of the values of SDL_SensorType */
    float[3] data; /**< Up to 3 values from the sensor, as defined in SDL_sensor.h */
    Uint64 sensor_timestamp; /**< The timestamp of the sensor reading in nanoseconds, not necessarily synchronized with the system clock */
}

/**
 * Audio device event structure (event.adevice.*)
 *
 * Note that SDL will send a SDL_EVENT_AUDIO_DEVICE_ADDED event for every
 * device it discovers during initialization. After that, this event will only
 * arrive when a device is hotplugged during the program's run.
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_AudioDeviceEvent
{
    SDL_EventType type; /**< SDL_EVENT_AUDIO_DEVICE_ADDED, or SDL_EVENT_AUDIO_DEVICE_REMOVED, or SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_AudioDeviceID which; /**< SDL_AudioDeviceID for the device being added or removed or changing */
    bool recording; /**< false if a playback device, true if a recording device. */
    Uint8 padding1;
    Uint8 padding2;
    Uint8 padding3;
}

/**
 * Camera device event structure (event.cdevice.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_CameraDeviceEvent
{
    SDL_EventType type; /**< SDL_EVENT_CAMERA_DEVICE_ADDED, SDL_EVENT_CAMERA_DEVICE_REMOVED, SDL_EVENT_CAMERA_DEVICE_APPROVED, SDL_EVENT_CAMERA_DEVICE_DENIED */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_CameraID which; /**< SDL_CameraID for the device being added or removed or changing */
}

/**
 * Renderer event structure (event.render.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_RenderEvent
{
    SDL_EventType type; /**< SDL_EVENT_RENDER_TARGETS_RESET, SDL_EVENT_RENDER_DEVICE_RESET, SDL_EVENT_RENDER_DEVICE_LOST */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window containing the renderer in question. */
}

/**
 * Touch finger event structure (event.tfinger.*)
 *
 * Coordinates in this event are normalized. `x` and `y` are normalized to a
 * range between 0.0f and 1.0f, relative to the window, so (0,0) is the top
 * left and (1,1) is the bottom right. Delta coordinates `dx` and `dy` are
 * normalized in the ranges of -1.0f (traversed all the way from the bottom or
 * right to all the way up or left) to 1.0f (traversed all the way from the
 * top or left to all the way down or right).
 *
 * Note that while the coordinates are _normalized_, they are not _clamped_,
 * which means in some circumstances you can get a value outside of this
 * range. For example, a renderer using logical presentation might give a
 * negative value when the touch is in the letterboxing. Some platforms might
 * report a touch outside of the window, which will also be outside of the
 * range.
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_TouchFingerEvent
{
    SDL_EventType type; /**< SDL_EVENT_FINGER_DOWN, SDL_EVENT_FINGER_UP, SDL_EVENT_FINGER_MOTION, or SDL_EVENT_FINGER_CANCELED */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_TouchID touchID; /**< The touch device id */
    SDL_FingerID fingerID;
    float x; /**< Normalized in the range 0...1 */
    float y; /**< Normalized in the range 0...1 */
    float dx; /**< Normalized in the range -1...1 */
    float dy; /**< Normalized in the range -1...1 */
    float pressure; /**< Normalized in the range 0...1 */
    SDL_WindowID windowID; /**< The window underneath the finger, if any */
}

/**
 * Pinch event structure (event.pinch.*)
 */
struct SDL_PinchFingerEvent
{
    SDL_EventType type; /**< ::SDL_EVENT_PINCH_BEGIN or ::SDL_EVENT_PINCH_UPDATE or ::SDL_EVENT_PINCH_END */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    float scale; /**< The scale change since the last SDL_EVENT_PINCH_UPDATE. Scale < 1 is "zoom out". Scale > 1 is "zoom in". */
    SDL_WindowID windowID; /**< The window underneath the finger, if any */
}

/**
 * Pressure-sensitive pen proximity event structure (event.pproximity.*)
 *
 * When a pen becomes visible to the system (it is close enough to a tablet,
 * etc), SDL will send an SDL_EVENT_PEN_PROXIMITY_IN event with the new pen's
 * ID. This ID is valid until the pen leaves proximity again (has been removed
 * from the tablet's area, the tablet has been unplugged, etc). If the same
 * pen reenters proximity again, it will be given a new ID.
 *
 * Note that "proximity" means "close enough for the tablet to know the tool
 * is there." The pen touching and lifting off from the tablet while not
 * leaving the area are handled by SDL_EVENT_PEN_DOWN and SDL_EVENT_PEN_UP.
 *
 * Not all platforms have a window associated with the pen during proximity
 * events. Some wait until motion/button/etc events to offer this info.
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_PenProximityEvent
{
    SDL_EventType type; /**< SDL_EVENT_PEN_PROXIMITY_IN or SDL_EVENT_PEN_PROXIMITY_OUT */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with pen focus, if any */
    SDL_PenID which; /**< The pen instance id */
}

/**
 * Pressure-sensitive pen motion event structure (event.pmotion.*)
 *
 * Depending on the hardware, you may get motion events when the pen is not
 * touching a tablet, for tracking a pen even when it isn't drawing. You
 * should listen for SDL_EVENT_PEN_DOWN and SDL_EVENT_PEN_UP events, or check
 * `pen_state & SDL_PEN_INPUT_DOWN` to decide if a pen is "drawing" when
 * dealing with pen motion.
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_PenMotionEvent
{
    SDL_EventType type; /**< SDL_EVENT_PEN_MOTION */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with pen focus, if any */
    SDL_PenID which; /**< The pen instance id */
    SDL_PenInputFlags pen_state; /**< Complete pen input state at time of event */
    float x; /**< X coordinate, relative to window */
    float y; /**< Y coordinate, relative to window */
}

/**
 * Pressure-sensitive pen touched event structure (event.ptouch.*)
 *
 * These events come when a pen touches a surface (a tablet, etc), or lifts
 * off from one.
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_PenTouchEvent
{
    SDL_EventType type; /**< SDL_EVENT_PEN_DOWN or SDL_EVENT_PEN_UP */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with pen focus, if any */
    SDL_PenID which; /**< The pen instance id */
    SDL_PenInputFlags pen_state; /**< Complete pen input state at time of event */
    float x; /**< X coordinate, relative to window */
    float y; /**< Y coordinate, relative to window */
    bool eraser; /**< true if eraser end is used (not all pens support this). */
    bool down; /**< true if the pen is touching or false if the pen is lifted off */
}

/**
 * Pressure-sensitive pen button event structure (event.pbutton.*)
 *
 * This is for buttons on the pen itself that the user might click. The pen
 * itself pressing down to draw triggers a SDL_EVENT_PEN_DOWN event instead.
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_PenButtonEvent
{
    SDL_EventType type; /**< SDL_EVENT_PEN_BUTTON_DOWN or SDL_EVENT_PEN_BUTTON_UP */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with mouse focus, if any */
    SDL_PenID which; /**< The pen instance id */
    SDL_PenInputFlags pen_state; /**< Complete pen input state at time of event */
    float x; /**< X coordinate, relative to window */
    float y; /**< Y coordinate, relative to window */
    Uint8 button; /**< The pen button index (first button is 1). */
    bool down; /**< true if the button is pressed */
}

/**
 * Pressure-sensitive pen pressure / angle event structure (event.paxis.*)
 *
 * You might get some of these events even if the pen isn't touching the
 * tablet.
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_PenAxisEvent
{
    SDL_EventType type; /**< SDL_EVENT_PEN_AXIS */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window with pen focus, if any */
    SDL_PenID which; /**< The pen instance id */
    SDL_PenInputFlags pen_state; /**< Complete pen input state at time of event */
    float x; /**< X coordinate, relative to window */
    float y; /**< Y coordinate, relative to window */
    SDL_PenAxis axis; /**< Axis that has changed */
    float value; /**< New value of axis */
}

/**
 * An event used to drop text or request a file open by the system
 * (event.drop.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_DropEvent
{
    SDL_EventType type; /**< SDL_EVENT_DROP_BEGIN or SDL_EVENT_DROP_FILE or SDL_EVENT_DROP_TEXT or SDL_EVENT_DROP_COMPLETE or SDL_EVENT_DROP_POSITION */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The window that was dropped on, if any */
    float x; /**< X coordinate, relative to window (not on begin) */
    float y; /**< Y coordinate, relative to window (not on begin) */
    const(char)* source; /**< The source app that sent this drop event, or NULL if that isn't available */
    const(char)* data; /**< The text for SDL_EVENT_DROP_TEXT and the file name for SDL_EVENT_DROP_FILE, NULL for other events */
}

/**
 * An event triggered when the clipboard contents have changed
 * (event.clipboard.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_ClipboardEvent
{
    SDL_EventType type; /**< SDL_EVENT_CLIPBOARD_UPDATE */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    bool owner; /**< are we owning the clipboard (internal update) */
    Sint32 num_mime_types; /**< number of mime types */
    const(char*)* mime_types; /**< current mime types */
}

/**
 * Sensor event structure (event.sensor.*)
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_SensorEvent
{
    SDL_EventType type; /**< SDL_EVENT_SENSOR_UPDATE */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_SensorID which; /**< The instance ID of the sensor */
    float[6] data; /**< Up to 6 values from the sensor - additional values can be queried using SDL_GetSensorData() */
    Uint64 sensor_timestamp; /**< The timestamp of the sensor reading in nanoseconds, not necessarily synchronized with the system clock */
}

/**
 * The "quit requested" event
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_QuitEvent
{
    SDL_EventType type; /**< SDL_EVENT_QUIT */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
}

/**
 * A user-defined event type (event.user.*)
 *
 * This event is unique; it is never created by SDL, but only by the
 * application. The event can be pushed onto the event queue using
 * SDL_PushEvent(). The contents of the structure members are completely up to
 * the programmer; the only requirement is that '''type''' is a value obtained
 * from SDL_RegisterEvents().
 *
 * \since This struct is available since SDL 3.2.0.
 */
struct SDL_UserEvent
{
    Uint32 type; /**< SDL_EVENT_USER through SDL_EVENT_LAST, Uint32 because these are not in the SDL_EventType enumeration */
    Uint32 reserved;
    Uint64 timestamp; /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The associated window if any */
    Sint32 code; /**< User defined event code */
    void* data1; /**< User defined data pointer */
    void* data2; /**< User defined data pointer */
}

/**
 * The structure for all events in SDL.
 *
 * The SDL_Event structure is the core of all event handling in SDL. SDL_Event
 * is a union of all event structures used in SDL.
 *
 * \since This struct is available since SDL 3.2.0.
 */
union SDL_Event
{
    Uint32 type; /**< Event type, shared with all events, Uint32 to cover user events which are not in the SDL_EventType enumeration */
    SDL_CommonEvent common; /**< Common event data */
    SDL_DisplayEvent display; /**< Display event data */
    SDL_WindowEvent window; /**< Window event data */
    SDL_KeyboardDeviceEvent kdevice; /**< Keyboard device change event data */
    SDL_KeyboardEvent key; /**< Keyboard event data */
    SDL_TextEditingEvent edit; /**< Text editing event data */
    SDL_TextEditingCandidatesEvent edit_candidates; /**< Text editing candidates event data */
    SDL_TextInputEvent text; /**< Text input event data */
    SDL_MouseDeviceEvent mdevice; /**< Mouse device change event data */
    SDL_MouseMotionEvent motion; /**< Mouse motion event data */
    SDL_MouseButtonEvent button; /**< Mouse button event data */
    SDL_MouseWheelEvent wheel; /**< Mouse wheel event data */
    SDL_JoyDeviceEvent jdevice; /**< Joystick device change event data */
    SDL_JoyAxisEvent jaxis; /**< Joystick axis event data */
    SDL_JoyBallEvent jball; /**< Joystick ball event data */
    SDL_JoyHatEvent jhat; /**< Joystick hat event data */
    SDL_JoyButtonEvent jbutton; /**< Joystick button event data */
    SDL_JoyBatteryEvent jbattery; /**< Joystick battery event data */
    SDL_GamepadDeviceEvent gdevice; /**< Gamepad device event data */
    SDL_GamepadAxisEvent gaxis; /**< Gamepad axis event data */
    SDL_GamepadButtonEvent gbutton; /**< Gamepad button event data */
    SDL_GamepadTouchpadEvent gtouchpad; /**< Gamepad touchpad event data */
    SDL_GamepadSensorEvent gsensor; /**< Gamepad sensor event data */
    SDL_AudioDeviceEvent adevice; /**< Audio device event data */
    SDL_CameraDeviceEvent cdevice; /**< Camera device event data */
    SDL_SensorEvent sensor; /**< Sensor event data */
    SDL_QuitEvent quit; /**< Quit request event data */
    SDL_UserEvent user; /**< Custom event data */
    SDL_TouchFingerEvent tfinger; /**< Touch finger event data */
    SDL_PinchFingerEvent pinch; /**< Pinch event data */
    SDL_PenProximityEvent pproximity; /**< Pen proximity event data */
    SDL_PenTouchEvent ptouch; /**< Pen tip touching event data */
    SDL_PenMotionEvent pmotion; /**< Pen motion event data */
    SDL_PenButtonEvent pbutton; /**< Pen button event data */
    SDL_PenAxisEvent paxis; /**< Pen axis event data */
    SDL_RenderEvent render; /**< Render event data */
    SDL_DropEvent drop; /**< Drag and drop event data */
    SDL_ClipboardEvent clipboard; /**< Clipboard event data */

    /* This is necessary for ABI compatibility between Visual C++ and GCC.
       Visual C++ will respect the push pack pragma and use 52 bytes (size of
       SDL_TextEditingEvent, the largest structure for 32-bit and 64-bit
       architectures) for this union, and GCC will use the alignment of the
       largest datatype within the union, which is 8 bytes on 64-bit
       architectures.

       So... we'll add padding to force the size to be the same for both.

       On architectures where pointers are 16 bytes, this needs rounding up to
       the next multiple of 16, 64, and on architectures where pointers are
       even larger the size of SDL_UserEvent will dominate as being 3 pointers.
    */
    Uint8[128] padding;
}

/* Make sure we haven't broken binary compatibility */

/* Function prototypes */

/**
 * Pump the event loop, gathering events from the input devices.
 *
 * This function updates the event queue and internal input device state.
 *
 * SDL_PumpEvents() gathers all the pending input information from devices and
 * places it in the event queue. Without calls to SDL_PumpEvents() no events
 * would ever be placed on the queue. Often the need for calls to
 * SDL_PumpEvents() is hidden from the user since SDL_PollEvent() and
 * SDL_WaitEvent() implicitly call SDL_PumpEvents(). However, if you are not
 * polling or waiting for events (e.g. you are filtering them), then you must
 * call SDL_PumpEvents() to force an event queue update.
 *
 * \threadsafety This function should only be called on the main thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_PollEvent
 * \sa SDL_WaitEvent
 */
void SDL_PumpEvents ();

/* @{ */

/**
 * The type of action to request from SDL_PeepEvents().
 *
 * \since This enum is available since SDL 3.2.0.
 */
enum SDL_EventAction
{
    SDL_ADDEVENT = 0, /**< Add events to the back of the queue. */
    SDL_PEEKEVENT = 1, /**< Check but don't remove events from the queue front. */
    SDL_GETEVENT = 2 /**< Retrieve/remove events from the front of the queue. */
}

/**
 * Check the event queue for messages and optionally return them.
 *
 * `action` may be any of the following:
 *
 * - `SDL_ADDEVENT`: up to `numevents` events will be added to the back of the
 *   event queue.
 * - `SDL_PEEKEVENT`: `numevents` events at the front of the event queue,
 *   within the specified minimum and maximum type, will be returned to the
 *   caller and will _not_ be removed from the queue. If you pass NULL for
 *   `events`, then `numevents` is ignored and the total number of matching
 *   events will be returned.
 * - `SDL_GETEVENT`: up to `numevents` events at the front of the event queue,
 *   within the specified minimum and maximum type, will be returned to the
 *   caller and will be removed from the queue.
 *
 * You may have to call SDL_PumpEvents() before calling this function.
 * Otherwise, the events may not be ready to be filtered when you call
 * SDL_PeepEvents().
 *
 * \param events destination buffer for the retrieved events, may be NULL to
 *               leave the events in the queue and return the number of events
 *               that would have been stored.
 * \param numevents if action is SDL_ADDEVENT, the number of events to add
 *                  back to the event queue; if action is SDL_PEEKEVENT or
 *                  SDL_GETEVENT, the maximum number of events to retrieve.
 * \param action action to take; see [Remarks](#remarks) for details.
 * \param minType minimum value of the event type to be considered;
 *                SDL_EVENT_FIRST is a safe choice.
 * \param maxType maximum value of the event type to be considered;
 *                SDL_EVENT_LAST is a safe choice.
 * \returns the number of events actually stored or -1 on failure; call
 *          SDL_GetError() for more information.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_PollEvent
 * \sa SDL_PumpEvents
 * \sa SDL_PushEvent
 */
int SDL_PeepEvents (SDL_Event* events, int numevents, SDL_EventAction action, Uint32 minType, Uint32 maxType);
/* @} */

/**
 * Check for the existence of a certain event type in the event queue.
 *
 * If you need to check for a range of event types, use SDL_HasEvents()
 * instead.
 *
 * \param type the type of event to be queried; see SDL_EventType for details.
 * \returns true if events matching `type` are present, or false if events
 *          matching `type` are not present.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_HasEvents
 */
bool SDL_HasEvent (Uint32 type);

/**
 * Check for the existence of certain event types in the event queue.
 *
 * If you need to check for a single event type, use SDL_HasEvent() instead.
 *
 * \param minType the low end of event type to be queried, inclusive; see
 *                SDL_EventType for details.
 * \param maxType the high end of event type to be queried, inclusive; see
 *                SDL_EventType for details.
 * \returns true if events with type >= `minType` and <= `maxType` are
 *          present, or false if not.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_HasEvents
 */
bool SDL_HasEvents (Uint32 minType, Uint32 maxType);

/**
 * Clear events of a specific type from the event queue.
 *
 * This will unconditionally remove any events from the queue that match
 * `type`. If you need to remove a range of event types, use SDL_FlushEvents()
 * instead.
 *
 * It's also normal to just ignore events you don't care about in your event
 * loop without calling this function.
 *
 * This function only affects currently queued events. If you want to make
 * sure that all pending OS events are flushed, you can call SDL_PumpEvents()
 * on the main thread immediately before the flush call.
 *
 * If you have user events with custom data that needs to be freed, you should
 * use SDL_PeepEvents() to remove and clean up those events before calling
 * this function.
 *
 * \param type the type of event to be cleared; see SDL_EventType for details.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_FlushEvents
 */
void SDL_FlushEvent (Uint32 type);

/**
 * Clear events of a range of types from the event queue.
 *
 * This will unconditionally remove any events from the queue that are in the
 * range of `minType` to `maxType`, inclusive. If you need to remove a single
 * event type, use SDL_FlushEvent() instead.
 *
 * It's also normal to just ignore events you don't care about in your event
 * loop without calling this function.
 *
 * This function only affects currently queued events. If you want to make
 * sure that all pending OS events are flushed, you can call SDL_PumpEvents()
 * on the main thread immediately before the flush call.
 *
 * \param minType the low end of event type to be cleared, inclusive; see
 *                SDL_EventType for details.
 * \param maxType the high end of event type to be cleared, inclusive; see
 *                SDL_EventType for details.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_FlushEvent
 */
void SDL_FlushEvents (Uint32 minType, Uint32 maxType);

/**
 * Poll for currently pending events.
 *
 * If `event` is not NULL, the next event is removed from the queue and stored
 * in the SDL_Event structure pointed to by `event`.
 *
 * If `event` is NULL, it simply returns true if there is an event in the
 * queue, but will not remove it from the queue.
 *
 * As this function may implicitly call SDL_PumpEvents(), you can only call
 * this function in the thread that initialized the video subsystem.
 *
 * SDL_PollEvent() is the favored way of receiving system events since it can
 * be done from the main loop and does not suspend the main loop while waiting
 * on an event to be posted.
 *
 * The common practice is to fully process the event queue once every frame,
 * usually as a first step before updating the game's state:
 *
 * ```c
 * while (game_is_still_running) {
 *     SDL_Event event;
 *     while (SDL_PollEvent(&event)) {  // poll until all events are handled!
 *         // decide what to do with this event.
 *     }
 *
 *     // update game state, draw the current frame
 * }
 * ```
 *
 * Note that Windows (and possibly other platforms) has a quirk about how it
 * handles events while dragging/resizing a window, which can cause this
 * function to block for significant amounts of time. Technical explanations
 * and solutions are discussed on the wiki:
 *
 * https://wiki.libsdl.org/SDL3/AppFreezeDuringDrag
 *
 * \param event the SDL_Event structure to be filled with the next event from
 *              the queue, or NULL.
 * \returns true if this got an event or false if there are none available.
 *
 * \threadsafety This function should only be called on the main thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_PushEvent
 * \sa SDL_WaitEvent
 * \sa SDL_WaitEventTimeout
 */
bool SDL_PollEvent (SDL_Event* event);

/**
 * Wait indefinitely for the next available event.
 *
 * If `event` is not NULL, the next event is removed from the queue and stored
 * in the SDL_Event structure pointed to by `event`.
 *
 * As this function may implicitly call SDL_PumpEvents(), you can only call
 * this function in the thread that initialized the video subsystem.
 *
 * \param event the SDL_Event structure to be filled in with the next event
 *              from the queue, or NULL.
 * \returns true on success or false if there was an error while waiting for
 *          events; call SDL_GetError() for more information.
 *
 * \threadsafety This function should only be called on the main thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_PollEvent
 * \sa SDL_PushEvent
 * \sa SDL_WaitEventTimeout
 */
bool SDL_WaitEvent (SDL_Event* event);

/**
 * Wait until the specified timeout (in milliseconds) for the next available
 * event.
 *
 * If `event` is not NULL, the next event is removed from the queue and stored
 * in the SDL_Event structure pointed to by `event`.
 *
 * As this function may implicitly call SDL_PumpEvents(), you can only call
 * this function in the thread that initialized the video subsystem.
 *
 * The timeout is not guaranteed, the actual wait time could be longer due to
 * system scheduling.
 *
 * \param event the SDL_Event structure to be filled in with the next event
 *              from the queue, or NULL.
 * \param timeoutMS the maximum number of milliseconds to wait for the next
 *                  available event.
 * \returns true if this got an event or false if the timeout elapsed without
 *          any events available.
 *
 * \threadsafety This function should only be called on the main thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_PollEvent
 * \sa SDL_PushEvent
 * \sa SDL_WaitEvent
 */
bool SDL_WaitEventTimeout (SDL_Event* event, Sint32 timeoutMS);

/**
 * Add an event to the event queue.
 *
 * The event queue can actually be used as a two way communication channel.
 * Not only can events be read from the queue, but the user can also push
 * their own events onto it. `event` is a pointer to the event structure you
 * wish to push onto the queue. The event is copied into the queue, and the
 * caller may dispose of the memory pointed to after SDL_PushEvent() returns.
 *
 * Note: Pushing device input events onto the queue doesn't modify the state
 * of the device within SDL.
 *
 * Note: Events pushed onto the queue with SDL_PushEvent() get passed through
 * the event filter but events added with SDL_PeepEvents() do not.
 *
 * For pushing application-specific events, please use SDL_RegisterEvents() to
 * get an event type that does not conflict with other code that also wants
 * its own custom event types.
 *
 * \param event the SDL_Event to be added to the queue.
 * \returns true on success, false if the event was filtered or on failure;
 *          call SDL_GetError() for more information. A common reason for
 *          error is the event queue being full.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_PeepEvents
 * \sa SDL_PollEvent
 * \sa SDL_RegisterEvents
 */
bool SDL_PushEvent (SDL_Event* event);

/**
 * A function pointer used for callbacks that watch the event queue.
 *
 * \param userdata what was passed as `userdata` to SDL_SetEventFilter() or
 *                 SDL_AddEventWatch, etc.
 * \param event the event that triggered the callback.
 * \returns true to permit event to be added to the queue, and false to
 *          disallow it. When used with SDL_AddEventWatch, the return value is
 *          ignored.
 *
 * \threadsafety SDL may call this callback at any time from any thread; the
 *               application is responsible for locking resources the callback
 *               touches that need to be protected.
 *
 * \since This datatype is available since SDL 3.2.0.
 *
 * \sa SDL_SetEventFilter
 * \sa SDL_AddEventWatch
 */
alias SDL_EventFilter = bool function (void* userdata, SDL_Event* event);

/**
 * Set up a filter to process all events before they are added to the internal
 * event queue.
 *
 * If you just want to see events without modifying them or preventing them
 * from being queued, you should use SDL_AddEventWatch() instead.
 *
 * If the filter function returns true when called, then the event will be
 * added to the internal queue. If it returns false, then the event will be
 * dropped from the queue, but the internal state will still be updated. This
 * allows selective filtering of dynamically arriving events.
 *
 * **WARNING**: Be very careful of what you do in the event filter function,
 * as it may run in a different thread! The exception is handling of
 * SDL_EVENT_WINDOW_EXPOSED, which is guaranteed to be sent from the OS on the
 * main thread and you are expected to redraw your window in response to this
 * event.
 *
 * On platforms that support it, if the quit event is generated by an
 * interrupt signal (e.g. pressing Ctrl-C), it will be delivered to the
 * application at the next event poll.
 *
 * Note: Disabled events never make it to the event filter function; see
 * SDL_SetEventEnabled().
 *
 * Note: Events pushed onto the queue with SDL_PushEvent() get passed through
 * the event filter, but events pushed onto the queue with SDL_PeepEvents() do
 * not.
 *
 * \param filter a function to call when an event happens.
 * \param userdata a pointer that is passed to `filter`.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_AddEventWatch
 * \sa SDL_SetEventEnabled
 * \sa SDL_GetEventFilter
 * \sa SDL_PeepEvents
 * \sa SDL_PushEvent
 */
void SDL_SetEventFilter (SDL_EventFilter filter, void* userdata);

/**
 * Query the current event filter.
 *
 * This function can be used to "chain" filters, by saving the existing filter
 * before replacing it with a function that will call that saved filter.
 *
 * \param filter the current callback function will be stored here.
 * \param userdata the pointer that is passed to the current event filter will
 *                 be stored here.
 * \returns true on success or false if there is no event filter set.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_SetEventFilter
 */
bool SDL_GetEventFilter (SDL_EventFilter* filter, void** userdata);

/**
 * Add a callback to be triggered when an event is added to the event queue.
 *
 * `filter` will be called when an event happens, and its return value is
 * ignored.
 *
 * **WARNING**: Be very careful of what you do in the event filter function,
 * as it may run in a different thread!
 *
 * If the quit event is generated by a signal (e.g. SIGINT), it will bypass
 * the internal queue and be delivered to the watch callback immediately, and
 * arrive at the next event poll.
 *
 * Note: the callback is called for events posted by the user through
 * SDL_PushEvent(), but not for disabled events, nor for events by a filter
 * callback set with SDL_SetEventFilter(), nor for events posted by the user
 * through SDL_PeepEvents().
 *
 * \param filter an SDL_EventFilter function to call when an event happens.
 * \param userdata a pointer that is passed to `filter`.
 * \returns true on success or false on failure; call SDL_GetError() for more
 *          information.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_RemoveEventWatch
 * \sa SDL_SetEventFilter
 */
bool SDL_AddEventWatch (SDL_EventFilter filter, void* userdata);

/**
 * Remove an event watch callback added with SDL_AddEventWatch().
 *
 * This function takes the same input as SDL_AddEventWatch() to identify and
 * delete the corresponding callback.
 *
 * \param filter the function originally passed to SDL_AddEventWatch().
 * \param userdata the pointer originally passed to SDL_AddEventWatch().
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_AddEventWatch
 */
void SDL_RemoveEventWatch (SDL_EventFilter filter, void* userdata);

/**
 * Run a specific filter function on the current event queue, removing any
 * events for which the filter returns false.
 *
 * See SDL_SetEventFilter() for more information. Unlike SDL_SetEventFilter(),
 * this function does not change the filter permanently, it only uses the
 * supplied filter until this function returns.
 *
 * \param filter the SDL_EventFilter function to call when an event happens.
 * \param userdata a pointer that is passed to `filter`.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_GetEventFilter
 * \sa SDL_SetEventFilter
 */
void SDL_FilterEvents (SDL_EventFilter filter, void* userdata);

/**
 * Set the state of processing events by type.
 *
 * \param type the type of event; see SDL_EventType for details.
 * \param enabled whether to process the event or not.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_EventEnabled
 */
void SDL_SetEventEnabled (Uint32 type, bool enabled);

/**
 * Query the state of processing events by type.
 *
 * \param type the type of event; see SDL_EventType for details.
 * \returns true if the event is being processed, false otherwise.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_SetEventEnabled
 */
bool SDL_EventEnabled (Uint32 type);

/**
 * Allocate a set of user-defined events, and return the beginning event
 * number for that set of events.
 *
 * \param numevents the number of events to be allocated.
 * \returns the beginning event number, or 0 if numevents is invalid or if
 *          there are not enough user-defined events left.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_PushEvent
 */
Uint32 SDL_RegisterEvents (int numevents);

/**
 * Get window associated with an event.
 *
 * \param event an event containing a `windowID`.
 * \returns the associated window on success or NULL if there is none.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.2.0.
 *
 * \sa SDL_PollEvent
 * \sa SDL_WaitEvent
 * \sa SDL_WaitEventTimeout
 */
SDL_Window* SDL_GetWindowFromEvent (const(SDL_Event)* event);

/**
 * Generate an English description of an event.
 *
 * This will fill `buf` with a null-terminated string that might look
 * something like this:
 *
 * ```
 * SDL_EVENT_MOUSE_MOTION (timestamp=1140256324 windowid=2 which=0 state=0 x=492.99 y=139.09 xrel=52 yrel=6)
 * ```
 *
 * The exact format of the string is not guaranteed; it is intended for
 * logging purposes, to be read by a human, and not parsed by a computer.
 *
 * The returned value follows the same rules as SDL_snprintf(): `buf` will
 * always be NULL-terminated (unless `buflen` is zero), and will be truncated
 * if `buflen` is too small. The return code is the number of bytes needed for
 * the complete string, not counting the NULL-terminator, whether the string
 * was truncated or not. Unlike SDL_snprintf(), though, this function never
 * returns -1.
 *
 * \param event an event to describe. May be NULL.
 * \param buf the buffer to fill with the description string. May be NULL.
 * \param buflen the maximum bytes that can be written to `buf`.
 * \returns number of bytes needed for the full string, not counting the
 *          null-terminator byte.
 *
 * \threadsafety It is safe to call this function from any thread.
 *
 * \since This function is available since SDL 3.4.0.
 */
int SDL_GetEventDescription (const(SDL_Event)* event, char* buf, int buflen);

/* Ends C function definitions when using C++ */

/* SDL_events_h_ */
