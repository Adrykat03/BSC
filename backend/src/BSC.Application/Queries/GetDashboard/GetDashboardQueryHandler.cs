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
    private readonly ILogger<GetDashboardQueryHandler> _logger;

    public GetDashboardQueryHandler(ITaskItemRepository taskItemRepository, ILogger<GetDashboardQueryHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
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

        var dashboard = new DashboardDto
        {
            CollaboratorHeatmap = CalculateCollaboratorHeatmap(tasks),
            CollaboratorHeatmapActive = CalculateCollaboratorHeatmapActive(allTasks),
            AvgTimeByStatus = CalculateAvgTimeByStatus(tasks),
            TasksByCollaboratorAndStatus = CalculateTasksByCollaboratorAndStatus(tasks),
            TasksByStatus = CalculateTasksByStatus(tasks),
            Highlights = CalculateHighlights(tasks),
            CompletionTimeline = CalculateCompletionTimeline(tasks)
        };

        return ApiResponse<DashboardDto>.Ok(dashboard);
    }

    /// <summary>
    /// Mapa de calor: colaboradores y cantidad de tareas asignadas.
    /// </summary>
    private static List<CollaboratorHeatmapItem> CalculateCollaboratorHeatmap(List<TaskItem> tasks)
    {
        return tasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedToName))
            .GroupBy(t => t.AssignedToName!)
            .Select(g => new CollaboratorHeatmapItem
            {
                Name = g.Key,
                TaskCount = g.Count()
            })
            .OrderByDescending(x => x.TaskCount)
            .ToList();
    }

    /// <summary>
    /// Mapa de calor de tareas activas: excluye Completa y Cancelada.
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
                TaskCount = g.Count()
            })
            .OrderByDescending(x => x.TaskCount)
            .ToList();
    }

    /// <summary>
    /// Tiempo promedio (horas) que las tareas pasan en cada estado.
    /// Calcula usando el statusHistory: el tiempo en un estado es la diferencia entre
    /// el changedAt de una transición y la siguiente.
    /// </summary>
    private static List<StatusAvgTimeItem> CalculateAvgTimeByStatus(List<TaskItem> tasks)
    {
        var statusDurations = new Dictionary<string, List<double>>();

        foreach (var task in tasks)
        {
            var history = task.StatusHistory?.OrderBy(h => h.ChangedAt).ToList();
            if (history == null || history.Count == 0)
                continue;

            for (int i = 0; i < history.Count; i++)
            {
                var currentStatus = history[i].ToStatus;
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
    /// Calcula etiquetas destacadas:
    /// - Colaborador más rápido: menor tiempo promedio (actualTime) en tareas "Completa"
    /// - Líder top: mayor cantidad de tareas "Completa" gestionadas
    /// </summary>
    private static HighlightLabels CalculateHighlights(List<TaskItem> tasks)
    {
        var highlights = new HighlightLabels();

        // Colaborador más rápido: tareas en estado "Completa" con ActualTime,
        // agrupadas por assignedToName, menor promedio de ActualTime
        var completedTasks = tasks.Where(t => t.Status == TaskStatuses.Completa).ToList();

        var fastestCollaborator = completedTasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedToName) && t.ActualTime.HasValue && t.ActualTime.Value > 0)
            .GroupBy(t => t.AssignedToName!)
            .Select(g => new
            {
                Name = g.Key,
                AvgHours = (double)g.Average(t => t.ActualTime!.Value)
            })
            .OrderBy(x => x.AvgHours)
            .FirstOrDefault();

        if (fastestCollaborator != null)
        {
            highlights.FastestCollaboratorName = fastestCollaborator.Name;
            highlights.FastestCollaboratorAvgHours = Math.Round(fastestCollaborator.AvgHours, 2);
        }

        // Líder con más tareas completas
        var topLeader = completedTasks
            .Where(t => !string.IsNullOrEmpty(t.AssignedLeaderName))
            .GroupBy(t => t.AssignedLeaderName!)
            .Select(g => new
            {
                Name = g.Key,
                Count = g.Count()
            })
            .OrderByDescending(x => x.Count)
            .FirstOrDefault();

        if (topLeader != null)
        {
            highlights.TopLeaderName = topLeader.Name;
            highlights.TopLeaderCompletedCount = topLeader.Count;
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
        var completedTasks = tasks
            .Where(t => t.Status == TaskStatuses.Completa && !string.IsNullOrEmpty(t.AssignedToName))
            .ToList();

        return completedTasks
            .GroupBy(t => t.AssignedToName!)
            .Select(g =>
            {
                // Para cada tarea, buscar la fecha del último cambio a "Completa"
                var completionDates = g
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

                var dataPoints = new List<TimelineDataPoint>();
                for (int i = 0; i < completionDates.Count; i++)
                {
                    dataPoints.Add(new TimelineDataPoint
                    {
                        Date = completionDates[i].ToString("yyyy-MM-dd"),
                        CumulativeCount = i + 1
                    });
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
}
