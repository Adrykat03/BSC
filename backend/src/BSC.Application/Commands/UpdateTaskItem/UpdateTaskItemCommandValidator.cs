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
            .NotEmpty().WithMessage("El titulo es requerido.")
            .MaximumLength(200).WithMessage("El titulo no puede exceder 200 caracteres.");

        RuleFor(x => x.Description)
            .NotEmpty().WithMessage("La descripcion es requerida.")
            .MaximumLength(2000).WithMessage("La descripcion no puede exceder 2000 caracteres.");

        RuleFor(x => x.EstimatedTime)
            .GreaterThanOrEqualTo(0).WithMessage("El tiempo estimado debe ser mayor o igual a 0.")
            .Must(v => v!.Value % 0.5m == 0).WithMessage("El tiempo estimado debe ser multiplo de 0.5.")
            .When(x => x.EstimatedTime.HasValue);

        RuleFor(x => x.Insumos)
            .MaximumLength(5000).WithMessage("Los insumos no pueden exceder 5000 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.Insumos));

        RuleFor(x => x.Observations)
            .MaximumLength(5000).WithMessage("Las observaciones no pueden exceder 5000 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.Observations));

        RuleFor(x => x.EvidenceText)
            .MaximumLength(5000).WithMessage("La evidencia no puede exceder 5000 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.EvidenceText));

        RuleFor(x => x.UpdatedByEmail)
            .NotEmpty().WithMessage("El email del usuario es requerido.")
            .EmailAddress().WithMessage("El email del usuario no es valido.");
    }
}
