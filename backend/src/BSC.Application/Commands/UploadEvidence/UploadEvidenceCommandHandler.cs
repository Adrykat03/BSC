using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.UploadEvidence;

/// <summary>
/// Handler para el comando de subida de evidencia.
/// Solo el colaborador asignado a la tarea puede subir evidencia.
/// </summary>
public class UploadEvidenceCommandHandler : IRequestHandler<UploadEvidenceCommand, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly ILogger<UploadEvidenceCommandHandler> _logger;

    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".pdf", ".jpg", ".jpeg", ".png", ".doc", ".docx", ".xls", ".xlsx"
    };

    private const long MaxFileSize = 10 * 1024 * 1024; // 10MB
    private const string FilesBasePath = "/app/files";
    private const string EvidenciasRelativeDir = "evidencias";

    public UploadEvidenceCommandHandler(ITaskItemRepository taskItemRepository, ILogger<UploadEvidenceCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(UploadEvidenceCommand request, CancellationToken cancellationToken)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(request.TaskId);
        if (taskItem == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{request.TaskId}'." }
            );
        }

        // Verificar que el uploader es el colaborador asignado
        if (string.IsNullOrEmpty(taskItem.AssignedToEmail) ||
            !taskItem.AssignedToEmail.Equals(request.UploaderEmail, StringComparison.OrdinalIgnoreCase))
        {
            return ApiResponse<TaskItemDto>.Fail(
                "No autorizado.",
                new List<string> { "Solo el colaborador asignado a la tarea puede subir evidencia." }
            );
        }

        // Validar archivo
        if (request.EvidenceFile == null || request.EvidenceFile.Length == 0)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Archivo requerido.",
                new List<string> { "Debe proporcionar un archivo de evidencia." }
            );
        }

        if (request.EvidenceFile.Length > MaxFileSize)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "El archivo excede el tamano maximo permitido.",
                new List<string> { "El tamano maximo permitido es 10MB." }
            );
        }

        var extension = Path.GetExtension(request.EvidenceFile.FileName);
        if (!AllowedExtensions.Contains(extension))
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tipo de archivo no permitido.",
                new List<string> { "Los tipos permitidos son: pdf, jpg, jpeg, png, doc, docx, xls, xlsx." }
            );
        }

        // NO eliminar archivo anterior — los archivos nunca se borran del disco

        // Guardar archivo de evidencia con timestamp para evitar colisiones
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var safeFileName = Path.GetFileName(request.EvidenceFile.FileName);
        var diskFileName = $"{taskItem.Id}_{timestamp}_{safeFileName}";
        var relativePath = Path.Combine(EvidenciasRelativeDir, diskFileName);
        var absolutePath = Path.Combine(FilesBasePath, relativePath);

        Directory.CreateDirectory(Path.Combine(FilesBasePath, EvidenciasRelativeDir));
        using (var stream = new FileStream(absolutePath, FileMode.Create))
        {
            await request.EvidenceFile.CopyToAsync(stream, cancellationToken);
        }

        taskItem.EvidenceFileName = request.EvidenceFile.FileName;
        taskItem.EvidenceFilePath = relativePath;
        taskItem.EvidenceContentType = request.EvidenceFile.ContentType;
        taskItem.UpdatedAt = DateTime.UtcNow;
        taskItem.UpdatedBy = request.UploaderEmail;

        await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation(
            "Evidencia subida para tarea {TaskId} por {Email}",
            taskItem.Id, request.UploaderEmail);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(taskItem), "Evidencia subida exitosamente.");
    }
}
