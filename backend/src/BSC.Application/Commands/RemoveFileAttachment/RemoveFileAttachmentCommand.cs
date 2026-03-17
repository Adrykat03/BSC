using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.RemoveFileAttachment;

/// <summary>
/// Comando para eliminar un archivo adjunto (insumo o evidencia) de una tarea.
/// Solo elimina la referencia en MongoDB, NO el archivo fisico del disco.
/// </summary>
public class RemoveFileAttachmentCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string TaskId { get; set; } = string.Empty;
    public string FileId { get; set; } = string.Empty;
    public string FileType { get; set; } = string.Empty; // "insumo" o "evidence"
    public string RequesterEmail { get; set; } = string.Empty;
    public string RequesterRole { get; set; } = string.Empty;
}
