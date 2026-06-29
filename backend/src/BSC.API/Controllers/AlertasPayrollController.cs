using System.Security.Claims;
using System.Text.Json.Nodes;
using BSC.API.Authorization;
using BSC.Application.DTOs;
using BSC.Application.Features.Alertas.Queries.GetNotificacionesFiltradas;
using BSC.Application.Queries.DescargarAdjunto;
using BSC.Domain.Constants;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BSC.API.Controllers;

/// <summary>
/// Endpoints relacionados con el modulo Alertas Payroll que consume DAB.
/// Por ahora solo expone la descarga de adjuntos via proxy al API interno de Utilerias Payroll.
/// </summary>
[ApiController]
[Authorize]
[RequireModule(Modules.AlertasPayroll)]
[Route("api/alertas-payroll")]
public class AlertasPayrollController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<AlertasPayrollController> _logger;

    public AlertasPayrollController(IMediator mediator, ILogger<AlertasPayrollController> logger)
    {
        _mediator = mediator;
        _logger = logger;
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
    /// Lista las notificaciones de Alertas Payroll (Avisos.notificacionesConsolidadas via DAB),
    /// filtradas segun el rol y el email del usuario autenticado:
    ///  - Rol privilegiado (Administrador, Gerente, Soporte Alertas): ve TODAS.
    ///  - Resto: solo aquellas donde su email aparece en el campo "destinatarios".
    /// Las filas se devuelven completas (passthrough) con los nombres de campo originales de DAB,
    /// ordenadas por fechaCreacion desc.
    /// </summary>
    [HttpGet("notificaciones")]
    [ProducesResponseType(typeof(ApiResponse<IReadOnlyList<JsonObject>>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status502BadGateway)]
    public async Task<IActionResult> GetNotificaciones(CancellationToken cancellationToken)
    {
        try
        {
            var query = new GetNotificacionesFiltradasQuery
            {
                UsuarioEmail = GetUserEmail(),
                UsuarioRol = GetUserRole(),
            };

            var resultado = await _mediator.Send(query, cancellationToken);
            return Ok(resultado);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Fallo al listar notificaciones desde DAB.");
            return StatusCode(StatusCodes.Status502BadGateway,
                ApiResponse<object>.Fail("No se pudieron obtener las notificaciones desde el proveedor de datos."));
        }
    }

    /// <summary>
    /// Descarga un adjunto de una alerta. Reenvia al API interna de Utilerias Payroll
    /// inyectando el token desde el .env del backend; el frontend nunca lo ve.
    /// </summary>
    /// <param name="ruta">Ruta del blob (columna rutaAdjunto).</param>
    /// <param name="nombre">Nombre amigable para el navegador (columna nombreAdjunto).</param>
    [HttpGet("adjunto")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status502BadGateway)]
    public async Task<IActionResult> DescargarAdjunto(
        [FromQuery] string ruta,
        [FromQuery] string? nombre,
        CancellationToken cancellationToken)
    {
        try
        {
            var query = new DescargarAdjuntoQuery
            {
                Ruta = ruta ?? string.Empty,
                NombreArchivo = nombre ?? string.Empty,
            };

            var resultado = await _mediator.Send(query, cancellationToken);

            return File(resultado.Contenido, resultado.ContentType, resultado.NombreArchivo);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Fallo al descargar adjunto desde Utilerias Payroll. Ruta={Ruta}", ruta);
            return StatusCode(StatusCodes.Status502BadGateway,
                ApiResponse<object>.Fail("No se pudo descargar el adjunto desde el proveedor."));
        }
    }
}
