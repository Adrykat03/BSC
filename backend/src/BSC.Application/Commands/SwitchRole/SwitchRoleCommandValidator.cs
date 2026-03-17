using FluentValidation;

namespace BSC.Application.Commands.SwitchRole;

/// <summary>
/// Validador para el comando de cambio de rol activo.
/// </summary>
public class SwitchRoleCommandValidator : AbstractValidator<SwitchRoleCommand>
{
    public SwitchRoleCommandValidator()
    {
        RuleFor(x => x.Role)
            .NotEmpty().WithMessage("El rol es requerido.");

        RuleFor(x => x.UserId)
            .NotEmpty().WithMessage("El ID del usuario es requerido.");
    }
}
