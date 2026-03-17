using BSC.Application.Features.Colaboradores.Commands.Update;
using FluentValidation;

namespace BSC.Application.Validators;

public class UpdateColaboradorValidator : AbstractValidator<UpdateColaboradorCommand>
{
    public UpdateColaboradorValidator()
    {
        RuleFor(x => x.Id)
            .NotEmpty().WithMessage("El Id es requerido.");

        RuleFor(x => x.NombreCompleto)
            .NotEmpty().WithMessage("El nombre completo es requerido.")
            .MaximumLength(100).WithMessage("El nombre completo no puede exceder 100 caracteres.");

        RuleFor(x => x.Cedula)
            .NotEmpty().WithMessage("La cédula es requerida.")
            .Matches(@"^\d{10}$").WithMessage("La cédula debe tener exactamente 10 dígitos.");

        RuleFor(x => x.Correo)
            .NotEmpty().WithMessage("El correo es requerido.")
            .EmailAddress().WithMessage("El correo no tiene un formato válido.");

        RuleFor(x => x.Area)
            .NotEmpty().WithMessage("El área es requerida.");

        RuleFor(x => x.RolId)
            .NotEmpty().WithMessage("El rol es requerido.");
    }
}
