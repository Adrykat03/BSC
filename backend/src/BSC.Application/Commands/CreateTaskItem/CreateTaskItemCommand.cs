using BSC.Application.DTOs;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace BSC.Application.Commands.CreateTaskItem;

/// <summary>
/// Comando para crear una nueva tarea.
/// </summary>
public class CreateTaskItemCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? AssignedTo { get; set; }
    public decimal? EstimatedTime { get; set; }
    public IFormFile? Evidence { get; set; }
}
