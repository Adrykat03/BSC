using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Constants;
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
            EstimatedTime = request.EstimatedTime,
            Insumos = request.Insumos,
            CreatedAt = DateTime.UtcNow,
            CreatedBy = request.CreatedByEmail,
            UpdatedAt = DateTime.UtcNow,
            UpdatedBy = request.CreatedByEmail
        };

        // Procesar archivo de insumo si se proporciona
        if (request.InsumoFile != null && request.InsumoFile.Length > 0)
        {
            if (request.InsumoFile.Length > MaxFileSize)
            {
                return ApiResponse<TaskItemDto>.Fail(
                    "El archivo excede el tamano maximo permitido.",
                    new List<string> { "El tamano maximo permitido es 10MB." }
                );
            }

            var extension = Path.GetExtension(request.InsumoFile.FileName);
            if (!AllowedExtensions.Contains(extension))
            {
                return ApiResponse<TaskItemDto>.Fail(
                    "Tipo de archivo no permitido.",
                    new List<string> { "Los tipos permitidos son: pdf, jpg, jpeg, png, doc, docx, xls, xlsx." }
                );
            }

            // Crear tarea primero para obtener el Id
            var created = await _taskItemRepository.CreateAsync(taskItem);

            // Guardar archivo de insumo en disco
            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            var safeFileName = Path.GetFileName(request.InsumoFile.FileName);
            var diskFileName = $"{created.Id}_{timestamp}_{safeFileName}";
            var relativePath = Path.Combine(InsumosRelativeDir, diskFileName);
            var absolutePath = Path.Combine(FilesBasePath, relativePath);

            Directory.CreateDirectory(Path.Combine(FilesBasePath, InsumosRelativeDir));
            using (var stream = new FileStream(absolutePath, FileMode.Create))
            {
                await request.InsumoFile.CopyToAsync(stream, cancellationToken);
            }

            // Actualizar tarea con path relativo (NO absoluto, NO contenido binario)
            created.InsumoFileName = request.InsumoFile.FileName;
            created.InsumoFilePath = relativePath;
            created.InsumoContentType = request.InsumoFile.ContentType;
            await _taskItemRepository.UpdateAsync(created);

            _logger.LogInformation("Tarea creada exitosamente con insumo: {Title} ({TaskId})", created.Title, created.Id);

            return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(created), "Tarea creada exitosamente.");
        }

        var createdTask = await _taskItemRepository.CreateAsync(taskItem);

        _logger.LogInformation("Tarea creada exitosamente: {Title} ({TaskId})", createdTask.Title, createdTask.Id);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(createdTask), "Tarea creada exitosamente.");
    }
}
