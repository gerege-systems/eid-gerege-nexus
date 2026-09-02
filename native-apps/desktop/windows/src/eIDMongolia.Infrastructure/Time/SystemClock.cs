using eIDMongolia.Application.Abstractions;

namespace eIDMongolia.Infrastructure.Time;

public sealed class SystemClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
