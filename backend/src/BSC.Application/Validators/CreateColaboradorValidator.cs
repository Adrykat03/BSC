using BSC.Application.Features.Colaboradores.Commands.Create;
using FluentValidation;

namespace BSC.Application.Validators;

public class CreateColaboradorValidator : AbstractValidator<CreateColaboradorCommand>
{
    public CreateColaboradorValidator()
    {
        RuleFor(x => x.NombreCompleto)
            .NotEmpty().WithMessage("El nombre completo es requerido.")
            .MaximumLength(100).WithMessage("El nombre completo no puede exceder 100 caracteres.");

        RuleFor(x => x.Cedula)
            .NotEmpty().WithMessage("La cédula es requerida.")
            .Matches(@"^\d{10}$").WithMessage("La cédula debe tener exactamente 10 dígitos.");

        RuleFor(x => x.Correo)
            .NotEmpty().WithMessage("El correo es requerido.")
            .EmailAddress().WithMessage("El correo no tiene un formato válido.");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("La contraseña es requerida.")
            .MinimumLength(8).WithMessage("La contraseña debe tener al menos 8 caracteres.")
            .Matches(@"[A-Z]").WithMessage("La contraseña debe contener al menos una letra mayúscula.")
            .Matches(@"[a-z]").WithMessage("La contraseña debe contener al menos una letra minúscula.")
            .Matches(@"\d").WithMessage("La contraseña debe contener al menos un número.")
            .Matches(@"[^a-zA-Z\d]").WithMessage("La contraseña debe contener al menos un carácter especial.");

        RuleFor(x => x.Area)
            .NotEmpty().WithMessage("El área es requerida.");

        RuleFor(x => x.RolIds)
            .NotEmpty().WithMessage("Debe asignar al menos un rol.")
            .Must(ids => ids != null && ids.All(id => !string.IsNullOrWhiteSpace(id)))
            .WithMessage("Cada ID de rol debe ser válido y no estar vacío.");
    }
}
