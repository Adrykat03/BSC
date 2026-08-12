using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using BSC.Application.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace BSC.Infrastructure.Services;

/// <summary>
/// Implementacion HTTP del cliente de Data API Builder para Avisos.notificacionesConsolidadas.
/// DAB expone REST con la convencion: {BaseUrl}/api/NotificacionesConsolidadas/idNotificacion/{id}.
/// </summary>
public class DabAlertasClient : IDabAlertasClient
{
    private const string EntityPath = "api/NotificacionesConsolidadas";

    // Cache corto del listado completo (GetAllAsync): todos los usuarios
    // conectados (carga inicial, boton Actualizar, auto-refresh periodico)
    // comparten el mismo resultado durante esta ventana en vez de volver a
    // pedirle a DAB cada uno por su lado. Se invalida al toque cuando alguien
    // cambia el estado de una alerta (ver InvalidarCache), asi que el margen
    // de "dato viejo" real es mucho menor a los 15s en el caso que importa
    // (que alguien vea reflejado SU PROPIO cambio).
    private const string CacheKeyTodas = "dab:notificaciones:todas";
    private static readonly TimeSpan CacheTtl = TimeSpan.FromSeconds(15);

    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;
    private readonly ILogger<DabAlertasClient> _logger;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public DabAlertasClient(HttpClient httpClient, IMemoryCache cache, ILogger<DabAlertasClient> logger)
    {
        _httpClient = httpClient;
        _cache = cache;
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

        // Invalidar el cache del listado: sin esto, quien acaba de cambiar el
        // estado (o cualquier otro usuario que refresque) seguiria viendo el
        // dato viejo hasta que expire la ventana de CacheTtl.
        _cache.Remove(CacheKeyTodas);
    }

    public async Task<IReadOnlyList<JsonObject>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        if (_cache.TryGetValue(CacheKeyTodas, out IReadOnlyList<JsonObject>? cached) && cached != null)
        {
            return cached;
        }

        var rows = await FetchAllFromDabAsync(cancellationToken);

        // Tamaño (no memoria real, MemoryCache no lo mide por si solo) para que
        // conviva con SetSize/SizeLimit si en el futuro se configura uno.
        _cache.Set(CacheKeyTodas, (IReadOnlyList<JsonObject>)rows, new MemoryCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = CacheTtl,
            Size = 1,
        });

        return rows;
    }

    private async Task<List<JsonObject>> FetchAllFromDabAsync(CancellationToken cancellationToken)
    {
        const int maxPages = 100;
        var rows = new List<JsonObject>();

        // Primera pagina. DAB acepta $orderby + $first; las siguientes vienen por
        // nextLink. $first grande (antes 100) para traer todo en 1-2 llamadas en
        // vez de ~70 secuenciales: verificado que DAB soporta paginas de miles de
        // filas sin problema (10000 filas / ~13MB en ~3.6s en un solo request).
        string? nextUrl = $"{EntityPath}?$orderby=fechaCreacion desc&$first=10000";

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
