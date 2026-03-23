using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.RevertTaskStatus;

/// <summary>
/// Comando para revertir una tarea a su estado anterior basado en el historial.
/// Solo Colaborador y Lider pueden ejecutar esta accion.
/// </summary>
public class RevertTaskStatusCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string TaskId { get; set; } = string.Empty;
    public string RevertedByEmail { get; set; } = string.Empty;
    public string RevertedByRole { get; set; } = string.Empty;
    public string? Comment { get; set; }
}
