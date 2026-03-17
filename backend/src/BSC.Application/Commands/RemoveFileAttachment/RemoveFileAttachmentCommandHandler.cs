using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.RemoveFileAttachment;

/// <summary>
/// Handler para el comando de eliminacion de archivo adjunto.
/// Solo elimina la referencia en MongoDB, NO el archivo fisico del disco.
/// </summary>
public class RemoveFileAttachmentCommandHandler : IRequestHandler<RemoveFileAttachmentCommand, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly ILogger<RemoveFileAttachmentCommandHandler> _logger;

    public RemoveFileAttachmentCommandHandler(ITaskItemRepository taskItemRepository, ILogger<RemoveFileAttachmentCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(RemoveFileAttachmentCommand request, CancellationToken cancellationToken)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(request.TaskId);
        if (taskItem == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{request.TaskId}'." }
            );
        }

        var isInsumo = request.FileType.Equals("insumo", StringComparison.OrdinalIgnoreCase);
        var isEvidence = request.FileType.Equals("evidence", StringComparison.OrdinalIgnoreCase);

        // Validar permisos segun tipo de archivo
        var role = request.RequesterRole;
        if (isInsumo)
        {
            if (!role.Equals("Gerente", StringComparison.OrdinalIgnoreCase) &&
                !role.Equals("Lider", StringComparison.OrdinalIgnoreCase))
            {
                return ApiResponse<TaskItemDto>.Fail(
                    "No autorizado.",
                    new List<string> { "Solo el Gerente o Lider pueden eliminar archivos de insumo." }
                );
            }
        }
        else if (isEvidence)
        {
            if (!role.Equals("Colaborador", StringComparison.OrdinalIgnoreCase) &&
                !role.Equals("Lider", StringComparison.OrdinalIgnoreCase))
            {
                return ApiResponse<TaskItemDto>.Fail(
                    "No autorizado.",
                    new List<string> { "Solo el Colaborador o Lider pueden eliminar archivos de evidencia." }
                );
            }
        }

        // Buscar y remover el archivo de la lista correspondiente
        var fileList = isInsumo ? taskItem.InsumoFiles : taskItem.EvidenceFiles;
        var file = fileList.FirstOrDefault(f => f.Id == request.FileId);

        if (file == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Archivo no encontrado.",
                new List<string> { $"No se encontro un archivo con el ID '{request.FileId}' en la lista de {(isInsumo ? "insumos" : "evidencias")}." }
            );
        }

        fileList.Remove(file);

        taskItem.UpdatedAt = DateTime.UtcNow;
        taskItem.UpdatedBy = request.RequesterEmail;

        await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation(
            "Archivo {FileId} ({FileName}) removido de {FileType} en tarea {TaskId} por {Email}",
            file.Id, file.FileName, request.FileType, taskItem.Id, request.RequesterEmail);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(taskItem), "Archivo eliminado exitosamente.");
    }
}
