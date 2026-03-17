using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Constants;
using BSC.Domain.Interfaces;
using BSC.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.AssignTask;

/// <summary>
/// Handler para el comando de asignacion de tarea.
/// - Gerente asigna a Lider (AssignedLeader) o a Colaborador si ya tiene Lider.
/// - Lider asigna a Colaborador (AssignedTo).
/// </summary>
public class AssignTaskCommandHandler : IRequestHandler<AssignTaskCommand, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly IColaboradorRepository _colaboradorRepository;
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<AssignTaskCommandHandler> _logger;

    public AssignTaskCommandHandler(
        ITaskItemRepository taskItemRepository,
        IColaboradorRepository colaboradorRepository,
        IRoleRepository roleRepository,
        ILogger<AssignTaskCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _colaboradorRepository = colaboradorRepository;
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(AssignTaskCommand request, CancellationToken cancellationToken)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(request.TaskId);
        if (taskItem == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{request.TaskId}'." }
            );
        }

        // Buscar el colaborador a asignar
        var assignee = await _colaboradorRepository.GetByIdAsync(request.AssigneeId);
        if (assignee == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Colaborador no encontrado.",
                new List<string> { $"No se encontro un colaborador con el ID '{request.AssigneeId}'." }
            );
        }

        // Obtener los roles del colaborador a asignar
        var assigneeRoleNames = new List<string>();
        foreach (var rolId in assignee.RolIds)
        {
            var role = await _roleRepository.GetByIdAsync(rolId);
            if (role != null)
            {
                assigneeRoleNames.Add(role.Name);
            }
        }

        // Buscar datos del asignador
        var assigner = await _colaboradorRepository.GetByCorreoAsync(request.AssignerEmail);
        var assignerName = assigner?.NombreCompleto ?? request.AssignerEmail;
        var assignerId = assigner?.Id ?? string.Empty;

        var previousStatus = taskItem.Status;
        var statusChanged = false;

        if (request.AssignerRole == TaskStateTransitions.RolGerente)
        {
            // El gerente puede asignar a un Lider si la tarea no tiene lider aun
            if (string.IsNullOrEmpty(taskItem.AssignedLeaderId))
            {
                // Debe asignar a un Lider
                if (!assigneeRoleNames.Any(n => n.Equals("Lider", StringComparison.OrdinalIgnoreCase)))
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "Asignacion no valida.",
                        new List<string> { "El Gerente debe asignar primero a un colaborador con rol 'Lider'." }
                    );
                }

                taskItem.AssignedLeaderId = assignee.Id;
                taskItem.AssignedLeaderName = assignee.NombreCompleto;
                taskItem.AssignedLeaderEmail = assignee.Correo;

                // Cambiar estado a Asignada si estaba en Creada
                if (taskItem.Status == TaskStatuses.Creada)
                {
                    taskItem.Status = TaskStatuses.Asignada;
                    statusChanged = true;
                }
            }
            else
            {
                // Ya tiene lider, el gerente puede asignar a un Colaborador directamente
                taskItem.AssignedToId = assignee.Id;
                taskItem.AssignedToName = assignee.NombreCompleto;
                taskItem.AssignedToEmail = assignee.Correo;
            }
        }
        else if (request.AssignerRole == TaskStateTransitions.RolLider)
        {
            // El lider asigna a cualquier Colaborador
            taskItem.AssignedToId = assignee.Id;
            taskItem.AssignedToName = assignee.NombreCompleto;
            taskItem.AssignedToEmail = assignee.Correo;
        }
        else
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Rol no autorizado para asignar tareas.",
                new List<string> { "Solo Gerente y Lider pueden asignar tareas." }
            );
        }

        // Siempre agregar al historial — registra cada asignacion
        taskItem.StatusHistory.Add(new StatusChange
        {
            FromStatus = previousStatus,
            ToStatus = taskItem.Status,
            ChangedById = assignerId,
            ChangedByName = assignerName,
            ChangedByEmail = request.AssignerEmail,
            ChangedAt = DateTime.UtcNow,
            Comment = statusChanged
                ? $"Tarea asignada a {assignee.NombreCompleto}"
                : $"Reasignada a {assignee.NombreCompleto}"
        });

        taskItem.UpdatedAt = DateTime.UtcNow;
        taskItem.UpdatedBy = request.AssignerEmail;

        await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation(
            "Tarea {TaskId} asignada a {AssigneeName} ({AssigneeId}) por {AssignerEmail} ({AssignerRole})",
            taskItem.Id, assignee.NombreCompleto, assignee.Id, request.AssignerEmail, request.AssignerRole);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(taskItem), "Tarea asignada exitosamente.");
    }
}
