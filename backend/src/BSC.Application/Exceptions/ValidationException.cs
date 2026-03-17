namespace BSC.Application.Exceptions;

public class ValidationException : Exception
{
    public List<string> Errors { get; }

    public ValidationException(List<string> errors)
        : base("Se produjeron uno o más errores de validación.")
    {
        Errors = errors;
    }
}
