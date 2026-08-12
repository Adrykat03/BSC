using BSC.Application.DTOs;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Queries.GetDashboard;

/// <summary>
/// Handler para la query del dashboard. Carga todas las tareas y calcula estadísticas en memoria.
/// </summary>
public class GetDashboardQueryHandler : IRequestHandler<GetDashboardQuery, ApiResponse<DashboardDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly IBscDashboardConfigRepository _bscConfigRepository;
    private readonly ILogger<GetDashboardQueryHandler> _logger;

    public GetDashboardQueryHandler(ITaskItemRepository taskItemRepository, IBscDashboardConfigRepository bscConfigRepository, ILogger<GetDashboardQueryHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _bscConfigRepository = bscConfigRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<DashboardDto>> Handle(GetDashboardQuery request, CancellationToken cancellationToken)
    {
        _logger.LogInformation("Calculando estadísticas del dashboard. From={From}, To={To}, Role={Role}, Email={Email}",
            request.From, request.To, request.UserRole, request.UserEmail);

        List<TaskItem> tasks;
        List<TaskItem> allTasks;

        if (!string.IsNullOrEmpty(request.UserRole) && !string.IsNullOrEmpty(request.UserEmail))
        {
            switch (request.UserRole)
            {
                case TaskStateTransitions.RolLider:
                    tasks = await _taskItemRepository.GetForDashboardByLeaderAsync(request.UserEmail, request.From, request.To);
                    allTasks = (request.From.HasValue || request.To.HasValue)
                        ? await _taskItemRepository.GetForDashboardByLeaderAsync(request.UserEmail, null, null)
                        : tasks;
                    break;

                case TaskStateTransitions.RolColaborador:
                    tasks = await _taskItemRepository.GetForDashboardByAssigneeAsync(request.UserEmail, request.From, request.To);
                    allTasks = (request.From.HasValue || request.To.HasValue)
                        ? await _taskItemRepository.GetForDashboardByAssigneeAsync(request.UserEmail, null, null)
                        : tasks;
                    break;

                case TaskStateTransitions.RolGerente:
                    tasks = await _taskItemRepository.GetAllForDashboardAsync(request.From, request.To);
                    allTasks = (request.From.HasValue || request.To.HasValue)
                        ? await _taskItemRepository.GetAllForDashboardAsync(null, null)
                        : tasks;
                    break;

                default: // Rol desconocido: no mostrar datos (principio de menor privilegio)
                    _logger.LogWarning("Dashboard solicitado con rol no reconocido: {Role}", request.UserRole);
                    tasks = new List<TaskItem>();
                    allTasks = new List<TaskItem>();
                    break;
            }
        }
        else
        {
            // Sin rol/email: no mostrar datos (principio de menor privilegio)
            _logger.LogWarning("Dashboard solicitado sin rol o email. Role={Role}, Email={Email}", request.UserRole, request.UserEmail);
            tasks = new List<TaskItem>();
            allTasks = new List<TaskItem>();
        }

        // Obtener configuracion BSC para excluir tareas BSC del promedio general
        var bscConfig = await _bscConfigRepository.GetActiveConfigAsync();
        var bscEmails = bscConfig?.Emails ?? new List<string>();
        var bscPattern = bscConfig?.TaskTitlePattern ?? "";
        var bscEmailSet = new HashSet<string>(bscEmails, StringComparer.OrdinalIgnoreCase);

        // "Más eficiente" es mensual por defecto (igual criterio que Estrella del
        // mes: DueDate, con CreatedAt de respaldo), salvo que el usuario haya
        // elegido explícitamente un rango de fechas en el Dashboard — en ese caso
        // se respeta ese rango en vez del mes actual.
        var highlightTasks = tasks;
        if (!request.From.HasValue && !request.To.HasValue)
        {
            var now = DateTime.UtcNow;
            var monthStart = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);
            var monthEnd = monthStart.AddMonths(1);
            highlightTasks = tasks.Where(t =>
            {
                var periodo = t.DueDate ?? t.CreatedAt;
                return periodo >= monthStart && periodo < monthEnd;
            }).ToList();
        }

        var dashboard = new DashboardDto
        {
            CollaboratorHeatmap = CalculateCollaboratorHeatmap(tasks),
            CollaboratorHeatmapActive = CalculateCollaboratorHeatmapActive(allTasks),
            AvgTimeByStatus = CalculateAvgTimeByStatus(tasks),
            TasksByCollaboratorAndStatus = CalculateTasksByCollaboratorAndStatus(tasks),
            HistoricReassignedByCollaborator = CalculateHistoricReassigned(tasks),
            LateTasksByCollaborator = CalculateLateTasks(tasks),
            TasksByStatus = CalculateTasksByStatus(tasks),
            Highlights = CalculateHighlights(highlightTasks),
            CompletionTimeline = CalculateCompletionTimeline(tasks),
            AvgRatingByCollaborator = CalculateAvgRatingByCollaborator(tasks, bscEmailSet, bscPattern),
            BscAvgRatingByCollaborator = CalculateBscAvgRating(tasks, bscEmailSet, bscPattern)
        };

        return ApiResponse<DashboardDto>.Ok(dashboard);
    }

    /// <summary>
    /// Mapa de calor: colaboradores y suma de tiempo estimado de tareas asignadas.
    /// </summary>
    private static List<CollaboratorHeatmapItem> CalculateCollaboratorHeatmap(List<TaskItem> tasks)
    {
        return tasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedToName)
                && t.Status != TaskStatuses.Cancelada)
            .GroupBy(t => t.AssignedToName!)
            .Select(g => new CollaboratorHeatmapItem
            {
                Name = g.Key,
                TaskCount = g.Count(),
                EstimatedTimeSum = g.Sum(t => t.EstimatedTime)
            })
            .OrderByDescending(x => x.EstimatedTimeSum)
            .ToList();
    }

    /// <summary>
    /// Mapa de calor de tareas activas: excluye Completa y Cancelada.
    /// Suma el tiempo estimado de las tareas activas.
    /// </summary>
    private static List<CollaboratorHeatmapItem> CalculateCollaboratorHeatmapActive(List<TaskItem> tasks)
    {
        return tasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedToName)
                && t.Status != TaskStatuses.Completa
                && t.Status != TaskStatuses.Cancelada)
            .GroupBy(t => t.AssignedToName!)
            .Select(g => new CollaboratorHeatmapItem
            {
                Name = g.Key,
                TaskCount = g.Count(),
                EstimatedTimeSum = g.Sum(t => t.EstimatedTime)
            })
            .OrderByDescending(x => x.EstimatedTimeSum)
            .ToList();
    }

    /// <summary>
    /// Tiempo promedio (horas) que las tareas pasan en cada estado.
    /// Calcula usando el statusHistory: el tiempo en un estado es la diferencia entre
    /// el changedAt de una transición y la siguiente.
    /// </summary>
    private static List<StatusAvgTimeItem> CalculateAvgTimeByStatus(List<TaskItem> tasks)
    {
        // Estados terminales: el tiempo "en" estos estados crece indefinidamente y no aporta
        // información analítica del flujo. Se excluyen del promedio.
        var excludedStatuses = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            TaskStatuses.Completa,
        };

        var statusDurations = new Dictionary<string, List<double>>();

        foreach (var task in tasks)
        {
            var history = task.StatusHistory?.OrderBy(h => h.ChangedAt).ToList();
            if (history == null || history.Count == 0)
                continue;

            for (int i = 0; i < history.Count; i++)
            {
                var currentStatus = history[i].ToStatus;
                if (excludedStatuses.Contains(currentStatus))
                    continue;

                DateTime start = history[i].ChangedAt;
                DateTime end;

                if (i + 1 < history.Count)
                {
                    end = history[i + 1].ChangedAt;
                }
                else
                {
                    // Ultimo estado: el tiempo transcurrido hasta ahora
                    end = DateTime.UtcNow;
                }

                var hours = (end - start).TotalHours;

                if (!statusDurations.ContainsKey(currentStatus))
                    statusDurations[currentStatus] = new List<double>();

                statusDurations[currentStatus].Add(hours);
            }
        }

        return statusDurations
            .Select(kvp => new StatusAvgTimeItem
            {
                Status = kvp.Key,
                AvgHours = Math.Round(kvp.Value.Average(), 2)
            })
            .OrderBy(x => x.Status)
            .ToList();
    }

    /// <summary>
    /// Tareas por colaborador desglosadas por estado.
    /// </summary>
    private static List<CollaboratorStatusBreakdown> CalculateTasksByCollaboratorAndStatus(List<TaskItem> tasks)
    {
        return tasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedToName))
            .GroupBy(t => t.AssignedToName!)
            .Select(g => new CollaboratorStatusBreakdown
            {
                Name = g.Key,
                StatusCounts = g.GroupBy(t => t.Status)
                    .ToDictionary(sg => sg.Key, sg => sg.Count())
            })
            .OrderBy(x => x.Name)
            .ToList();
    }

    /// <summary>
    /// Calcula la cantidad historica de reasignaciones por colaborador.
    /// Cuenta las transiciones a "Reasignada" en el historial de cada tarea.
    /// </summary>
    private static List<CollaboratorReassignedCount> CalculateHistoricReassigned(List<TaskItem> tasks)
    {
        var counts = new Dictionary<string, int>();

        foreach (var task in tasks)
        {
            if (string.IsNullOrEmpty(task.AssignedToName) || task.StatusHistory == null)
                continue;

            var reassignCount = task.StatusHistory
                .Count(h => h.ToStatus == TaskStatuses.Reasignada);

            if (reassignCount > 0)
            {
                if (!counts.ContainsKey(task.AssignedToName))
                    counts[task.AssignedToName] = 0;
                counts[task.AssignedToName] += reassignCount;
            }
        }

        return counts
            .Select(kvp => new CollaboratorReassignedCount
            {
                Name = kvp.Key,
                Count = kvp.Value
            })
            .OrderByDescending(x => x.Count)
            .ToList();
    }

    /// <summary>
    /// Calcula la cantidad de tareas entregadas tarde por colaborador.
    /// Una tarea es tardia si fue enviada a validacion despues de la fecha de entrega.
    /// </summary>
    private static List<CollaboratorReassignedCount> CalculateLateTasks(List<TaskItem> tasks)
    {
        var counts = new Dictionary<string, int>();

        foreach (var task in tasks)
        {
            if (string.IsNullOrEmpty(task.AssignedToName) || task.StatusHistory == null || !task.DueDate.HasValue)
                continue;

            var sentLate = task.StatusHistory
                .Any(h => h.ToStatus == TaskStatuses.CompletaPorValidar && h.ChangedAt > task.DueDate.Value);

            if (sentLate)
            {
                if (!counts.ContainsKey(task.AssignedToName))
                    counts[task.AssignedToName] = 0;
                counts[task.AssignedToName]++;
            }
        }

        return counts
            .Select(kvp => new CollaboratorReassignedCount
            {
                Name = kvp.Key,
                Count = kvp.Value
            })
            .OrderByDescending(x => x.Count)
            .ToList();
    }

    /// <summary>
    /// Total de tareas por estado.
    /// </summary>
    private static List<StatusCountItem> CalculateTasksByStatus(List<TaskItem> tasks)
    {
        return tasks
            .GroupBy(t => t.Status)
            .Select(g => new StatusCountItem
            {
                Status = g.Key,
                Count = g.Count()
            })
            .OrderByDescending(x => x.Count)
            .ToList();
    }

    /// <summary>
    /// Numero de tareas "de referencia" del promedio bayesiano: mientras mas
    /// tareas tiene una persona, menos pesa este valor (su propio promedio
    /// domina); con pocas tareas, el score se acerca al promedio general del
    /// grupo. Validado contra volumen real de produccion (mediana ~40
    /// tareas/mes por colaborador, ~31 por lider) — ver CONTEXTO.md.
    /// </summary>
    private const int EfficiencyScoreK = 10;

    /// <summary>
    /// Calcula etiquetas destacadas usando un promedio bayesiano (score = (promedio*n +
    /// promedioGlobal*K) / (n+K)) sobre el Rating de tareas completadas y calificadas:
    /// - Colaborador más eficiente: mejor score entre quienes tienen tareas asignadas (AssignedToName)
    /// - Líder top: mejor score entre quienes gestionan tareas (AssignedLeaderName)
    /// Evita que 1-2 tareas con calificacion perfecta le ganen a alguien con un
    /// promedio sostenido sobre muchas tareas.
    /// </summary>
    private static HighlightLabels CalculateHighlights(List<TaskItem> tasks)
    {
        var highlights = new HighlightLabels();

        var ratedCompletedTasks = tasks
            .Where(t => t.Status == TaskStatuses.Completa && t.Rating.HasValue)
            .ToList();

        var collaboratorGroups = ratedCompletedTasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedToName))
            .GroupBy(t => t.AssignedToName!)
            .Select(g => new
            {
                Name = g.Key,
                Count = g.Count(),
                AvgRating = g.Average(t => t.Rating!.Value),
                EstimatedTimeSum = g.Sum(t => t.EstimatedTime)
            })
            .ToList();

        if (collaboratorGroups.Count > 0)
        {
            var globalAvg = collaboratorGroups.Average(x => x.AvgRating);
            var fastestCollaborator = collaboratorGroups
                .Select(x => new
                {
                    x.Name,
                    x.Count,
                    x.AvgRating,
                    x.EstimatedTimeSum,
                    Score = (x.AvgRating * x.Count + globalAvg * EfficiencyScoreK) / (x.Count + EfficiencyScoreK)
                })
                .OrderByDescending(x => x.Score)
                .First();

            highlights.FastestCollaboratorName = fastestCollaborator.Name;
            highlights.FastestCollaboratorCompletedCount = fastestCollaborator.Count;
            highlights.FastestCollaboratorEstimatedTimeSum = fastestCollaborator.EstimatedTimeSum;
            highlights.FastestCollaboratorAvgRating = Math.Round(fastestCollaborator.AvgRating, 1);
            highlights.FastestCollaboratorScore = Math.Round(fastestCollaborator.Score, 1);
        }

        var leaderGroups = ratedCompletedTasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedLeaderName))
            .GroupBy(t => t.AssignedLeaderName!)
            .Select(g => new
            {
                Name = g.Key,
                Count = g.Count(),
                AvgRating = g.Average(t => t.Rating!.Value),
                EstimatedTimeSum = g.Sum(t => t.EstimatedTime)
            })
            .ToList();

        if (leaderGroups.Count > 0)
        {
            var globalAvg = leaderGroups.Average(x => x.AvgRating);
            var topLeader = leaderGroups
                .Select(x => new
                {
                    x.Name,
                    x.Count,
                    x.AvgRating,
                    x.EstimatedTimeSum,
                    Score = (x.AvgRating * x.Count + globalAvg * EfficiencyScoreK) / (x.Count + EfficiencyScoreK)
                })
                .OrderByDescending(x => x.Score)
                .First();

            highlights.TopLeaderName = topLeader.Name;
            highlights.TopLeaderCompletedCount = topLeader.Count;
            highlights.TopLeaderEstimatedTimeSum = topLeader.EstimatedTimeSum;
            highlights.TopLeaderAvgRating = Math.Round(topLeader.AvgRating, 1);
            highlights.TopLeaderScore = Math.Round(topLeader.Score, 1);
        }

        return highlights;
    }

    /// <summary>
    /// Calcula el timeline de tareas completadas por colaborador.
    /// Para cada colaborador, encuentra la fecha en que cada tarea llegó a "Completa"
    /// y construye una serie acumulativa ordenada por fecha.
    /// </summary>
    private static List<CollaboratorCompletionTimeline> CalculateCompletionTimeline(List<TaskItem> tasks)
    {
        // Se agrupa por TODOS los colaboradores con tareas en el rango (no solo
        // quienes ya tienen alguna "Completa"), para que el selector del dashboard
        // pueda ofrecer a cualquiera — el que no completó nada simplemente queda
        // con una línea vacía/plana en el gráfico.
        return tasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedToName))
            .GroupBy(t => t.AssignedToName!)
            .Select(g =>
            {
                // Para cada tarea COMPLETADA de este colaborador, buscar la fecha
                // del último cambio a "Completa" (las no completadas no aportan
                // puntos a la serie, pero el colaborador igual aparece en la lista).
                var completionDates = g
                    .Where(t => t.Status == TaskStatuses.Completa)
                    .Select(t =>
                    {
                        var completeEntry = t.StatusHistory?
                            .Where(h => h.ToStatus == TaskStatuses.Completa)
                            .OrderByDescending(h => h.ChangedAt)
                            .FirstOrDefault();
                        return completeEntry?.ChangedAt ?? t.UpdatedAt;
                    })
                    .OrderBy(d => d)
                    .ToList();

                // Agrupar por fecha: solo conservar el conteo acumulado maximo de cada dia
                var dataPoints = new List<TimelineDataPoint>();
                for (int i = 0; i < completionDates.Count; i++)
                {
                    var dateStr = completionDates[i].ToString("yyyy-MM-dd");
                    var cumulative = i + 1;

                    // Si ya existe un punto para esta fecha, actualizar el conteo
                    if (dataPoints.Count > 0 && dataPoints[^1].Date == dateStr)
                    {
                        dataPoints[^1].CumulativeCount = cumulative;
                    }
                    else
                    {
                        dataPoints.Add(new TimelineDataPoint
                        {
                            Date = dateStr,
                            CumulativeCount = cumulative
                        });
                    }
                }

                return new CollaboratorCompletionTimeline
                {
                    Name = g.Key,
                    DataPoints = dataPoints
                };
            })
            .OrderBy(x => x.Name)
            .ToList();
    }

    /// <summary>
    /// Promedio de calificacion por colaborador.
    /// Solo considera tareas que tienen calificacion (rating != null).
    /// Para colaboradores BSC, excluye las tareas que coincidan con el patron BSC.
    /// </summary>
    private static List<CollaboratorAvgRating> CalculateAvgRatingByCollaborator(
        List<TaskItem> tasks, HashSet<string> bscEmails, string bscPattern)
    {
        var ratedTasks = tasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedToName) && t.Rating.HasValue)
            .ToList();

        // Excluir tareas BSC para colaboradores BSC en el calculo de promedio general
        if (bscEmails.Count > 0 && !string.IsNullOrEmpty(bscPattern))
        {
            ratedTasks = ratedTasks.Where(t =>
            {
                if (!string.IsNullOrEmpty(t.AssignedToEmail) && bscEmails.Contains(t.AssignedToEmail))
                    return t.Title.IndexOf(bscPattern, StringComparison.OrdinalIgnoreCase) < 0;
                return true;
            }).ToList();
        }

        return ratedTasks
            .GroupBy(t => t.AssignedToName!)
            .Select(g => new CollaboratorAvgRating
            {
                Name = g.Key,
                AvgRating = Math.Round(g.Average(t => t.Rating!.Value), 1),
                TaskCount = g.Count()
            })
            .OrderByDescending(x => x.AvgRating)
            .ToList();
    }

    /// <summary>
    /// Calcula el promedio de calificacion solo de tareas BSC para colaboradores configurados.
    /// </summary>
    private static List<CollaboratorAvgRating> CalculateBscAvgRating(
        List<TaskItem> tasks, HashSet<string> bscEmails, string bscPattern)
    {
        if (bscEmails.Count == 0 || string.IsNullOrEmpty(bscPattern))
            return new List<CollaboratorAvgRating>();

        var bscRatedTasks = tasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedToName)
                && t.Rating.HasValue
                && !string.IsNullOrEmpty(t.AssignedToEmail)
                && bscEmails.Contains(t.AssignedToEmail)
                && t.Title.IndexOf(bscPattern, StringComparison.OrdinalIgnoreCase) >= 0)
            .ToList();

        return bscRatedTasks
            .GroupBy(t => t.AssignedToName!)
            .Select(g => new CollaboratorAvgRating
            {
                Name = g.Key,
                AvgRating = Math.Round(g.Average(t => t.Rating!.Value), 1),
                TaskCount = g.Count()
            })
            .OrderByDescending(x => x.AvgRating)
            .ToList();
    }
}
