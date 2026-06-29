using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using BSC.Application.Interfaces;
using Microsoft.Extensions.Logging;

namespace BSC.Infrastructure.Services;

/// <summary>
/// Implementacion HTTP del cliente de Data API Builder para Avisos.notificacionesConsolidadas.
/// DAB expone REST con la convencion: {BaseUrl}/api/NotificacionesConsolidadas/idNotificacion/{id}.
/// </summary>
public class DabAlertasClient : IDabAlertasClient
{
    private const string EntityPath = "api/NotificacionesConsolidadas";

    private readonly HttpClient _httpClient;
    private readonly ILogger<DabAlertasClient> _logger;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public DabAlertasClient(HttpClient httpClient, ILogger<DabAlertasClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<NotificacionConsolidadaSnapshot?> GetByIdAsync(long idNotificacion, CancellationToken cancellationToken = default)
    {
        var url = $"{EntityPath}/idNotificacion/{idNotificacion}";
        using var response = await _httpClient.GetAsync(url, cancellationToken);

        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            _logger.LogWarning("DAB GET fallo. Status={Status} Id={Id} Body={Body}",
                response.StatusCode, idNotificacion, Truncate(body, 500));
            throw new HttpRequestException(
                $"DAB respondio {(int)response.StatusCode} al leer notificacion {idNotificacion}.");
        }

        // DAB retorna { "value": [ { ...row... } ] }
        using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        var envelope = await JsonSerializer.DeserializeAsync<DabEnvelope>(stream, JsonOptions, cancellationToken);
        var row = envelope?.Value?.FirstOrDefault();
        if (row == null) return null;

        return new NotificacionConsolidadaSnapshot
        {
            IdNotificacion = row.IdNotificacion,
            Estado = row.Estado ?? string.Empty,
            NotasResolucion = row.NotasResolucion,
            UsuarioResolucion = row.UsuarioResolucion,
            FechaResolucion = row.FechaResolucion,
        };
    }

    public async Task ActualizarAsync(long idNotificacion, ActualizarNotificacionRequest request, CancellationToken cancellationToken = default)
    {
        var url = $"{EntityPath}/idNotificacion/{idNotificacion}";

        // DAB acepta PATCH para actualizaciones parciales sobre la primary key.
        // El body NO debe incluir idNotificacion (DAB lo rechaza con 400 porque la PK va en la URL).
        var payload = new DabUpdatePayload
        {
            Estado = request.Estado,
            NotasResolucion = request.NotasResolucion,
            UsuarioResolucion = request.UsuarioResolucion,
            FechaResolucion = request.FechaResolucion,
            FechaModificacion = request.FechaModificacion,
        };

        using var httpRequest = new HttpRequestMessage(HttpMethod.Patch, url)
        {
            Content = JsonContent.Create(payload, options: JsonOptions),
        };

        using var response = await _httpClient.SendAsync(httpRequest, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            _logger.LogWarning("DAB PATCH fallo. Status={Status} Id={Id} Body={Body}",
                response.StatusCode, idNotificacion, Truncate(body, 500));
            throw new HttpRequestException(
                $"DAB respondio {(int)response.StatusCode} al actualizar notificacion {idNotificacion}.");
        }
    }

    public async Task<IReadOnlyList<JsonObject>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        const int maxPages = 100;
        var rows = new List<JsonObject>();

        // Primera pagina. DAB acepta $orderby + $first; las siguientes vienen por nextLink.
        string? nextUrl = $"{EntityPath}?$orderby=fechaCreacion desc&$first=100";

        for (var page = 0; page < maxPages && !string.IsNullOrEmpty(nextUrl); page++)
        {
            using var response = await _httpClient.GetAsync(nextUrl, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogWarning("DAB GET (lista) fallo. Status={Status} Url={Url} Body={Body}",
                    response.StatusCode, nextUrl, Truncate(body, 500));
                throw new HttpRequestException(
                    $"DAB respondio {(int)response.StatusCode} al listar notificaciones.");
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            var envelope = await JsonNode.ParseAsync(stream, cancellationToken: cancellationToken);

            if (envelope is JsonObject envObj)
            {
                if (envObj["value"] is JsonArray valueArray)
                {
                    foreach (var item in valueArray)
                    {
                        // Clonamos para desacoplar del documento padre (que se descarta al iterar).
                        if (item is JsonObject rowObj)
                        {
                            rows.Add((JsonObject)rowObj.DeepClone());
                        }
                    }
                }

                // DAB pagina con nextLink o @odata.nextLink. Puede venir absoluto o relativo.
                nextUrl = NormalizeNextLink(
                    envObj["nextLink"]?.GetValue<string>()
                    ?? envObj["@odata.nextLink"]?.GetValue<string>());
            }
            else
            {
                nextUrl = null;
            }
        }

        return rows;
    }

    /// <summary>
    /// Normaliza el nextLink de DAB a una ruta utilizable por el HttpClient (cuya BaseAddress
    /// es la interna http://bsc_dab:5000/). Si DAB devuelve un host distinto (p. ej. localhost
    /// porque ve el X-Forwarded-Host), reescribimos a path+query relativo al EntityPath.
    /// </summary>
    private static string? NormalizeNextLink(string? rawNextLink)
    {
        if (string.IsNullOrWhiteSpace(rawNextLink)) return null;

        if (Uri.TryCreate(rawNextLink, UriKind.Absolute, out var abs))
        {
            // Devolvemos path + query sin el leading '/' para que concatene con BaseAddress.
            return (abs.AbsolutePath.TrimStart('/') + abs.Query);
        }

        // Relativo: quitamos el leading '/' si lo trae.
        return rawNextLink.TrimStart('/');
    }

    private static string Truncate(string s, int max) =>
        string.IsNullOrEmpty(s) ? string.Empty : (s.Length <= max ? s : s[..max] + "...");

    // Modelos internos para (de)serializar la respuesta de DAB.
    private class DabEnvelope
    {
        [JsonPropertyName("value")]
        public List<DabRow>? Value { get; set; }
    }

    private class DabRow
    {
        [JsonPropertyName("idNotificacion")]
        public long IdNotificacion { get; set; }

        [JsonPropertyName("estado")]
        public string? Estado { get; set; }

        [JsonPropertyName("notasResolucion")]
        public string? NotasResolucion { get; set; }

        [JsonPropertyName("usuarioResolucion")]
        public string? UsuarioResolucion { get; set; }

        [JsonPropertyName("fechaResolucion")]
        public DateTime? FechaResolucion { get; set; }
    }

    // Payload para PATCH: NO incluye la primary key (idNotificacion) porque DAB
    // la requiere solo en la URL y rechaza el body si la trae duplicada.
    private class DabUpdatePayload
    {
        [JsonPropertyName("estado")]
        public string? Estado { get; set; }

        [JsonPropertyName("notasResolucion")]
        public string? NotasResolucion { get; set; }

        [JsonPropertyName("usuarioResolucion")]
        public string? UsuarioResolucion { get; set; }

        [JsonPropertyName("fechaResolucion")]
        public DateTime? FechaResolucion { get; set; }

        [JsonPropertyName("fechaModificacion")]
        public DateTime FechaModificacion { get; set; }
    }
}
