using BSC.Application.DTOs;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace BSC.Application.Commands.UpdateTaskItem;

/// <summary>
/// Comando para actualizar una tarea existente.
/// No permite cambiar el estado (usar ChangeTaskStatus para eso).
/// </summary>
public class UpdateTaskItemCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime? DueDate { get; set; }
    public decimal? EstimatedTime { get; set; }
    public string? Insumos { get; set; }
    public List<IFormFile>? InsumoFiles { get; set; }
    public List<IFormFile>? EvidenceFiles { get; set; }
    public string? EvidenceText { get; set; }
    public string UpdatedByEmail { get; set; } = string.Empty;
}
