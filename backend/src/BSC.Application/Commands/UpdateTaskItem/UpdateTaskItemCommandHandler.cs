using BSC.Application.Common;
using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Constants;
using BSC.Domain.Interfaces;
using BSC.Domain.ValueObjects;
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

    private const long MaxFileSize = 20 * 1024 * 1024; // 20MB
    private const string FilesBasePath = "/app/files";
    private const string InsumosRelativeDir = "insumos";
    private const string EvidenciasRelativeDir = "evidencias";

    public UpdateTaskItemCommandHandler(ITaskItemRepository taskItemRepository, ILogger<UpdateTaskItemCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(UpdateTaskItemCommand request, CancellationToken cancellationToken)
    {
        // H-02: Validar que solo Gerente o Lider puedan editar tareas
        if (request.UpdatedByRole != TaskStateTransitions.RolGerente
            && request.UpdatedByRole != TaskStateTransitions.RolLider)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "No tiene permisos para editar tareas.",
                new List<string> { "Solo Gerente y Lider pueden editar tareas." }
            );
        }

        var taskItem = await _taskItemRepository.GetByIdAsync(request.Id);
        if (taskItem == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{request.Id}'." }
            );
        }

        taskItem.Title = request.Title;
        taskItem.Description = request.Description;

        // Si el rol es Lider, preservar el DueDate original (no puede modificarlo)
        if (request.UpdatedByRole != TaskStateTransitions.RolLider)
        {
            taskItem.DueDate = request.DueDate;
        }

        taskItem.EstimatedTime = request.EstimatedTime;
        taskItem.Insumos = request.Insumos;
        taskItem.Observations = request.Observations;
        taskItem.EvidenceText = request.EvidenceText;
        taskItem.UpdatedAt = DateTime.UtcNow;
        taskItem.UpdatedBy = request.UpdatedByEmail;

        // Procesar archivos de insumo si se proporcionan (se AGREGAN a los existentes)
        if (request.InsumoFiles != null && request.InsumoFiles.Count > 0)
        {
            foreach (var file in request.InsumoFiles)
            {
                if (file.Length > MaxFileSize)
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "El archivo excede el tamano maximo permitido.",
                        new List<string> { $"El archivo '{file.FileName}' excede el tamano maximo de 20MB." }
                    );
                }

                var extension = Path.GetExtension(file.FileName);
                using var validationStream = file.OpenReadStream();
                if (!FileValidationHelper.ValidateMagicBytes(validationStream, extension))
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "Archivo invalido.",
                        new List<string> { $"El archivo '{file.FileName}' no coincide con el tipo esperado ({extension})." }
                    );
                }
            }

            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            Directory.CreateDirectory(Path.Combine(FilesBasePath, InsumosRelativeDir));

            for (int i = 0; i < request.InsumoFiles.Count; i++)
            {
                var file = request.InsumoFiles[i];
                var safeFileName = Path.GetFileName(file.FileName);
                var diskFileName = $"{taskItem.Id}_{timestamp}_{i}_{safeFileName}";
                var relativePath = Path.Combine(InsumosRelativeDir, diskFileName);
                var absolutePath = Path.Combine(FilesBasePath, relativePath);

                using (var stream = new FileStream(absolutePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream, cancellationToken);
                }

                taskItem.InsumoFiles.Add(new FileAttachment
                {
                    FileName = file.FileName,
                    FilePath = relativePath,
                    ContentType = file.ContentType,
                    UploadedAt = DateTime.UtcNow
                });
            }
        }

        // Procesar archivos de evidencia si se proporcionan (se AGREGAN a los existentes)
        if (request.EvidenceFiles != null && request.EvidenceFiles.Count > 0)
        {
            foreach (var file in request.EvidenceFiles)
            {
                if (file.Length > MaxFileSize)
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "El archivo excede el tamano maximo permitido.",
                        new List<string> { $"El archivo '{file.FileName}' excede el tamano maximo de 20MB." }
                    );
                }

                var extension = Path.GetExtension(file.FileName);
                using var validationStream = file.OpenReadStream();
                if (!FileValidationHelper.ValidateMagicBytes(validationStream, extension))
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "Archivo invalido.",
                        new List<string> { $"El archivo '{file.FileName}' no coincide con el tipo esperado ({extension})." }
                    );
                }
            }

            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            Directory.CreateDirectory(Path.Combine(FilesBasePath, EvidenciasRelativeDir));

            for (int i = 0; i < request.EvidenceFiles.Count; i++)
            {
                var file = request.EvidenceFiles[i];
                var safeFileName = Path.GetFileName(file.FileName);
                var diskFileName = $"{taskItem.Id}_{timestamp}_{i}_{safeFileName}";
                var relativePath = Path.Combine(EvidenciasRelativeDir, diskFileName);
                var absolutePath = Path.Combine(FilesBasePath, relativePath);

                using (var stream = new FileStream(absolutePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream, cancellationToken);
                }

                taskItem.EvidenceFiles.Add(new FileAttachment
                {
                    FileName = file.FileName,
                    FilePath = relativePath,
                    ContentType = file.ContentType,
                    UploadedAt = DateTime.UtcNow
                });
            }
        }

        var updated = await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation("Tarea actualizada exitosamente: {Title} ({TaskId})", updated.Title, updated.Id);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(updated), "Tarea actualizada exitosamente.");
    }
}
