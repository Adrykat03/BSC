namespace BSC.Domain.Constants;

/// <summary>
/// Estados validos para una notificacion de Alertas Payroll.
/// Se almacenan como char(1) en SQL Server (Avisos.notificacionesConsolidadas.estado).
/// </summary>
public static class AlertaEstados
{
    public const string Activa = "A";
    public const string Resuelta = "R";
    public const string Cerrada = "C";
    public const string Escalada = "E";
    public const string EnProceso = "P";

    public static readonly IReadOnlyList<string> All = new[] { Activa, Resuelta, Cerrada, Escalada, EnProceso };

    public static bool IsValid(string? estado) =>
        !string.IsNullOrEmpty(estado) && All.Contains(estado);
}
