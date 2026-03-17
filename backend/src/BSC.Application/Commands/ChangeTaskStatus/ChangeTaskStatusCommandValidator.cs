using BSC.Domain.Constants;
using FluentValidation;

namespace BSC.Application.Commands.ChangeTaskStatus;

/// <summary>
/// Validador para el comando de cambio de estado de tarea.
/// </summary>
public class ChangeTaskStatusCommandValidator : AbstractValidator<ChangeTaskStatusCommand>
{
    public ChangeTaskStatusCommandValidator()
    {
        RuleFor(x => x.TaskId)
            .NotEmpty().WithMessage("El ID de la tarea es requerido.");

        RuleFor(x => x.NewStatus)
            .NotEmpty().WithMessage("El nuevo estado es requerido.")
            .Must(s => TaskStatuses.IsValid(s))
            .WithMessage("El estado proporcionado no es valido.");

        RuleFor(x => x.ChangedByEmail)
            .NotEmpty().WithMessage("El email del usuario es requerido.")
            .EmailAddress().WithMessage("El email del usuario no es valido.");

        RuleFor(x => x.ChangedByRole)
            .NotEmpty().WithMessage("El rol del usuario es requerido.")
            .Must(r => r == TaskStateTransitions.RolGerente
                     || r == TaskStateTransitions.RolLider
                     || r == TaskStateTransitions.RolColaborador)
            .WithMessage("El rol debe ser Gerente, Lider o Colaborador.");

        RuleFor(x => x.Comment)
            .MaximumLength(2000).WithMessage("El comentario no puede exceder 2000 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.Comment));
    }
}
