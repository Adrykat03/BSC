namespace BSC.Domain.Constants;

/// <summary>
/// Define las transiciones de estado validas por rol.
/// </summary>
public static class TaskStateTransitions
{
    public const string RolGerente = "Gerente";
    public const string RolLider = "Lider";
    public const string RolColaborador = "Colaborador";

    private static readonly Dictionary<string, List<(string From, string To)>> _transitions = new()
    {
        [RolGerente] = new List<(string, string)>
        {
            (TaskStatuses.Creada, TaskStatuses.Asignada),
            (TaskStatuses.CompletaValidada, TaskStatuses.Completa),
            (TaskStatuses.CompletaValidada, TaskStatuses.Reasignada),
            // Cancelar desde cualquier estado activo
            (TaskStatuses.Asignada, TaskStatuses.Cancelada),
            (TaskStatuses.CompletaPorValidar, TaskStatuses.Cancelada),
            (TaskStatuses.Reasignada, TaskStatuses.Cancelada),
            (TaskStatuses.CompletaValidada, TaskStatuses.Cancelada),
        },
        [RolLider] = new List<(string, string)>
        {
            (TaskStatuses.Asignada, TaskStatuses.Asignada), // reasignar a Colaborador
            (TaskStatuses.CompletaPorValidar, TaskStatuses.CompletaValidada),
            (TaskStatuses.CompletaPorValidar, TaskStatuses.Reasignada)
        },
        [RolColaborador] = new List<(string, string)>
        {
            (TaskStatuses.Asignada, TaskStatuses.CompletaPorValidar),
            (TaskStatuses.Reasignada, TaskStatuses.CompletaPorValidar)
        }
    };

    /// <summary>
    /// Verifica si una transicion de estado es valida para un rol dado.
    /// </summary>
    public static bool IsValidTransition(string role, string fromStatus, string toStatus)
    {
        if (!_transitions.ContainsKey(role))
            return false;

        return _transitions[role].Any(t => t.From == fromStatus && t.To == toStatus);
    }

    /// <summary>
    /// Obtiene las transiciones permitidas para un rol y estado actual.
    /// </summary>
    public static List<string> GetAllowedTransitions(string role, string currentStatus)
    {
        if (!_transitions.ContainsKey(role))
            return new List<string>();

        return _transitions[role]
            .Where(t => t.From == currentStatus)
            .Select(t => t.To)
            .Distinct()
            .ToList();
    }
}
