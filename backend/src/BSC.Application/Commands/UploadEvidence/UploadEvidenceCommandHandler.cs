using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Interfaces;
using BSC.Domain.ValueObjects;
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

        // Validar que al menos se envie archivo o texto
        var hasFiles = request.EvidenceFiles != null && request.EvidenceFiles.Count > 0 && request.EvidenceFiles.Any(f => f.Length > 0);
        var hasText = !string.IsNullOrWhiteSpace(request.EvidenceText);

        if (!hasFiles && !hasText)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Evidencia requerida.",
                new List<string> { "Debe proporcionar al menos un archivo de evidencia o un texto de evidencia." }
            );
        }

        // Procesar archivos si se proporcionan (se AGREGAN a los existentes)
        if (hasFiles)
        {
            foreach (var file in request.EvidenceFiles!)
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
            }

            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            Directory.CreateDirectory(Path.Combine(FilesBasePath, EvidenciasRelativeDir));

            for (int i = 0; i < request.EvidenceFiles!.Count; i++)
            {
                var file = request.EvidenceFiles[i];
                if (file.Length == 0) continue;

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

        // Guardar texto de evidencia si se proporciona
        if (hasText)
        {
            taskItem.EvidenceText = request.EvidenceText;
        }

        taskItem.UpdatedAt = DateTime.UtcNow;
        taskItem.UpdatedBy = request.UploaderEmail;

        await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation(
            "Evidencia subida para tarea {TaskId} por {Email}",
            taskItem.Id, request.UploaderEmail);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(taskItem), "Evidencia subida exitosamente.");
    }
}
