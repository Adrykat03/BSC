using BSC.Application.DTOs;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace BSC.Application.Commands.UploadEvidence;

/// <summary>
/// Comando para subir evidencia de una tarea.
/// Solo el colaborador asignado puede subir evidencia.
/// </summary>
public class UploadEvidenceCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string TaskId { get; set; } = string.Empty;
    public IFormFile EvidenceFile { get; set; } = null!;
    public string UploaderEmail { get; set; } = string.Empty;
}
