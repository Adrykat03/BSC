using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.OverrideTaskRating;

/// <summary>
/// Comando para que un Gerente modifique manualmente la calificación de una tarea.
/// Solo aplica para tareas en estado "Completa - Validada" o "Completa".
/// La justificación es obligatoria y se guarda en el audit trail (RatingHistory).
/// </summary>
public class OverrideTaskRatingCommand : IRequest<ApiResponse<TaskItemDto>>
{
    public string TaskId { get; set; } = string.Empty;
    public int NewRating { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string ChangedByEmail { get; set; } = string.Empty;
    public string ChangedByRole { get; set; } = string.Empty;
}
