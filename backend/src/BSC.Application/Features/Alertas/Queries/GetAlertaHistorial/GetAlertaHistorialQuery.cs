using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Features.Alertas.Queries.GetAlertaHistorial;

/// <summary>
/// Query para obtener el historial de cambios de estado de una alerta.
/// Lee de MongoDB (alertasEstadosHistorial), ordenado por fecha DESC.
/// </summary>
public class GetAlertaHistorialQuery : IRequest<ApiResponse<AlertaHistorialListDto>>
{
    public long IdNotificacion { get; set; }
}
