using BSC.Application.DTOs;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.UpdateTaskItem;

/// <summary>
/// Handler para el comando de actualizacion de tarea.
/// </summary>
public class UpdateTaskItemCommandHandler : IRequestHandler<UpdateTaskItemCommand, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly ILogger<UpdateTaskItemCommandHandler> _logger;

    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".pdf", ".jpg", ".jpeg", ".png", ".doc", ".docx", ".xls", ".xlsx"
    };

    private const long MaxFileSize = 10 * 1024 * 1024; // 10MB
    private const string UploadsBasePath = "/app/uploads/tasks";

    public UpdateTaskItemCommandHandler(ITaskItemRepository taskItemRepository, ILogger<UpdateTaskItemCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(UpdateTaskItemCommand request, CancellationToken cancellationToken)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(request.Id);
        if (taskItem == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontró una tarea con el ID '{request.Id}'." }
            );
        }

        taskItem.Title = request.Title;
        taskItem.Description = request.Description;
        taskItem.AssignedTo = request.AssignedTo;
        taskItem.EstimatedTime = request.EstimatedTime;
        taskItem.UpdatedAt = DateTime.UtcNow;

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

            // Eliminar archivo anterior si existe
            if (!string.IsNullOrEmpty(taskItem.EvidenceFilePath) && File.Exists(taskItem.EvidenceFilePath))
            {
                File.Delete(taskItem.EvidenceFilePath);
            }

            // Guardar nuevo archivo
            var fileName = $"{taskItem.Id}{extension}";
            var filePath = Path.Combine(UploadsBasePath, fileName);

            Directory.CreateDirectory(UploadsBasePath);
            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await request.Evidence.CopyToAsync(stream, cancellationToken);
            }

            taskItem.EvidenceFileName = request.Evidence.FileName;
            taskItem.EvidenceFilePath = filePath;
            taskItem.EvidenceContentType = request.Evidence.ContentType;
        }

        var updated = await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation("Tarea actualizada exitosamente: {Title} ({TaskId})", updated.Title, updated.Id);

        var dto = new TaskItemDto
        {
            Id = updated.Id,
            Title = updated.Title,
            Description = updated.Description,
            AssignedTo = updated.AssignedTo,
            Status = updated.Status,
            EstimatedTime = updated.EstimatedTime,
            ActualTime = updated.ActualTime,
            EvidenceFileName = updated.EvidenceFileName,
            HasEvidence = !string.IsNullOrEmpty(updated.EvidenceFilePath),
            CreatedAt = updated.CreatedAt,
            UpdatedAt = updated.UpdatedAt
        };

        return ApiResponse<TaskItemDto>.Ok(dto, "Tarea actualizada exitosamente.");
    }
}
