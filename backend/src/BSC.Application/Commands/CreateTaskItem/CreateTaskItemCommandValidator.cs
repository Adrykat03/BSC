using FluentValidation;

namespace BSC.Application.Commands.CreateTaskItem;

/// <summary>
/// Validador para el comando de creacion de tarea.
/// </summary>
public class CreateTaskItemCommandValidator : AbstractValidator<CreateTaskItemCommand>
{
    public CreateTaskItemCommandValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty().WithMessage("El titulo es requerido.")
            .MaximumLength(200).WithMessage("El titulo no puede exceder 200 caracteres.");

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("La descripcion es requerida.")
            .MaximumLength(2000).WithMessage("La descripcion no puede exceder 2000 caracteres.");

        RuleFor(x => x.EstimatedTime)
            .GreaterThan(0).WithMessage("El tiempo estimado debe ser mayor a 0.")
            .When(x => x.EstimatedTime.HasValue);

        RuleFor(x => x.Insumos)
            .MaximumLength(5000).WithMessage("Los insumos no pueden exceder 5000 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.Insumos));

        RuleFor(x => x.Observations)
            .MaximumLength(5000).WithMessage("Las observaciones no pueden exceder 5000 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.Observations));

        RuleFor(x => x.CreatedByEmail)
            .NotEmpty().WithMessage("El email del creador es requerido.")
            .EmailAddress().WithMessage("El email del creador no es valido.");
    }
}
