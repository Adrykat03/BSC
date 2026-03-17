namespace BSC.Domain.Constants;

/// <summary>
/// Estados validos para una tarea.
/// </summary>
public static class TaskStatuses
{
    public const string Creada = "Creada";
    public const string Asignada = "Asignada";
    public const string CompletaPorValidar = "Completa - Por Validar";
    public const string Reasignada = "Reasignada";
    public const string CompletaValidada = "Completa - Validada";
    public const string Completa = "Completa";
    public const string Cancelada = "Cancelada";

    public static readonly string[] All = new[]
    {
        Creada,
        Asignada,
        CompletaPorValidar,
        Reasignada,
        CompletaValidada,
        Completa,
        Cancelada
    };

    public static bool IsValid(string status) => All.Contains(status);
}
