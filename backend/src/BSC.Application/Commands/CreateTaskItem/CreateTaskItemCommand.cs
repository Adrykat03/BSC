using BSC.Application.DTOs;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace BSC.Application.Commands.CreateTaskItem;

/// <summary>
/// Comando para crear una nueva tarea. Gerente y Lider pueden crear tareas.
/// Cuando un Lider crea una tarea, se auto-asigna como lider y opcionalmente asigna un colaborador.
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
    public string CreatedByRole { get; set; } = string.Empty;
    public string CreatedById { get; set; } = string.Empty;
    public string CreatedByName { get; set; } = string.Empty;

    /// <summary>
    /// ID del colaborador a asignar (opcional). Usado por el Lider al crear una tarea.
    /// </summary>
    public string? AssigneeId { get; set; }
}
