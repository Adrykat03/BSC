using BSC.Application.DTOs;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace BSC.Application.Commands.CreateTaskItem;

/// <summary>
/// Comando para crear una nueva tarea. Solo el Gerente deberia crear tareas.
/// </summary>
public class CreateTaskItemCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime? DueDate { get; set; }
    public decimal? EstimatedTime { get; set; }
    public string? Insumos { get; set; }
    public string? Observations { get; set; }
    public List<IFormFile>? InsumoFiles { get; set; }
    public string CreatedByEmail { get; set; } = string.Empty;
}
