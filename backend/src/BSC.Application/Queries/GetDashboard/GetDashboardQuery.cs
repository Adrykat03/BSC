using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Queries.GetDashboard;

/// <summary>
/// Query para obtener las estadísticas del dashboard de tareas.
/// Soporta filtrado opcional por rango de fechas.
/// </summary>
public class GetDashboardQuery : IRequest<ApiResponse<DashboardDto>>
{
    /// <summary>
    /// Fecha inicio del filtro (opcional).
    /// </summary>
    public DateTime? From { get; set; }

    /// <summary>
    /// Fecha fin del filtro (opcional).
    /// </summary>
    public DateTime? To { get; set; }

    /// <summary>
    /// Email del usuario autenticado (para filtrado por rol).
    /// </summary>
    public string? UserEmail { get; set; }

    /// <summary>
    /// Rol del usuario autenticado (Gerente, Lider, Colaborador).
    /// </summary>
    public string? UserRole { get; set; }
}
