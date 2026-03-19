using FluentValidation;

namespace BSC.Application.Commands.UploadEvidence;

/// <summary>
/// Validador para el comando de subida de evidencia.
/// </summary>
public class UploadEvidenceCommandValidator : AbstractValidator<UploadEvidenceCommand>
{
    public UploadEvidenceCommandValidator()
    {
        RuleFor(x => x.TaskId)
            .NotEmpty().WithMessage("El ID de la tarea es requerido.");

        RuleFor(x => x.UploaderEmail)
            .NotEmpty().WithMessage("El email del colaborador es requerido.")
            .EmailAddress().WithMessage("El email del colaborador no es valido.");

    }
}
