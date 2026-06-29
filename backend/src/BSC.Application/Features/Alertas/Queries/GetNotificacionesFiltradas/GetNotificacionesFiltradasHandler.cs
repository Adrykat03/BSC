using System.Text.Json.Nodes;
using BSC.Application.DTOs;
using BSC.Application.Interfaces;
using BSC.Domain.Constants;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Alertas.Queries.GetNotificacionesFiltradas;

public class GetNotificacionesFiltradasHandler
    : IRequestHandler<GetNotificacionesFiltradasQuery, ApiResponse<IReadOnlyList<JsonObject>>>
{
    private static readonly char[] DestinatariosSeparators = { '|', ';', ',' };

    private readonly IDabAlertasClient _dabClient;
    private readonly ILogger<GetNotificacionesFiltradasHandler> _logger;

    public GetNotificacionesFiltradasHandler(
        IDabAlertasClient dabClient,
        ILogger<GetNotificacionesFiltradasHandler> logger)
    {
        _dabClient = dabClient;
        _logger = logger;
    }

    public async Task<ApiResponse<IReadOnlyList<JsonObject>>> Handle(
        GetNotificacionesFiltradasQuery request, CancellationToken cancellationToken)
    {
        var esPrivilegiado = AlertaRolesPrivilegiados.EsPrivilegiado(request.UsuarioRol);
        var emailNormalizado = (request.UsuarioEmail ?? string.Empty).Trim().ToLowerInvariant();

        // Defensa: usuario no privilegiado sin email => no puede haber match. Lista vacia.
        if (!esPrivilegiado && string.IsNullOrEmpty(emailNormalizado))
        {
            _logger.LogWarning(
                "GetNotificacionesFiltradas: usuario no privilegiado sin email. Rol={Rol}. Devolviendo lista vacia.",
                request.UsuarioRol);
            return ApiResponse<IReadOnlyList<JsonObject>>.Ok(
                Array.Empty<JsonObject>(), "Sin notificaciones para el usuario.");
        }

        var todas = await _dabClient.GetAllAsync(cancellationToken);

        IReadOnlyList<JsonObject> resultado;
        if (esPrivilegiado)
        {
            resultado = todas;
        }
        else
        {
            resultado = todas
                .Where(row => DestinatariosContiene(row, emailNormalizado))
                .ToList();
        }

        _logger.LogDebug(
            "GetNotificacionesFiltradas: Rol={Rol} Privilegiado={Priv} Total={Total} Devueltas={Devueltas}",
            request.UsuarioRol, esPrivilegiado, todas.Count, resultado.Count);

        return ApiResponse<IReadOnlyList<JsonObject>>.Ok(
            resultado, "Notificaciones obtenidas exitosamente.");
    }

    /// <summary>
    /// Indica si el campo "destinatarios" de la fila contiene el email dado.
    /// "destinatarios" es un string con correos separados por '|', ';' o ','.
    /// El match es exacto por token (normalizado trim+lowercase), no substring.
    /// </summary>
    private static bool DestinatariosContiene(JsonObject row, string emailNormalizado)
    {
        if (string.IsNullOrEmpty(emailNormalizado)) return false;

        var node = row["destinatarios"];
        if (node is null) return false;

        string? destinatarios;
        try
        {
            destinatarios = node.GetValue<string?>();
        }
        catch
        {
            // El campo no es un string simple; no podemos hacer match seguro.
            return false;
        }

        if (string.IsNullOrWhiteSpace(destinatarios)) return false;

        var tokens = destinatarios.Split(DestinatariosSeparators, StringSplitOptions.RemoveEmptyEntries);
        foreach (var token in tokens)
        {
            if (string.Equals(token.Trim(), emailNormalizado, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }
}
