module sdlffcd.sdl_logger;

import std.logger.core : Logger, LogLevel;
import sdlffcd.sdlffcd_clib : sdlffcd_log_message, sdlffcd_LogPriority;

/// Custom Logger that forwards D log messages to SDL3's log subsystem
/// via sdlffcd_clib wrapper.
class SdlLogger : Logger
{
    private int category_;

    /// Construct with a D LogLevel and an SDL log category
    /// (0 = SDL_LOG_CATEGORY_APPLICATION by default).
    this(LogLevel lv, int sdlCategory = 0) @safe
    {
        super(lv);
        this.category_ = sdlCategory;
    }

    override protected void writeLogMsg(ref LogEntry payload) @safe
    {
        import std.string : toStringz;

        auto priority = mapLogLevel(payload.logLevel);
        auto msgz = payload.msg.toStringz;

        () @trusted {
            sdlffcd_log_message(category_, priority, msgz);
        }();
    }

    /// Map D LogLevel to SDL log priority.
    public static sdlffcd_LogPriority mapLogLevel(LogLevel level) @safe pure nothrow @nogc
    {
        switch (level)
        {
        case LogLevel.all:
        case LogLevel.trace:
            return sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_DEBUG;
        case LogLevel.info:
            return sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_INFO;
        case LogLevel.warning:
            return sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_WARN;
        case LogLevel.error:
            return sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_ERROR;
        case LogLevel.critical:
        case LogLevel.fatal:
            return sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_CRITICAL;
        default:
            return sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_INFO;
        }
    }
}

unittest
{
    // Verify level mappings
    assert(SdlLogger.mapLogLevel(LogLevel.all) == sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_DEBUG);
    assert(SdlLogger.mapLogLevel(LogLevel.trace) == sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_DEBUG);
    assert(SdlLogger.mapLogLevel(LogLevel.info) == sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_INFO);
    assert(SdlLogger.mapLogLevel(LogLevel.warning) == sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_WARN);
    assert(SdlLogger.mapLogLevel(LogLevel.error) == sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_ERROR);
    assert(SdlLogger.mapLogLevel(LogLevel.critical) == sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_CRITICAL);
    assert(SdlLogger.mapLogLevel(LogLevel.fatal) == sdlffcd_LogPriority.SDLFFCD_LOG_PRIORITY_CRITICAL);

    // Verify instantiation and logging
    auto logger = new SdlLogger(LogLevel.info);
    assert(logger !is null);
    logger.log(LogLevel.info, "Test message from SdlLogger unittest");
    logger.log(LogLevel.warning, "Test warning from SdlLogger unittest");
}
