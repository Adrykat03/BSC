using BSC.Application.DTOs;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace BSC.Application.Commands.UpdateTaskItem;

/// <summary>
/// Comando para actualizar una tarea existente.
/// </summary>
public class UpdateTaskItemCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? AssignedTo { get; set; }
    public decimal? EstimatedTime { get; set; }
    public IFormFile? Evidence { get; set; }
}
