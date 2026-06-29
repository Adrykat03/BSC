namespace BSC.Domain.Constants;

/// <summary>
/// Roles con privilegio para ver TODAS las alertas de Payroll, sin filtrar por destinatario.
/// La comparacion debe hacerse case-insensitive y con trim (ver <see cref="EsPrivilegiado"/>).
/// </summary>
public static class AlertaRolesPrivilegiados
{
    public const string Administrador = "Administrador";
    public const string Gerente = "Gerente";
    public const string SoporteAlertas = "Soporte Alertas";

    public static readonly IReadOnlyList<string> All = new[] { Administrador, Gerente, SoporteAlertas };

    /// <summary>
    /// Indica si el rol dado es privilegiado. Comparacion case-insensitive y con trim.
    /// </summary>
    public static bool EsPrivilegiado(string? rol)
    {
        if (string.IsNullOrWhiteSpace(rol)) return false;
        var normalizado = rol.Trim();
        return All.Any(r => string.Equals(r, normalizado, StringComparison.OrdinalIgnoreCase));
    }
}
