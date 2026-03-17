using FluentValidation;

namespace BSC.Application.Commands.UpdateTaskItem;

/// <summary>
/// Validador para el comando de actualizacion de tarea.
/// </summary>
public class UpdateTaskItemCommandValidator : AbstractValidator<UpdateTaskItemCommand>
{
    public UpdateTaskItemCommandValidator()
    {
        RuleFor(x => x.Id)
            .NotEmpty().WithMessage("El ID es requerido.");

        RuleFor(x => x.Title)
            .NotEmpty().WithMessage("El título es requerido.")
            .MaximumLength(200).WithMessage("El título no puede exceder 200 caracteres.");

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("La descripción es requerida.")
            .MaximumLength(2000).WithMessage("La descripción no puede exceder 2000 caracteres.");

        RuleFor(x => x.AssignedTo)
            .MaximumLength(200).WithMessage("El campo asignado a no puede exceder 200 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.AssignedTo));

        RuleFor(x => x.EstimatedTime)
            .GreaterThan(0).WithMessage("El tiempo estimado debe ser mayor a 0.")
            .When(x => x.EstimatedTime.HasValue);
    }
}
