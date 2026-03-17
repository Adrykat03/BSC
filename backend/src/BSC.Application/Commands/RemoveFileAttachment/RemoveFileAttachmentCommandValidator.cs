using FluentValidation;

namespace BSC.Application.Commands.RemoveFileAttachment;

/// <summary>
/// Validador para el comando de eliminacion de archivo adjunto.
/// </summary>
public class RemoveFileAttachmentCommandValidator : AbstractValidator<RemoveFileAttachmentCommand>
{
    private static readonly HashSet<string> ValidFileTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "insumo", "evidence"
    };

    public RemoveFileAttachmentCommandValidator()
    {
        RuleFor(x => x.TaskId)
            .NotEmpty().WithMessage("El ID de la tarea es requerido.");

        RuleFor(x => x.FileId)
            .NotEmpty().WithMessage("El ID del archivo es requerido.");

        RuleFor(x => x.FileType)
            .NotEmpty().WithMessage("El tipo de archivo es requerido.")
            .Must(ft => ValidFileTypes.Contains(ft))
            .WithMessage("El tipo de archivo debe ser 'insumo' o 'evidence'.");

        RuleFor(x => x.RequesterEmail)
            .NotEmpty().WithMessage("El email del solicitante es requerido.")
            .EmailAddress().WithMessage("El email del solicitante no es valido.");

        RuleFor(x => x.RequesterRole)
            .NotEmpty().WithMessage("El rol del solicitante es requerido.");
    }
}
