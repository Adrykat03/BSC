using BSC.Domain.Constants;
using FluentValidation;

namespace BSC.Application.Commands.OverrideTaskRating;

/// <summary>
/// Validador para OverrideTaskRatingCommand.
/// </summary>
public class OverrideTaskRatingCommandValidator : AbstractValidator<OverrideTaskRatingCommand>
{
    public OverrideTaskRatingCommandValidator()
    {
        RuleFor(x => x.TaskId)
            .NotEmpty().WithMessage("El ID de la tarea es requerido.");

        RuleFor(x => x.NewRating)
            .InclusiveBetween(0, 100)
            .WithMessage("La calificación debe estar entre 0 y 100.");

        RuleFor(x => x.Reason)
            .NotEmpty().WithMessage("La justificación es requerida.")
            .MinimumLength(10).WithMessage("La justificación debe tener al menos 10 caracteres.")
            .MaximumLength(1000).WithMessage("La justificación no puede exceder 1000 caracteres.");

        RuleFor(x => x.ChangedByEmail)
            .NotEmpty().WithMessage("El email del usuario es requerido.")
            .EmailAddress().WithMessage("El email del usuario no es válido.");

        RuleFor(x => x.ChangedByRole)
            .NotEmpty().WithMessage("El rol del usuario es requerido.")
            .Equal(TaskStateTransitions.RolGerente)
            .WithMessage("Solo el rol Gerente puede modificar la calificación.");
    }
}
