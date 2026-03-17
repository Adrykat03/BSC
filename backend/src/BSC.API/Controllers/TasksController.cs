using BSC.Application.Commands.AssignTask;
using BSC.Application.Commands.ChangeTaskStatus;
using BSC.Application.Commands.CreateTaskItem;
using BSC.Application.Commands.DeleteTaskItem;
using BSC.Application.Commands.UpdateTaskItem;
using BSC.Application.Commands.UploadEvidence;
using BSC.Application.DTOs;
using BSC.Application.Queries.GetTaskItemById;
using BSC.Application.Queries.GetTaskItems;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BSC.API.Controllers;

/// <summary>
/// Controller para la gestion de tareas del sistema.
/// Soporta flujo de estados por rol (Gerente, Lider, Colaborador).
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class TasksController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ITaskItemRepository _taskItemRepository;

    public TasksController(IMediator mediator, ITaskItemRepository taskItemRepository)
    {
        _mediator = mediator;
        _taskItemRepository = taskItemRepository;
    }

    /// <summary>
    /// Obtiene la lista paginada de tareas, filtrada por rol y email del usuario.
    /// </summary>
    /// <param name="page">Numero de pagina (default: 1).</param>
    /// <param name="pageSize">Cantidad de registros por pagina (default: 20, max: 100).</param>
    /// <param name="userEmail">Email del usuario para filtrar por rol.</param>
    /// <param name="userRole">Rol del usuario (Gerente, Lider, Colaborador).</param>
    /// <returns>Lista paginada de tareas.</returns>
    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<PaginatedResult<TaskItemDto>>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? userEmail = null,
        [FromQuery] string? userRole = null)
    {
        var query = new GetTaskItemsQuery
        {
            Page = page,
            PageSize = pageSize,
            UserEmail = userEmail,
            UserRole = userRole
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
    /// Crea una nueva tarea. Soporta multipart/form-data para adjuntar archivo de insumo.
    /// </summary>
    /// <param name="command">Datos de la tarea a crear.</param>
    /// <returns>Tarea creada.</returns>
    [HttpPost]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromForm] CreateTaskItemCommand command)
    {
        var result = await _mediator.Send(command);

        if (!result.Success)
            return BadRequest(result);

        return CreatedAtAction(nameof(GetById), new { id = result.Data!.Id }, result);
    }

    /// <summary>
    /// Actualiza una tarea existente. Soporta multipart/form-data para adjuntar archivo de insumo.
    /// No permite cambiar el estado (usar PUT /api/tasks/{id}/status para eso).
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
    /// Cambia el estado de una tarea. Valida la transicion segun el rol del usuario.
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
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <param name="command">Archivo de evidencia y datos del uploader.</param>
    /// <returns>Tarea con evidencia actualizada.</returns>
    [HttpPost("{id}/evidence")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<TaskItemDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UploadEvidence(string id, [FromForm] UploadEvidenceCommand command)
    {
        command.TaskId = id;
        var result = await _mediator.Send(command);

        if (!result.Success)
        {
            if (result.Message.Contains("no encontrada", StringComparison.OrdinalIgnoreCase))
                return NotFound(result);

            return BadRequest(result);
        }

        return Ok(result);
    }

    private const string FilesBasePath = "/app/files";

    /// <summary>
    /// Descarga el archivo de evidencia de una tarea.
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <returns>Archivo de evidencia.</returns>
    [HttpGet("{id}/evidence")]
    [ProducesResponseType(typeof(FileStreamResult), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DownloadEvidence(string id)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(id);
        if (taskItem == null)
        {
            return NotFound(ApiResponse<object>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{id}'." }
            ));
        }

        if (string.IsNullOrEmpty(taskItem.EvidenceFilePath))
        {
            return NotFound(ApiResponse<object>.Fail(
                "Evidencia no encontrada.",
                new List<string> { "La tarea no tiene un archivo de evidencia asociado." }
            ));
        }

        // Construir ruta absoluta desde path relativo y validar path traversal
        var absolutePath = Path.GetFullPath(Path.Combine(FilesBasePath, taskItem.EvidenceFilePath));
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
                "Evidencia no encontrada.",
                new List<string> { "El archivo de evidencia no existe en el servidor." }
            ));
        }

        var stream = new FileStream(absolutePath, FileMode.Open, FileAccess.Read);
        return File(stream, taskItem.EvidenceContentType ?? "application/octet-stream", taskItem.EvidenceFileName);
    }

    /// <summary>
    /// Descarga el archivo de insumo de una tarea.
    /// </summary>
    /// <param name="id">ID de la tarea.</param>
    /// <returns>Archivo de insumo.</returns>
    [HttpGet("{id}/insumo")]
    [ProducesResponseType(typeof(FileStreamResult), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DownloadInsumo(string id)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(id);
        if (taskItem == null)
        {
            return NotFound(ApiResponse<object>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{id}'." }
            ));
        }

        if (string.IsNullOrEmpty(taskItem.InsumoFilePath))
        {
            return NotFound(ApiResponse<object>.Fail(
                "Insumo no encontrado.",
                new List<string> { "La tarea no tiene un archivo de insumo asociado." }
            ));
        }

        // Construir ruta absoluta desde path relativo y validar path traversal
        var absolutePath = Path.GetFullPath(Path.Combine(FilesBasePath, taskItem.InsumoFilePath));
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
                "Insumo no encontrado.",
                new List<string> { "El archivo de insumo no existe en el servidor." }
            ));
        }

        var stream = new FileStream(absolutePath, FileMode.Open, FileAccess.Read);
        return File(stream, taskItem.InsumoContentType ?? "application/octet-stream", taskItem.InsumoFileName);
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
