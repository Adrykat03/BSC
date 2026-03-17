using BSC.Domain.Constants;
using FluentValidation;

namespace BSC.Application.Commands.AssignTask;

/// <summary>
/// Validador para el comando de asignacion de tarea.
/// </summary>
public class AssignTaskCommandValidator : AbstractValidator<AssignTaskCommand>
{
    public AssignTaskCommandValidator()
    {
        RuleFor(x => x.TaskId)
            .NotEmpty().WithMessage("El ID de la tarea es requerido.");

        RuleFor(x => x.AssigneeId)
            .NotEmpty().WithMessage("El ID del colaborador a asignar es requerido.");

        RuleFor(x => x.AssignerEmail)
            .NotEmpty().WithMessage("El email del asignador es requerido.")
            .EmailAddress().WithMessage("El email del asignador no es valido.");

        RuleFor(x => x.AssignerRole)
            .NotEmpty().WithMessage("El rol del asignador es requerido.")
            .Must(r => r == TaskStateTransitions.RolGerente || r == TaskStateTransitions.RolLider)
            .WithMessage("Solo Gerente y Lider pueden asignar tareas.");
    }
}
