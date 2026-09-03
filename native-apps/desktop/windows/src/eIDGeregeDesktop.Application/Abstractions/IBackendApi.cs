using eIDGeregeDesktop.Domain.Primitives;

namespace eIDGeregeDesktop.Application.Abstractions;

public interface IBackendApi
{
    Task<Result<HealthStatus>> GetHealthAsync(CancellationToken ct = default);
}

public sealed record HealthStatus(bool Live, bool Ready, string? Version);
