using BSC.Domain.Constants;
using FluentValidation;

namespace BSC.Application.Commands.RevertTaskStatus;

/// <summary>
/// Validador para el comando de reversion de estado de tarea.
/// </summary>
public class RevertTaskStatusCommandValidator : AbstractValidator<RevertTaskStatusCommand>
{
    public RevertTaskStatusCommandValidator()
    {
        RuleFor(x => x.TaskId)
            .NotEmpty().WithMessage("El ID de la tarea es requerido.");

        RuleFor(x => x.RevertedByEmail)
            .NotEmpty().WithMessage("El email del usuario es requerido.")
            .EmailAddress().WithMessage("El email del usuario no es valido.");

        RuleFor(x => x.RevertedByRole)
            .NotEmpty().WithMessage("El rol del usuario es requerido.")
            .Must(r => r == TaskStateTransitions.RolLider || r == TaskStateTransitions.RolColaborador)
            .WithMessage("Solo Lider y Colaborador pueden retomar tareas.");

        RuleFor(x => x.Comment)
            .MaximumLength(2000).WithMessage("El comentario no puede exceder 2000 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.Comment));
    }
}
