using BSC.Application.DTOs;
using BSC.Application.Mappings;
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
    private const string FilesBasePath = "/app/files";
    private const string InsumosRelativeDir = "insumos";

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
                new List<string> { $"No se encontro una tarea con el ID '{request.Id}'." }
            );
        }

        taskItem.Title = request.Title;
        taskItem.Description = request.Description;
        taskItem.EstimatedTime = request.EstimatedTime;
        taskItem.Insumos = request.Insumos;
        taskItem.UpdatedAt = DateTime.UtcNow;
        taskItem.UpdatedBy = request.UpdatedByEmail;

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

            // NO eliminar archivo anterior — los archivos nunca se borran del disco

            // Guardar nuevo archivo con timestamp para evitar colisiones
            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            var safeFileName = Path.GetFileName(request.InsumoFile.FileName);
            var diskFileName = $"{taskItem.Id}_{timestamp}_{safeFileName}";
            var relativePath = Path.Combine(InsumosRelativeDir, diskFileName);
            var absolutePath = Path.Combine(FilesBasePath, relativePath);

            Directory.CreateDirectory(Path.Combine(FilesBasePath, InsumosRelativeDir));
            using (var stream = new FileStream(absolutePath, FileMode.Create))
            {
                await request.InsumoFile.CopyToAsync(stream, cancellationToken);
            }

            taskItem.InsumoFileName = request.InsumoFile.FileName;
            taskItem.InsumoFilePath = relativePath;
            taskItem.InsumoContentType = request.InsumoFile.ContentType;
        }

        var updated = await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation("Tarea actualizada exitosamente: {Title} ({TaskId})", updated.Title, updated.Id);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(updated), "Tarea actualizada exitosamente.");
    }
}
