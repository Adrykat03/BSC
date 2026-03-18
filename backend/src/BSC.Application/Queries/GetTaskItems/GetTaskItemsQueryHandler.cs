using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Queries.GetTaskItems;

/// <summary>
/// Handler para la query de listado de tareas con filtrado por rol.
/// </summary>
public class GetTaskItemsQueryHandler : IRequestHandler<GetTaskItemsQuery, ApiResponse<PaginatedResult<TaskItemDto>>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly ILogger<GetTaskItemsQueryHandler> _logger;

    public GetTaskItemsQueryHandler(ITaskItemRepository taskItemRepository, ILogger<GetTaskItemsQueryHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<PaginatedResult<TaskItemDto>>> Handle(GetTaskItemsQuery request, CancellationToken cancellationToken)
    {
        var pageSize = Math.Min(request.PageSize, 100);
        var page = Math.Max(request.Page, 1);

        List<TaskItem> taskItems;
        int totalCount;

        if (!string.IsNullOrEmpty(request.UserEmail) && !string.IsNullOrEmpty(request.UserRole))
        {
            switch (request.UserRole)
            {
                case TaskStateTransitions.RolGerente:
                    // Gerente ve todas las tareas
                    taskItems = await _taskItemRepository.GetAllAsync(page, pageSize, request.Search);
                    totalCount = await _taskItemRepository.GetTotalCountAsync(request.Search);
                    break;

                case TaskStateTransitions.RolLider:
                    // Lider ve tareas donde es el lider asignado y status != Completa
                    taskItems = await _taskItemRepository.GetByLeaderEmailAsync(request.UserEmail, page, pageSize, request.Search);
                    totalCount = await _taskItemRepository.GetCountByLeaderEmailAsync(request.UserEmail, request.Search);
                    break;

                case TaskStateTransitions.RolColaborador:
                    // Colaborador ve todas sus tareas asignadas (cualquier estado activo)
                    var allowedStatuses = new List<string>
                    {
                        TaskStatuses.Asignada,
                        TaskStatuses.CompletaPorValidar,
                        TaskStatuses.Reasignada,
                        TaskStatuses.CompletaValidada,
                        TaskStatuses.Completa
                    };
                    taskItems = await _taskItemRepository.GetByAssignedEmailAsync(request.UserEmail, allowedStatuses, page, pageSize, request.Search);
                    totalCount = await _taskItemRepository.GetCountByAssignedEmailAsync(request.UserEmail, allowedStatuses, request.Search);
                    break;

                default:
                    // Rol desconocido, retornar vacio
                    taskItems = new List<TaskItem>();
                    totalCount = 0;
                    break;
            }
        }
        else
        {
            // Sin filtro de rol, retornar todas (comportamiento por defecto)
            taskItems = await _taskItemRepository.GetAllAsync(page, pageSize, request.Search);
            totalCount = await _taskItemRepository.GetTotalCountAsync(request.Search);
        }

        var dtos = taskItems.Select(TaskItemMapper.ToDto).ToList();

        var result = new PaginatedResult<TaskItemDto>
        {
            Items = dtos,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };

        return ApiResponse<PaginatedResult<TaskItemDto>>.Ok(result);
    }
}
