using eIDGeregeDesktop.Domain.Certificates;
using eIDGeregeDesktop.Domain.Primitives;

namespace eIDGeregeDesktop.Application.Abstractions;

public interface ICertificateService
{
    Result<CertificateInfo> ParsePem(string pemContents);

    Result<CertificateInfo> ParseFile(string filePath);
}
