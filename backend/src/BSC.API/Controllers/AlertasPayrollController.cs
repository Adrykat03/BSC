using BSC.Application.DTOs;
using BSC.Application.Queries.DescargarAdjunto;
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
