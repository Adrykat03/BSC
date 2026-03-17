using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.ChangeTaskStatus;

/// <summary>
/// Comando para cambiar el estado de una tarea.
/// Valida la transicion segun el rol del usuario.
/// </summary>
public class ChangeTaskStatusCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string TaskId { get; set; } = string.Empty;
    public string NewStatus { get; set; } = string.Empty;
    public string ChangedByEmail { get; set; } = string.Empty;
    public string ChangedByRole { get; set; } = string.Empty;
    public string? Comment { get; set; }
}
