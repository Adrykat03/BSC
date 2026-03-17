using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.AssignTask;

/// <summary>
/// Comando para asignar una tarea a un colaborador o lider.
/// </summary>
public class AssignTaskCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string TaskId { get; set; } = string.Empty;
    public string AssigneeId { get; set; } = string.Empty;
    public string AssignerEmail { get; set; } = string.Empty;
    public string AssignerRole { get; set; } = string.Empty;
}
