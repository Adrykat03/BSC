using BSC.Application.DTOs;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.CreateTaskItem;

/// <summary>
/// Handler para el comando de creacion de tarea.
/// </summary>
public class CreateTaskItemCommandHandler : IRequestHandler<CreateTaskItemCommand, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly ILogger<CreateTaskItemCommandHandler> _logger;

    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".pdf", ".jpg", ".jpeg", ".png", ".doc", ".docx", ".xls", ".xlsx"
    };

    private const long MaxFileSize = 10 * 1024 * 1024; // 10MB
    private const string UploadsBasePath = "/app/uploads/tasks";

    public CreateTaskItemCommandHandler(ITaskItemRepository taskItemRepository, ILogger<CreateTaskItemCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(CreateTaskItemCommand request, CancellationToken cancellationToken)
    {
        var taskItem = new TaskItem
        {
            Title = request.Title,
            Description = request.Description,
            AssignedTo = request.AssignedTo,
            Status = "Creada",
            EstimatedTime = request.EstimatedTime,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        // Procesar archivo de evidencia si se proporciona
        if (request.Evidence != null && request.Evidence.Length > 0)
        {
            if (request.Evidence.Length > MaxFileSize)
            {
                return ApiResponse<TaskItemDto>.Fail(
                    "El archivo excede el tamaño máximo permitido.",
                    new List<string> { "El tamaño máximo permitido es 10MB." }
                );
            }

            var extension = Path.GetExtension(request.Evidence.FileName);
            if (!AllowedExtensions.Contains(extension))
            {
                return ApiResponse<TaskItemDto>.Fail(
                    "Tipo de archivo no permitido.",
                    new List<string> { "Los tipos permitidos son: pdf, jpg, jpeg, png, doc, docx, xls, xlsx." }
                );
            }

            // Crear tarea primero para obtener el Id
            var created = await _taskItemRepository.CreateAsync(taskItem);

            // Guardar archivo
            var fileName = $"{created.Id}{extension}";
            var filePath = Path.Combine(UploadsBasePath, fileName);

            Directory.CreateDirectory(UploadsBasePath);
            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await request.Evidence.CopyToAsync(stream, cancellationToken);
            }

            // Actualizar tarea con datos del archivo
            created.EvidenceFileName = request.Evidence.FileName;
            created.EvidenceFilePath = filePath;
            created.EvidenceContentType = request.Evidence.ContentType;
            await _taskItemRepository.UpdateAsync(created);

            _logger.LogInformation("Tarea creada exitosamente con evidencia: {Title} ({TaskId})", created.Title, created.Id);

            return ApiResponse<TaskItemDto>.Ok(MapToDto(created), "Tarea creada exitosamente.");
        }

        var createdTask = await _taskItemRepository.CreateAsync(taskItem);

        _logger.LogInformation("Tarea creada exitosamente: {Title} ({TaskId})", createdTask.Title, createdTask.Id);

        return ApiResponse<TaskItemDto>.Ok(MapToDto(createdTask), "Tarea creada exitosamente.");
    }

    private static TaskItemDto MapToDto(TaskItem taskItem)
    {
        return new TaskItemDto
        {
            Id = taskItem.Id,
            Title = taskItem.Title,
            Description = taskItem.Description,
            AssignedTo = taskItem.AssignedTo,
            Status = taskItem.Status,
            EstimatedTime = taskItem.EstimatedTime,
            ActualTime = taskItem.ActualTime,
            EvidenceFileName = taskItem.EvidenceFileName,
            HasEvidence = !string.IsNullOrEmpty(taskItem.EvidenceFilePath),
            CreatedAt = taskItem.CreatedAt,
            UpdatedAt = taskItem.UpdatedAt
        };
    }
}
