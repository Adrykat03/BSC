using BSC.Application.Interfaces;
using Microsoft.Extensions.Logging;

namespace BSC.Infrastructure.Services;

/// <summary>
/// Implementacion HTTP del cliente de Utilerias Payroll.
/// Token y base URL vienen inyectados por DI (ver DependencyInjection.cs).
/// </summary>
public class UtileriasPayrollClient : IUtileriasPayrollClient
{
    private readonly HttpClient _httpClient;
    private readonly string _token;
    private readonly ILogger<UtileriasPayrollClient> _logger;

    public UtileriasPayrollClient(HttpClient httpClient, UtileriasPayrollOptions options, ILogger<UtileriasPayrollClient> logger)
    {
        _httpClient = httpClient;
        _token = options.Token;
        _logger = logger;
    }

    public async Task<AdjuntoDescargado> DescargarAsync(string ruta, string nombreArchivo, CancellationToken cancellationToken)
    {
        // El API externo: GET /VerArchivosPdf?nombreArchivo=...&token=...&tipo=D
        // BaseAddress ya termina en /api/Documentos/, asi que solo concatenamos.
        var url = $"VerArchivosPdf?nombreArchivo={Uri.EscapeDataString(ruta)}&token={Uri.EscapeDataString(_token)}&tipo=D";

        var response = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            _logger.LogWarning("Descarga de adjunto fallo. Status={Status} Ruta={Ruta} Body={Body}",
                response.StatusCode, ruta, Truncate(body, 500));
            throw new HttpRequestException(
                $"Utilerias Payroll respondio {(int)response.StatusCode}: {response.ReasonPhrase}");
        }

        var contentType = response.Content.Headers.ContentType?.MediaType ?? "application/octet-stream";
        var contentLength = response.Content.Headers.ContentLength;
        var stream = await response.Content.ReadAsStreamAsync(cancellationToken);

        return new AdjuntoDescargado
        {
            Contenido = stream,
            ContentType = contentType,
            NombreArchivo = string.IsNullOrWhiteSpace(nombreArchivo) ? Path.GetFileName(ruta) : nombreArchivo,
            TamanioBytes = contentLength,
        };
    }

    private static string Truncate(string s, int max) =>
        string.IsNullOrEmpty(s) ? string.Empty : (s.Length <= max ? s : s[..max] + "...");
}
