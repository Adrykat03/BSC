using BSC.Application.Common;
using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using BSC.Domain.ValueObjects;
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
    private const string FilesBasePath = "/app/files";
    private const string InsumosRelativeDir = "insumos";

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
            Status = TaskStatuses.Creada,
            DueDate = request.DueDate,
            EstimatedTime = request.EstimatedTime,
            Insumos = request.Insumos,
            CreatedAt = DateTime.UtcNow,
            CreatedBy = request.CreatedByEmail,
            UpdatedAt = DateTime.UtcNow,
            UpdatedBy = request.CreatedByEmail
        };

        // Validar archivos de insumo antes de crear la tarea
        if (request.InsumoFiles != null && request.InsumoFiles.Count > 0)
        {
            foreach (var file in request.InsumoFiles)
            {
                if (file.Length > MaxFileSize)
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "El archivo excede el tamano maximo permitido.",
                        new List<string> { $"El archivo '{file.FileName}' excede el tamano maximo de 10MB." }
                    );
                }

                var extension = Path.GetExtension(file.FileName);
                if (!AllowedExtensions.Contains(extension))
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "Tipo de archivo no permitido.",
                        new List<string> { $"El archivo '{file.FileName}' tiene un tipo no permitido. Los tipos permitidos son: pdf, jpg, jpeg, png, doc, docx, xls, xlsx." }
                    );
                }

                using var validationStream = file.OpenReadStream();
                if (!FileValidationHelper.ValidateMagicBytes(validationStream, extension))
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "Archivo invalido.",
                        new List<string> { $"El archivo '{file.FileName}' no coincide con el tipo esperado ({extension})." }
                    );
                }
            }

            // Crear tarea primero para obtener el Id
            var created = await _taskItemRepository.CreateAsync(taskItem);

            // Guardar cada archivo de insumo en disco
            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            Directory.CreateDirectory(Path.Combine(FilesBasePath, InsumosRelativeDir));

            for (int i = 0; i < request.InsumoFiles.Count; i++)
            {
                var file = request.InsumoFiles[i];
                var safeFileName = Path.GetFileName(file.FileName);
                var diskFileName = $"{created.Id}_{timestamp}_{i}_{safeFileName}";
                var relativePath = Path.Combine(InsumosRelativeDir, diskFileName);
                var absolutePath = Path.Combine(FilesBasePath, relativePath);

                using (var stream = new FileStream(absolutePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream, cancellationToken);
                }

                created.InsumoFiles.Add(new FileAttachment
                {
                    FileName = file.FileName,
                    FilePath = relativePath,
                    ContentType = file.ContentType,
                    UploadedAt = DateTime.UtcNow
                });
            }

            await _taskItemRepository.UpdateAsync(created);

            _logger.LogInformation("Tarea creada exitosamente con {Count} insumo(s): {Title} ({TaskId})",
                request.InsumoFiles.Count, created.Title, created.Id);

            return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(created), "Tarea creada exitosamente.");
        }

        var createdTask = await _taskItemRepository.CreateAsync(taskItem);

        _logger.LogInformation("Tarea creada exitosamente: {Title} ({TaskId})", createdTask.Title, createdTask.Id);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(createdTask), "Tarea creada exitosamente.");
    }
}
