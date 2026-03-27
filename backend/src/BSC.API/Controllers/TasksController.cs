using System.Security.Claims;
using System.Text.Json;
using BSC.Application.Commands.AssignTask;
using BSC.Application.Commands.ChangeTaskStatus;
using BSC.Application.Commands.CreateTaskItem;
using BSC.Application.Commands.CreateTaskItemsBulk;
using BSC.Application.Commands.DeleteTaskItem;
using BSC.Application.Commands.RemoveFileAttachment;
using BSC.Application.Commands.RevertTaskStatus;
using BSC.Application.Commands.UpdateTaskItem;
using BSC.Application.Commands.UploadEvidence;
using BSC.Application.DTOs;
using BSC.Application.Queries.GetDashboard;
using BSC.Application.Queries.GetTaskItemById;
using BSC.Application.Queries.GetTaskItems;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BSC.API.Controllers;

/// <summary>
/// Controller para la gestion de tareas del sistema.
/// Soporta flujo de estados por rol (Gerente, Lider, Colaborador).
/// </summary>
[ApiController]
[Authorize]
[Route("api/[controller]")]
public class TasksController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ITaskItemRepository _taskItemRepository;

    private const string FilesBasePath = "/app/files";

    public TasksController(IMediator mediator, ITaskItemRepository taskItemRepository)
    {
        _mediator = mediator;
        _taskItemRepository = taskItemRepository;
    }

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? string.Empty;
    private string GetUserName() => User.FindFirstValue(ClaimTypes.Name) ?? string.Empty;
    private string GetUserEmail() => User.FindFirstValue(ClaimTypes.Email) ?? string.Empty;
    private string GetUserRole()
    {
        // ASP.NET mapea tanto "roles" (JSON array) como "role" (activo) a ClaimTypes.Role.
        // El rol activo es el claim que NO es un JSON array.
        var allRoles = User.FindAll(ClaimTypes.Role).Select(c => c.Value).ToList();
        return allRoles.FirstOrDefault(v => !v.TrimStart().StartsWith("[")) ?? string.Empty;
    }

    /// <summary>
    /// Exporta tareas filtradas por nombre de colaborador, estado opcional y rango de fechas.
    /// Usado por el gráfico de tareas por colaborador para descargar XLSX.
    /// Si se envía historicStatus, busca tareas que tengan esa transición en el historial.
    /// </summary>
    [HttpGet("export")]
    [ProducesResponseType(typeof(ApiResponse<List<TaskItemDto>>), StatusCodes.Status200OK)]
    public async Task<IActionResult> ExportByCollaborator(
        [FromQuery] string collaboratorName,
        [FromQuery] string? status = null,
        [FromQuery] string? historicStatus = null,
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null)
    {
        if (string.IsNullOrWhiteSpace(collaboratorName))
            return BadRequest(ApiResponse<object>.Fail("El nombre del colaborador es requerido."));

        List<Domain.Entities.TaskItem> tasks;

        if (!string.IsNullOrEmpty(historicStatus))
        {
            tasks = await _taskItemRepository.GetByCollaboratorWithHistoricStatusAsync(
                collaboratorName, historicStatus, from, to);
        }
        else
        {
            tasks = await _taskItemRepository.GetByCollaboratorNameAsync(
                collaboratorName, status, from, to);
        }

        var dtos = tasks.Select(BSC.Application.Mappings.TaskItemMapper.ToDto).ToList();
        return Ok(ApiResponse<List<TaskItemDto>>.Ok(dtos));
    }

    /// <summary>
    /// Obtiene las estadísticas del dashboard de tareas.
    /// Soporta filtrado opcional por rango de fechas (from, to) sobre createdAt.
    /// </summary>
    /// <param name="from">Fecha inicio del filtro (opcional).</param>
    /// <param name="to">Fecha fin del filtro (opcional).</param>
    /// <returns>Estadísticas del dashboard.</returns>
    [HttpGet("dashboard")]
    [ProducesResponseType(typeof(ApiResponse<DashboardDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetDashboard([FromQuery] DateTime? from, [FromQuery] DateTime? to)
    {
        var query = new GetDashboardQuery
        {
            From = from,
            To = to,
            UserEmail = GetUserEmail(),
            UserRole = GetUserRole()
        };
        var result = await _mediator.Send(query);
        return Ok(result);
    }

    /// <summary>
    /// Obtiene las estrellas mensuales del colaborador autenticado.
    /// Se calcula a partir del promedio de calificacion de tareas entregadas en el mes actual.
    /// </summary>
    [HttpGet("monthly-stars")]
    [ProducesResponseType(typeof(ApiResponse<MonthlyStarsDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMonthlyStars()
    {
        var email = GetUserEmail();
        var now = DateTime.UtcNow;
        var monthStart = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        var monthEnd = monthStart.AddMonths(1);

        var tasks = await _taskItemRepository.GetForDashboardByAssigneeAsync(email, null, null);

        // Filtrar tareas cuya primera entrega (CPV) fue en el mes actual y tienen rating
        var monthlyRated = tasks.Where(t =>
        {
            if (!t.Rating.HasValue) return false;
            var firstCpv = t.StatusHistory?
                .FirstOrDefault(h => h.ToStatus == "Completa - Por Validar");
            if (firstCpv == null) return false;
            return firstCpv.ChangedAt >= monthStart && firstCpv.ChangedAt < monthEnd;
        }).ToList();

        var result = new MonthlyStarsDto();

        if (monthlyRated.Count == 0)
        {
            // Sin tareas entregadas en el mes: 5 estrellas por defecto
            result.Stars = 5;
            result.Phrase = "Lo estas logrando, la excelencia es tuya";
            result.AvgRating = 100;
            result.TaskCount = 0;
            result.HasTasks = false;
        }
        else
        {
            var avg = Math.Round(monthlyRated.Average(t => t.Rating!.Value), 1);
            result.AvgRating = avg;
            result.TaskCount = monthlyRated.Count;
            result.HasTasks = true;

            if (avg >= 100)
            {
                result.Stars = 5;
                result.Phrase = "Lo estas logrando, la excelencia es tuya";
            }
            else if (avg >= 80)
            {
                result.Stars = 4;
                result.Phrase = "Cuida los detalles, marca la diferencia";
            }
            else if (avg >= 60)
            {
                result.Stars = 3;
                result.Phrase = "Enfocate en lo que realmente importa";
            }
            else if (avg >= 40)
            {
                result.Stars = 2;
                result.Phrase = "Refuerza tu organizacion de tiempos y tareas";
            }
            else
            {
                result.Stars = 1;
                result.Phrase = "Avanza, tu lider puede aclarar tus dudas";
            }

            // Frase especial de fin de mes para 100%
            var lastDayOfMonth = monthStart.AddMonths(1).AddDays(-1).Day;
            if (now.Day == lastDayOfMonth && avg >= 100)
            {
                result.BonusPhrase = "Excelente trabajo, tienes un dia libre";
            }
        }

        return Ok(ApiResponse<MonthlyStarsDto>.Ok(result));
    }

    /// <summary>
    /// Obtiene la lista paginada de tareas, filtrada por rol y email del usuario autenticado.
    /// </summary>
    /// <param name="page">Numero de pagina (default: 1).</param>
    /// <param name="pageSize">Cantidad de registros por pagina (default: 20, max: 100).</param>
    /// <returns>Lista paginada de tareas.</returns>
    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<PaginatedResult<TaskItemDto>>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null)
    {
        var query = new GetTaskItemsQuery
        {
            Page = page,
            PageSize = pageSize,
            UserEmail = GetUserEmail(),
            UserRole = GetUserRole(),
            Search = search
        };
        var result = await _mediator.Send(query);
        return Ok(result);
    }

    /// <summary>
    /// Obtiene una tarea por su ID.
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <returns>Datos de la tarea.</returns>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(string id)
    {
        var query = new GetTaskItemByIdQuery { Id = id };
        var result = await _mediator.Send(query);

        if (!result.Success)
            return NotFound(result);

        return Ok(result);
    }

    /// <summary>
    /// Crea una nueva tarea. Soporta multipart/form-data para adjuntar archivos de insumo.
    /// El email del creador se obtiene del JWT.
    /// </summary>
    /// <param name="command">Datos de la tarea a crear.</param>
    /// <returns>Tarea creada.</returns>
    [HttpPost]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromForm] CreateTaskItemCommand command)
    {
        command.CreatedByEmail = GetUserEmail();
        command.CreatedByRole = GetUserRole();
        command.CreatedById = GetUserId();
        command.CreatedByName = GetUserName();
        var result = await _mediator.Send(command);

        if (!result.Success)
            return BadRequest(result);

        return CreatedAtAction(nameof(GetById), new { id = result.Data!.Id }, result);
    }

    /// <summary>
    /// Crea tareas de forma masiva desde datos procesados de un XLSX.
    /// Solo Gerente y Lider pueden usar esta funcionalidad.
    /// En carga masiva, un Lider puede especificar cualquier otro lider en la columna de lider.
    /// </summary>
    /// <param name="command">Array de tareas a crear.</param>
    /// <returns>Resultado de la carga masiva con detalle por fila.</returns>
    [HttpPost("bulk")]
    [Consumes("application/json")]
    [ProducesResponseType(typeof(ApiResponse<BulkCreateResultDto>), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ApiResponse<BulkCreateResultDto>), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateBulk([FromBody] CreateTaskItemsBulkCommand command)
    {
        command.CreatedByEmail = GetUserEmail();
        command.CreatedByRole = GetUserRole();
        command.CreatedById = GetUserId();
        command.CreatedByName = GetUserName();
        var result = await _mediator.Send(command);

        if (!result.Success)
            return BadRequest(result);

        return StatusCode(StatusCodes.Status201Created, result);
    }

    /// <summary>
    /// Actualiza una tarea existente. Soporta multipart/form-data para adjuntar archivos de insumo y evidencia.
    /// Los archivos nuevos se AGREGAN a los existentes, no los reemplazan.
    /// No permite cambiar el estado (usar PUT /api/tasks/{id}/status para eso).
    /// El email del actualizador se obtiene del JWT.
    /// </summary>
    /// <param name="id">ID de la tarea a actualizar.</param>
    /// <param name="command">Datos actualizados de la tarea.</param>
    /// <returns>Tarea actualizada.</returns>
    [HttpPut("{id}")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(string id, [FromForm] UpdateTaskItemCommand command)
    {
        command.Id = id;
        command.UpdatedByEmail = GetUserEmail();
        command.UpdatedByRole = GetUserRole();
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
    /// Cambia el estado de una tarea. Valida la transicion segun el rol del usuario autenticado.
    /// El email y rol se obtienen del JWT.
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <param name="command">Datos del cambio de estado.</param>
    /// <returns>Tarea con estado actualizado.</returns>
    [HttpPut("{id}/status")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ChangeStatus(string id, [FromBody] ChangeTaskStatusCommand command)
    {
        command.TaskId = id;
        command.ChangedByEmail = GetUserEmail();
        command.ChangedByRole = GetUserRole();
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
    /// Retoma una tarea revertiendola a su estado anterior basado en el historial.
    /// Solo Colaborador y Lider pueden ejecutar esta accion.
    /// El email y rol se obtienen del JWT.
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <param name="command">Datos de la reversion (comentario opcional).</param>
    /// <returns>Tarea con estado revertido.</returns>
    [HttpPut("{id}/revert")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RevertStatus(string id, [FromBody] RevertTaskStatusCommand command)
    {
        command.TaskId = id;
        command.RevertedByEmail = GetUserEmail();
        command.RevertedByRole = GetUserRole();
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
    /// Asigna una tarea a un colaborador o lider.
    /// El email y rol del asignador se obtienen del JWT.
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <param name="command">Datos de la asignacion.</param>
    /// <returns>Tarea con asignacion actualizada.</returns>
    [HttpPut("{id}/assign")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Assign(string id, [FromBody] AssignTaskCommand command)
    {
        command.TaskId = id;
        command.AssignerEmail = GetUserEmail();
        command.AssignerRole = GetUserRole();
        var result = await _mediator.Send(command);

        if (!result.Success)
        {
            if (result.Message.Contains("no encontrad", StringComparison.OrdinalIgnoreCase))
                return NotFound(result);

            return BadRequest(result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Sube evidencia para una tarea. Solo el colaborador asignado puede hacerlo.
    /// Soporta multiples archivos que se AGREGAN a los existentes.
    /// El email del uploader se obtiene del JWT.
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <param name="command">Archivos de evidencia.</param>
    /// <returns>Tarea con evidencia actualizada.</returns>
    [HttpPost("{id}/evidence")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UploadEvidence(string id, [FromForm] UploadEvidenceCommand command)
    {
        command.TaskId = id;
        command.UploaderEmail = GetUserEmail();
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
    /// Descarga un archivo especifico por su FileId. Busca en ambas listas (insumos y evidencias).
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <param name="fileId">ID del archivo adjunto.</param>
    /// <returns>Archivo para descarga.</returns>
    [HttpGet("{id}/files/{fileId}")]
    [ProducesResponseType(typeof(FileStreamResult), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DownloadFile(string id, string fileId)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(id);
        if (taskItem == null)
        {
            return NotFound(ApiResponse<object>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{id}'." }
            ));
        }

        // Buscar el archivo en ambas listas
        var file = taskItem.InsumoFiles.FirstOrDefault(f => f.Id == fileId)
                ?? taskItem.EvidenceFiles.FirstOrDefault(f => f.Id == fileId);

        if (file == null)
        {
            return NotFound(ApiResponse<object>.Fail(
                "Archivo no encontrado.",
                new List<string> { $"No se encontro un archivo con el ID '{fileId}' en la tarea." }
            ));
        }

        // Construir ruta absoluta desde path relativo y validar path traversal
        var absolutePath = Path.GetFullPath(Path.Combine(FilesBasePath, file.FilePath));
        var baseFull = Path.GetFullPath(FilesBasePath) + Path.DirectorySeparatorChar;
        if (!absolutePath.StartsWith(baseFull))
        {
            return BadRequest(ApiResponse<object>.Fail(
                "Ruta de archivo invalida.",
                new List<string> { "La ruta del archivo no es valida." }
            ));
        }

        if (!System.IO.File.Exists(absolutePath))
        {
            return NotFound(ApiResponse<object>.Fail(
                "Archivo no encontrado.",
                new List<string> { "El archivo no existe en el servidor." }
            ));
        }

        var stream = new FileStream(absolutePath, FileMode.Open, FileAccess.Read);
        return File(stream, file.ContentType ?? "application/octet-stream", file.FileName);
    }

    /// <summary>
    /// Elimina un archivo adjunto de una tarea (solo la referencia en MongoDB, NO el archivo fisico).
    /// El email y rol del solicitante se obtienen del JWT.
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <param name="fileId">ID del archivo a eliminar.</param>
    /// <param name="fileType">Tipo de archivo: "insumo" o "evidence".</param>
    /// <returns>Tarea actualizada.</returns>
    [HttpDelete("{id}/files/{fileId}")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RemoveFile(
        string id,
        string fileId,
        [FromQuery] string fileType)
    {
        var command = new RemoveFileAttachmentCommand
        {
            TaskId = id,
            FileId = fileId,
            FileType = fileType,
            RequesterEmail = GetUserEmail(),
            RequesterRole = GetUserRole()
        };

        var result = await _mediator.Send(command);

        if (!result.Success)
        {
            if (result.Message.Contains("no encontrad", StringComparison.OrdinalIgnoreCase))
                return NotFound(result);

            return BadRequest(result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Elimina una tarea (soft delete).
    /// </summary>
    /// <param name="id">ID de la tarea a eliminar.</param>
    /// <returns>Confirmacion de eliminacion.</returns>
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(string id)
    {
        var command = new DeleteTaskItemCommand { Id = id };
        var result = await _mediator.Send(command);

        if (!result.Success)
            return NotFound(result);

        return NoContent();
    }
}
