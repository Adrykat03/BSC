using BSC.Application.DTOs;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.CreateTaskItemsBulk;

/// <summary>
/// Handler para la creacion masiva de tareas.
/// Procesa cada tarea individualmente: si una falla, las demas continuan.
/// </summary>
public class CreateTaskItemsBulkCommandHandler : IRequestHandler<CreateTaskItemsBulkCommand, ApiResponse<BulkCreateResultDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly IColaboradorRepository _colaboradorRepository;
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<CreateTaskItemsBulkCommandHandler> _logger;

    public CreateTaskItemsBulkCommandHandler(
        ITaskItemRepository taskItemRepository,
        IColaboradorRepository colaboradorRepository,
        IRoleRepository roleRepository,
        ILogger<CreateTaskItemsBulkCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _colaboradorRepository = colaboradorRepository;
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<BulkCreateResultDto>> Handle(CreateTaskItemsBulkCommand request, CancellationToken cancellationToken)
    {
        // H-01: Validar que solo Gerente o Lider puedan crear tareas
        if (request.CreatedByRole != TaskStateTransitions.RolGerente
            && request.CreatedByRole != TaskStateTransitions.RolLider)
        {
            return ApiResponse<BulkCreateResultDto>.Fail(
                "No tiene permisos para crear tareas de forma masiva.",
                new List<string> { "Solo Gerente y Lider pueden usar la carga masiva." }
            );
        }

        // Validar cantidad de tareas
        if (request.Tasks == null || request.Tasks.Count == 0)
        {
            return ApiResponse<BulkCreateResultDto>.Fail(
                "Debe enviar al menos una tarea.",
                new List<string> { "El array de tareas esta vacio." }
            );
        }

        if (request.Tasks.Count > 100)
        {
            return ApiResponse<BulkCreateResultDto>.Fail(
                "Se excedio el limite maximo de tareas por carga.",
                new List<string> { "El maximo permitido es 100 tareas por carga masiva." }
            );
        }

        // Pre-cargar roles para evitar consultas repetidas
        var rolLider = await _roleRepository.GetByNameAsync(TaskStateTransitions.RolLider);
        var rolColaborador = await _roleRepository.GetByNameAsync(TaskStateTransitions.RolColaborador);

        var resultDto = new BulkCreateResultDto
        {
            TotalReceived = request.Tasks.Count
        };

        for (int i = 0; i < request.Tasks.Count; i++)
        {
            var taskData = request.Tasks[i];
            var rowNumber = i + 1;
            var resultItem = new BulkTaskResultItem
            {
                Row = rowNumber,
                Title = System.Net.WebUtility.HtmlEncode(taskData.Title.Trim())
            };

            try
            {
                // Validar campos obligatorios
                if (string.IsNullOrWhiteSpace(taskData.Title))
                {
                    resultItem.Success = false;
                    resultItem.Error = "El titulo es obligatorio.";
                    resultDto.Results.Add(resultItem);
                    resultDto.TotalFailed++;
                    continue;
                }

                if (string.IsNullOrWhiteSpace(taskData.Description))
                {
                    resultItem.Success = false;
                    resultItem.Error = "La descripcion es obligatoria.";
                    resultDto.Results.Add(resultItem);
                    resultDto.TotalFailed++;
                    continue;
                }

                var taskItem = new TaskItem
                {
                    Title = taskData.Title.Trim(),
                    Description = taskData.Description.Trim(),
                    Status = TaskStatuses.Creada,
                    DueDate = taskData.DueDate,
                    EstimatedTime = taskData.EstimatedTime ?? 0m,
                    Insumos = taskData.Insumos,
                    Observations = taskData.Observations,
                    CreatedAt = DateTime.UtcNow,
                    CreatedBy = request.CreatedByEmail,
                    UpdatedAt = DateTime.UtcNow,
                    UpdatedBy = request.CreatedByEmail
                };

                // Asignar lider si se proporciona email
                if (!string.IsNullOrWhiteSpace(taskData.LeaderEmail))
                {
                    var lider = await _colaboradorRepository.GetByCorreoAsync(taskData.LeaderEmail.Trim());
                    if (lider == null)
                    {
                        resultItem.Success = false;
                        resultItem.Error = $"No se encontro un lider con el correo '{System.Net.WebUtility.HtmlEncode(taskData.LeaderEmail)}'.";
                        resultDto.Results.Add(resultItem);
                        resultDto.TotalFailed++;
                        continue;
                    }

                    if (rolLider == null || !lider.RolIds.Contains(rolLider.Id))
                    {
                        resultItem.Success = false;
                        resultItem.Error = $"El usuario '{System.Net.WebUtility.HtmlEncode(taskData.LeaderEmail)}' no tiene rol de Lider.";
                        resultDto.Results.Add(resultItem);
                        resultDto.TotalFailed++;
                        continue;
                    }

                    taskItem.AssignedLeaderId = lider.Id;
                    taskItem.AssignedLeaderName = lider.NombreCompleto;
                    taskItem.AssignedLeaderEmail = lider.Correo;
                }

                // Asignar colaborador si se proporciona email
                if (!string.IsNullOrWhiteSpace(taskData.CollaboratorEmail))
                {
                    var colaborador = await _colaboradorRepository.GetByCorreoAsync(taskData.CollaboratorEmail.Trim());
                    if (colaborador == null)
                    {
                        resultItem.Success = false;
                        resultItem.Error = $"No se encontro un colaborador con el correo '{System.Net.WebUtility.HtmlEncode(taskData.CollaboratorEmail)}'.";
                        resultDto.Results.Add(resultItem);
                        resultDto.TotalFailed++;
                        continue;
                    }

                    if (rolColaborador == null || !colaborador.RolIds.Contains(rolColaborador.Id))
                    {
                        resultItem.Success = false;
                        resultItem.Error = $"El usuario '{System.Net.WebUtility.HtmlEncode(taskData.CollaboratorEmail)}' no tiene rol de Colaborador.";
                        resultDto.Results.Add(resultItem);
                        resultDto.TotalFailed++;
                        continue;
                    }

                    taskItem.AssignedToId = colaborador.Id;
                    taskItem.AssignedToName = colaborador.NombreCompleto;
                    taskItem.AssignedToEmail = colaborador.Correo;
                }

                // Determinar estado segun asignaciones
                if (!string.IsNullOrEmpty(taskItem.AssignedLeaderId) || !string.IsNullOrEmpty(taskItem.AssignedToId))
                {
                    taskItem.Status = TaskStatuses.Asignada;
                }

                var created = await _taskItemRepository.CreateAsync(taskItem);

                resultItem.Success = true;
                resultItem.TaskId = created.Id;
                resultDto.TotalCreated++;

                _logger.LogInformation(
                    "Tarea masiva creada: fila {Row}, titulo '{Title}', id {TaskId}",
                    rowNumber, taskData.Title, created.Id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Error al crear tarea masiva: fila {Row}, titulo '{Title}'",
                    rowNumber, taskData.Title);

                resultItem.Success = false;
                resultItem.Error = "Error interno al procesar esta tarea.";
                resultDto.TotalFailed++;
            }

            resultDto.Results.Add(resultItem);
        }

        var message = resultDto.TotalFailed == 0
            ? $"Carga masiva completada exitosamente. {resultDto.TotalCreated} tarea(s) creada(s)."
            : $"Carga masiva completada con errores. {resultDto.TotalCreated} creada(s), {resultDto.TotalFailed} fallida(s).";

        _logger.LogInformation(
            "Carga masiva finalizada: {TotalReceived} recibidas, {TotalCreated} creadas, {TotalFailed} fallidas",
            resultDto.TotalReceived, resultDto.TotalCreated, resultDto.TotalFailed);

        return ApiResponse<BulkCreateResultDto>.Ok(resultDto, message);
    }
}
