using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Features.Alertas.Commands.ChangeAlertaStatus;

/// <summary>
/// Comando para registrar un cambio de estado en una notificacion de Alertas Payroll.
/// 1) Lee el estado actual via DAB.
/// 2) PATCH a DAB para actualizar estado/notasResolucion/usuarioResolucion/fechaResolucion.
/// 3) Si DAB OK, inserta registro en MongoDB (alertasEstadosHistorial).
/// </summary>
public class ChangeAlertaStatusCommand : IRequest<ApiResponse<ChangeAlertaStatusResultDto>>
{
    public long IdNotificacion { get; set; }
    public string NuevoEstado { get; set; } = string.Empty;
    public string? Comentario { get; set; }
    public string UsuarioEmail { get; set; } = string.Empty;
    public string UsuarioRol { get; set; } = string.Empty;
}
