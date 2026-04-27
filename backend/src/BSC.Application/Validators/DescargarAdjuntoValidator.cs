using BSC.Application.Queries.DescargarAdjunto;
using FluentValidation;

namespace BSC.Application.Validators;

public class DescargarAdjuntoValidator : AbstractValidator<DescargarAdjuntoQuery>
{
    public DescargarAdjuntoValidator()
    {
        RuleFor(x => x.Ruta)
            .NotEmpty().WithMessage("La ruta del adjunto es obligatoria.")
            .MaximumLength(1000).WithMessage("La ruta no puede exceder 1000 caracteres.")
            .Must(NoTraversal).WithMessage("La ruta contiene caracteres no permitidos.");
    }

    private static bool NoTraversal(string ruta) =>
        !string.IsNullOrEmpty(ruta) && !ruta.Contains("..") && !ruta.StartsWith('/') && !ruta.Contains(':');
}
