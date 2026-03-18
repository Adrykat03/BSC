using FluentValidation;

namespace BSC.Application.Commands.CreateTaskItemsBulk;

/// <summary>
/// Validador para el comando de creacion masiva de tareas.
/// </summary>
public class CreateTaskItemsBulkCommandValidator : AbstractValidator<CreateTaskItemsBulkCommand>
{
    public CreateTaskItemsBulkCommandValidator()
    {
        RuleFor(x => x.Tasks)
            .NotNull().WithMessage("La lista de tareas es requerida.")
            .NotEmpty().WithMessage("Debe incluir al menos una tarea.");

        RuleFor(x => x.Tasks.Count)
            .LessThanOrEqualTo(100).WithMessage("No se pueden crear mas de 100 tareas a la vez.")
            .When(x => x.Tasks != null);

        RuleFor(x => x.CreatedByEmail)
            .NotEmpty().WithMessage("El email del creador es requerido.")
            .EmailAddress().WithMessage("Email del creador invalido.");

        RuleForEach(x => x.Tasks).ChildRules(task =>
        {
            task.RuleFor(t => t.Title)
                .NotEmpty().WithMessage("El titulo es requerido.")
                .MaximumLength(200).WithMessage("El titulo no puede exceder 200 caracteres.");

            task.RuleFor(t => t.Description)
                .NotEmpty().WithMessage("La descripcion es requerida.")
                .MaximumLength(2000).WithMessage("La descripcion no puede exceder 2000 caracteres.");

            task.RuleFor(t => t.Insumos)
                .MaximumLength(5000).WithMessage("Los insumos no pueden exceder 5000 caracteres.")
                .When(t => !string.IsNullOrEmpty(t.Insumos));

            task.RuleFor(t => t.Observations)
                .MaximumLength(5000).WithMessage("Las observaciones no pueden exceder 5000 caracteres.")
                .When(t => !string.IsNullOrEmpty(t.Observations));

            task.RuleFor(t => t.LeaderEmail)
                .MaximumLength(254).WithMessage("El email del lider no puede exceder 254 caracteres.")
                .EmailAddress().WithMessage("El email del lider es invalido.")
                .When(t => !string.IsNullOrWhiteSpace(t.LeaderEmail));

            task.RuleFor(t => t.CollaboratorEmail)
                .MaximumLength(254).WithMessage("El email del colaborador no puede exceder 254 caracteres.")
                .EmailAddress().WithMessage("El email del colaborador es invalido.")
                .When(t => !string.IsNullOrWhiteSpace(t.CollaboratorEmail));

            task.RuleFor(t => t.EstimatedTime)
                .GreaterThan(0).WithMessage("El tiempo estimado debe ser mayor a 0.")
                .When(t => t.EstimatedTime.HasValue);
        });
    }
}
