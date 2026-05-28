using System.Security.Claims;
using BSC.Application.DTOs;
using BSC.Application.Features.Alertas.Commands.ChangeAlertaStatus;
using BSC.Application.Features.Alertas.Queries.GetAlertaHistorial;
using BSC.Domain.Constants;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BSC.API.Controllers;

/// <summary>
/// Controller para el modulo de Alertas Payroll.
/// La tabla principal (Avisos.notificacionesConsolidadas) vive en SQL Server y se actualiza
/// via DAB. El historial de cambios de estado se persiste en MongoDB.
///
/// Autorizacion (Hallazgo Security A01 - IDOR):
/// El historial almacena emails de quienes operaron la alerta (PII). Restringimos el acceso
/// a los roles administrativos/de supervision: Administrador, Gerente y Lider.
/// El rol Colaborador queda fuera (no debe poder enumerar emails de otros operadores).
/// La misma restriccion aplica al POST de cambiar-estado para defensa en profundidad.
/// </summary>
[ApiController]
[Authorize(Roles = AlertasController.RolesPermitidos)]
[Route("api/[controller]")]
public class AlertasController : ControllerBase
{
    // Roles autorizados para operar el modulo de Alertas Payroll.
    // Coincide con las constantes de Domain.Constants.TaskStateTransitions.
    internal const string RolesPermitidos =
        TaskStateTransitions.RolAdministrador + "," +
        TaskStateTransitions.RolGerente + "," +
        TaskStateTransitions.RolLider;

    private readonly IMediator _mediator;

    public AlertasController(IMediator mediator)
    {
        _mediator = mediator;
    }

    private string GetUserEmail() => User.FindFirstValue(ClaimTypes.Email) ?? string.Empty;

    /// <summary>
    /// Retorna el rol activo del usuario (ASP.NET mapea tanto "role" como "roles" -JSON array-
    /// del JWT a ClaimTypes.Role; el activo es el que NO empieza por '[').
    /// </summary>
    private string GetUserRole()
    {
        var allRoles = User.FindAll(ClaimTypes.Role).Select(c => c.Value).ToList();
        return allRoles.FirstOrDefault(v => !v.TrimStart().StartsWith("[")) ?? string.Empty;
    }

    /// <summary>
    /// Cambia el estado de una notificacion en SQL Server (via DAB) y registra
    /// el cambio en el historial de MongoDB.
    /// El usuario que ejecuta el cambio se obtiene del JWT (NO del body).
    /// </summary>
    /// <param name="id">idNotificacion (BIGINT en SQL).</param>
    /// <param name="dto">Datos del cambio de estado (nuevoEstado + comentario).</param>
    [HttpPost("{id:long}/cambiar-estado")]
    [ProducesResponseType(typeof(ApiResponse<ChangeAlertaStatusResultDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<ChangeAlertaStatusResultDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<ChangeAlertaStatusResultDto>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<ChangeAlertaStatusResultDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CambiarEstado(long id, [FromBody] ChangeAlertaStatusDto dto)
    {
        var usuarioEmail = GetUserEmail();
        var usuarioRol = GetUserRole();

        // Defensa en profundidad: aunque [Authorize] garantiza un usuario autenticado,
        // si los claims requeridos no estan presentes (token mal emitido / mapeo roto)
        // rechazamos explicitamente en lugar de persistir un valor vacio.
        if (string.IsNullOrWhiteSpace(usuarioEmail))
        {
            return Unauthorized(ApiResponse<ChangeAlertaStatusResultDto>.Fail(
                "Token sin claim de email del usuario.",
                new List<string> { "El claim ClaimTypes.Email es requerido para cambiar el estado de una alerta." }));
        }

        if (string.IsNullOrWhiteSpace(usuarioRol))
        {
            return Unauthorized(ApiResponse<ChangeAlertaStatusResultDto>.Fail(
                "Token sin claim de rol activo del usuario.",
                new List<string> { "El claim ClaimTypes.Role (rol activo) es requerido para cambiar el estado de una alerta." }));
        }

        var command = new ChangeAlertaStatusCommand
        {
            IdNotificacion = id,
            NuevoEstado = dto.NuevoEstado,
            Comentario = dto.Comentario,
            UsuarioEmail = usuarioEmail,
            UsuarioRol = usuarioRol,
        };

        var result = await _mediator.Send(command);

        if (!result.Success)
        {
            if (result.Message.Contains("no encontrada", StringComparison.OrdinalIgnoreCase))
                return NotFound(result);

            return BadRequest(result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Retorna el historial completo de cambios de estado de una alerta,
    /// ordenado por fecha DESC (mas reciente primero).
    /// </summary>
    /// <param name="id">idNotificacion (BIGINT en SQL).</param>
    [HttpGet("{id:long}/historial")]
    [ProducesResponseType(typeof(ApiResponse<AlertaHistorialListDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetHistorial(long id)
    {
        var result = await _mediator.Send(new GetAlertaHistorialQuery { IdNotificacion = id });
        return Ok(result);
    }
}
