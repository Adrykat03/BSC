namespace BSC.Application.DTOs;

/// <summary>
/// DTO con las estadísticas del dashboard de tareas.
/// </summary>
public class DashboardDto
{
    /// <summary>
    /// Mapa de calor: colaboradores y cantidad de tareas recibidas.
    /// </summary>
    public List<CollaboratorHeatmapItem> CollaboratorHeatmap { get; set; } = new();

    /// <summary>
    /// Mapa de calor: colaboradores con tareas activas (no Completa ni Cancelada).
    /// </summary>
    public List<CollaboratorHeatmapItem> CollaboratorHeatmapActive { get; set; } = new();

    /// <summary>
    /// Tiempo promedio (horas) que las tareas pasan en cada estado.
    /// </summary>
    public List<StatusAvgTimeItem> AvgTimeByStatus { get; set; } = new();

    /// <summary>
    /// Tareas por colaborador desglosadas por estado.
    /// </summary>
    public List<CollaboratorStatusBreakdown> TasksByCollaboratorAndStatus { get; set; } = new();

    /// <summary>
    /// Total de tareas por estado (para gráfico pastel).
    /// </summary>
    public List<StatusCountItem> TasksByStatus { get; set; } = new();

    /// <summary>
    /// Etiquetas destacadas.
    /// </summary>
    public HighlightLabels Highlights { get; set; } = new();

    /// <summary>
    /// Timeline de tareas completadas por colaborador (para gráfico de líneas).
    /// </summary>
    public List<CollaboratorCompletionTimeline> CompletionTimeline { get; set; } = new();
}

/// <summary>
/// Timeline de completación de tareas para un colaborador.
/// </summary>
public class CollaboratorCompletionTimeline
{
    public string Name { get; set; } = string.Empty;
    public List<TimelineDataPoint> DataPoints { get; set; } = new();
}

/// <summary>
/// Punto de datos en el timeline: fecha y conteo acumulado.
/// </summary>
public class TimelineDataPoint
{
    public string Date { get; set; } = string.Empty;
    public int CumulativeCount { get; set; }
}

/// <summary>
/// Item del mapa de calor de colaboradores.
/// </summary>
public class CollaboratorHeatmapItem
{
    public string Name { get; set; } = string.Empty;
    public int TaskCount { get; set; }
}

/// <summary>
/// Tiempo promedio en horas que las tareas permanecen en un estado.
/// </summary>
public class StatusAvgTimeItem
{
    public string Status { get; set; } = string.Empty;
    public double AvgHours { get; set; }
}

/// <summary>
/// Desglose de tareas por estado para un colaborador.
/// </summary>
public class CollaboratorStatusBreakdown
{
    public string Name { get; set; } = string.Empty;
    public Dictionary<string, int> StatusCounts { get; set; } = new();
}

/// <summary>
/// Conteo de tareas en un estado específico.
/// </summary>
public class StatusCountItem
{
    public string Status { get; set; } = string.Empty;
    public int Count { get; set; }
}

/// <summary>
/// Etiquetas destacadas del dashboard.
/// </summary>
public class HighlightLabels
{
    /// <summary>
    /// Colaborador con menor tiempo promedio en tareas que llegaron a "Completa".
    /// </summary>
    public string FastestCollaboratorName { get; set; } = string.Empty;
    public double FastestCollaboratorAvgHours { get; set; }

    /// <summary>
    /// Líder con más tareas completas gestionadas en su historial.
    /// </summary>
    public string TopLeaderName { get; set; } = string.Empty;
    public int TopLeaderCompletedCount { get; set; }
}
