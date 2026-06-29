using System.Text.Json.Nodes;
using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Features.Alertas.Queries.GetNotificacionesFiltradas;

/// <summary>
/// Query que lista las notificaciones de Alertas Payroll desde DAB y las filtra
/// segun el rol y el email del usuario:
///  - Rol privilegiado: ve TODAS las filas.
///  - Resto: solo las filas cuyo campo "destinatarios" contiene su email.
/// Las filas se devuelven completas (passthrough) preservando los nombres de campo de DAB.
/// </summary>
public class GetNotificacionesFiltradasQuery : IRequest<ApiResponse<IReadOnlyList<JsonObject>>>
{
    public string UsuarioEmail { get; set; } = string.Empty;
    public string UsuarioRol { get; set; } = string.Empty;
}
