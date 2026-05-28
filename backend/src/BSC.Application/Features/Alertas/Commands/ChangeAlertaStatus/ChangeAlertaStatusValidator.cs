using BSC.Domain.Constants;
using FluentValidation;

namespace BSC.Application.Features.Alertas.Commands.ChangeAlertaStatus;

/// <summary>
/// Validador para el comando de cambio de estado de alerta.
/// </summary>
public class ChangeAlertaStatusValidator : AbstractValidator<ChangeAlertaStatusCommand>
{
    public ChangeAlertaStatusValidator()
    {
        RuleFor(x => x.IdNotificacion)
            .GreaterThan(0).WithMessage("El idNotificacion debe ser mayor a cero.");

        RuleFor(x => x.NuevoEstado)
            .NotEmpty().WithMessage("El nuevo estado es requerido.")
            .Must(AlertaEstados.IsValid)
            .WithMessage($"El estado debe ser uno de: {string.Join(", ", AlertaEstados.All)}.");

        RuleFor(x => x.Comentario)
            .MaximumLength(500).WithMessage("El comentario no puede exceder 500 caracteres.")
            .When(x => !string.IsNullOrEmpty(x.Comentario));

        RuleFor(x => x.UsuarioEmail)
            .NotEmpty().WithMessage("El email del usuario es requerido.")
            .EmailAddress().WithMessage("El email del usuario no es valido.");

        RuleFor(x => x.UsuarioRol)
            .NotEmpty().WithMessage("El rol del usuario es requerido.")
            .MaximumLength(50).WithMessage("El rol no puede exceder 50 caracteres.");
    }
}
