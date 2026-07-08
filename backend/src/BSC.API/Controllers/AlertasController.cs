using System.Security.Claims;
using BSC.API.Authorization;
using BSC.Application.Common;
using BSC.Application.DTOs;
using BSC.Application.Features.Alertas.Commands.ChangeAlertaStatus;
using BSC.Application.Features.Alertas.Queries.GetAlertaHistorial;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BSC.API.Controllers;

/// <summary>
/// Controller para el modulo de Alertas Payroll.
/// La tabla principal (Avisos.notificacionesConsolidadas) vive en SQL Server y se actualiza
/// via DAB. El historial de cambios de estado se persiste en MongoDB.
///
/// El acceso se controla por el modulo "alertas-payroll" (claim "modules" del JWT).
/// </summary>
[ApiController]
[Authorize]
[RequireModule(Modules.AlertasPayroll)]
[Route("api/[controller]")]
public class AlertasController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IAlertaAdjuntoRepository _adjuntoRepository;

    private const string FilesBasePath = "/app/files";
    private const string AdjuntosRelativeDir = "alertas-resolucion";
    private const long MaxFileSize = 20 * 1024 * 1024; // 20MB

    public AlertasController(IMediator mediator, IAlertaAdjuntoRepository adjuntoRepository)
    {
        _mediator = mediator;
        _adjuntoRepository = adjuntoRepository;
    }

    private static AlertaAdjuntoDto ToDto(AlertaResolucionAdjunto a) => new()
    {
        Id = a.Id,
        IdNotificacion = a.IdNotificacion,
        FileName = a.FileName,
        ContentType = a.ContentType,
        SizeBytes = a.SizeBytes,
        SubidoPorEmail = a.SubidoPorEmail,
        Fecha = a.Fecha,
    };

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

    /// <summary>
    /// Sube uno o varios adjuntos de resolucion para una alerta (multipart/form-data).
    /// El archivo va a disco (/app/files) y la metadata a MongoDB. Lo puede hacer cualquier
    /// usuario con acceso al modulo (los que cambian estado). El email se toma del JWT.
    /// </summary>
    [HttpPost("{id:long}/adjuntos")]
    [ProducesResponseType(typeof(ApiResponse<List<AlertaAdjuntoDto>>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<List<AlertaAdjuntoDto>>), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SubirAdjuntos(long id, CancellationToken cancellationToken)
    {
        var email = GetUserEmail();
        if (string.IsNullOrWhiteSpace(email))
            return Unauthorized(ApiResponse<List<AlertaAdjuntoDto>>.Fail("Token sin email del usuario."));

        if (!Request.HasFormContentType || Request.Form.Files.Count == 0)
            return BadRequest(ApiResponse<List<AlertaAdjuntoDto>>.Fail(
                "No se recibieron archivos.",
                new List<string> { "Adjunte al menos un archivo." }));

        var files = Request.Form.Files.Where(f => f.Length > 0).ToList();

        // Validacion (tamano + magic bytes) antes de escribir nada a disco.
        foreach (var f in files)
        {
            if (f.Length > MaxFileSize)
                return BadRequest(ApiResponse<List<AlertaAdjuntoDto>>.Fail(
                    "Archivo demasiado grande.",
                    new List<string> { $"El archivo '{f.FileName}' excede el maximo de 20MB." }));

            var ext = Path.GetExtension(f.FileName);
            using var vs = f.OpenReadStream();
            if (!FileValidationHelper.ValidateMagicBytes(vs, ext))
                return BadRequest(ApiResponse<List<AlertaAdjuntoDto>>.Fail(
                    "Archivo invalido.",
                    new List<string> { $"El archivo '{f.FileName}' no coincide con el tipo esperado ({ext})." }));
        }

        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        Directory.CreateDirectory(Path.Combine(FilesBasePath, AdjuntosRelativeDir));

        var saved = new List<AlertaAdjuntoDto>();
        for (int i = 0; i < files.Count; i++)
        {
            var f = files[i];
            var safeFileName = Path.GetFileName(f.FileName);
            var diskFileName = $"{id}_{timestamp}_{i}_{safeFileName}";
            var relativePath = Path.Combine(AdjuntosRelativeDir, diskFileName);
            var absolutePath = Path.Combine(FilesBasePath, relativePath);

            using (var stream = new FileStream(absolutePath, FileMode.Create))
            {
                await f.CopyToAsync(stream, cancellationToken);
            }

            var entity = await _adjuntoRepository.CreateAsync(new AlertaResolucionAdjunto
            {
                IdNotificacion = id,
                FileName = f.FileName,
                FilePath = relativePath,
                ContentType = string.IsNullOrEmpty(f.ContentType) ? "application/octet-stream" : f.ContentType,
                SizeBytes = f.Length,
                SubidoPorEmail = email,
                Fecha = DateTime.UtcNow,
            }, cancellationToken);

            saved.Add(ToDto(entity));
        }

        return Ok(ApiResponse<List<AlertaAdjuntoDto>>.Ok(saved, "Adjuntos subidos."));
    }

    /// <summary>Lista los adjuntos de resolucion de una alerta.</summary>
    [HttpGet("{id:long}/adjuntos")]
    [ProducesResponseType(typeof(ApiResponse<List<AlertaAdjuntoDto>>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAdjuntos(long id, CancellationToken cancellationToken)
    {
        var list = await _adjuntoRepository.GetByIdNotificacionAsync(id, cancellationToken);
        return Ok(ApiResponse<List<AlertaAdjuntoDto>>.Ok(list.Select(ToDto).ToList()));
    }

    /// <summary>Descarga/sirve un adjunto de resolucion por su id (con proteccion de path traversal).</summary>
    [HttpGet("{id:long}/adjuntos/{adjuntoId}")]
    [ProducesResponseType(typeof(FileStreamResult), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DescargarAdjunto(long id, string adjuntoId, CancellationToken cancellationToken)
    {
        var a = await _adjuntoRepository.GetByIdAsync(adjuntoId, cancellationToken);
        if (a == null || a.IdNotificacion != id)
            return NotFound(ApiResponse<object>.Fail("Adjunto no encontrado."));

        var absolutePath = Path.GetFullPath(Path.Combine(FilesBasePath, a.FilePath));
        var baseFull = Path.GetFullPath(FilesBasePath) + Path.DirectorySeparatorChar;
        if (!absolutePath.StartsWith(baseFull))
            return BadRequest(ApiResponse<object>.Fail("Ruta de archivo invalida."));

        if (!System.IO.File.Exists(absolutePath))
            return NotFound(ApiResponse<object>.Fail("El archivo no existe en el servidor."));

        var stream = new FileStream(absolutePath, FileMode.Open, FileAccess.Read);
        return File(stream, string.IsNullOrEmpty(a.ContentType) ? "application/octet-stream" : a.ContentType, a.FileName);
    }

    /// <summary>Elimina un adjunto de resolucion (archivo en disco + metadata en Mongo).</summary>
    [HttpDelete("{id:long}/adjuntos/{adjuntoId}")]
    [ProducesResponseType(typeof(ApiResponse<bool>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<bool>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> EliminarAdjunto(long id, string adjuntoId, CancellationToken cancellationToken)
    {
        var a = await _adjuntoRepository.GetByIdAsync(adjuntoId, cancellationToken);
        if (a == null || a.IdNotificacion != id)
            return NotFound(ApiResponse<bool>.Fail("Adjunto no encontrado."));

        try
        {
            var absolutePath = Path.GetFullPath(Path.Combine(FilesBasePath, a.FilePath));
            var baseFull = Path.GetFullPath(FilesBasePath) + Path.DirectorySeparatorChar;
            if (absolutePath.StartsWith(baseFull) && System.IO.File.Exists(absolutePath))
                System.IO.File.Delete(absolutePath);
        }
        catch { /* best-effort: si falla el borrado fisico, igual quitamos la metadata */ }

        await _adjuntoRepository.DeleteAsync(adjuntoId, cancellationToken);
        return Ok(ApiResponse<bool>.Ok(true, "Adjunto eliminado."));
    }
}
