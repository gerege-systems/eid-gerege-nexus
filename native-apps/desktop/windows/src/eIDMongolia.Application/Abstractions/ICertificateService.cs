using eIDMongolia.Domain.Certificates;
using eIDMongolia.Domain.Primitives;

namespace eIDMongolia.Application.Abstractions;

public interface ICertificateService
{
    Result<CertificateInfo> ParsePem(string pemContents);

    Result<CertificateInfo> ParseFile(string filePath);
}
