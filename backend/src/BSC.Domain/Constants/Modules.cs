namespace BSC.Domain.Constants;

/// <summary>
/// Catalogo de modulos del sistema. Las keys son ASCII en minuscula y constituyen
/// el contrato compartido con el frontend (claim "modules" del JWT y campo Role.Modules).
/// </summary>
public static class Modules
{
    public const string Dashboard = "dashboard";
    public const string Roles = "roles";
    public const string Colaboradores = "colaboradores";
    public const string Tareas = "tareas";
    public const string AlertasPayroll = "alertas-payroll";

    /// <summary>
    /// Conjunto con todas las keys de modulo validas. Usado para validar entrada.
    /// </summary>
    public static readonly IReadOnlyCollection<string> All = new[]
    {
        Dashboard,
        Roles,
        Colaboradores,
        Tareas,
        AlertasPayroll
    };

    /// <summary>
    /// Indica si la key proporcionada pertenece al catalogo de modulos.
    /// </summary>
    public static bool IsValid(string key) => key != null && All.Contains(key);
}
