using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.RateTask;

/// <summary>
/// Comando para calificar una tarea (1-10).
/// Solo Lider y Gerente pueden calificar.
/// </summary>
public class RateTaskCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string TaskId { get; set; } = string.Empty;
    public int Rating { get; set; }
    public string RatedByEmail { get; set; } = string.Empty;
    public string RatedByRole { get; set; } = string.Empty;
}
