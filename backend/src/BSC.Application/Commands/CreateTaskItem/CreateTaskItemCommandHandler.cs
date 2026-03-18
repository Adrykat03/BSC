using BSC.Application.Common;
using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using BSC.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.CreateTaskItem;

/// <summary>
/// Handler para el comando de creacion de tarea.
/// </summary>
public class CreateTaskItemCommandHandler : IRequestHandler<CreateTaskItemCommand, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly IColaboradorRepository _colaboradorRepository;
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<CreateTaskItemCommandHandler> _logger;

    private const long MaxFileSize = 20 * 1024 * 1024; // 20MB
    private const string FilesBasePath = "/app/files";
    private const string InsumosRelativeDir = "insumos";

    public CreateTaskItemCommandHandler(
        ITaskItemRepository taskItemRepository,
        IColaboradorRepository colaboradorRepository,
        IRoleRepository roleRepository,
        ILogger<CreateTaskItemCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _colaboradorRepository = colaboradorRepository;
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(CreateTaskItemCommand request, CancellationToken cancellationToken)
    {
        // H-01: Validar que solo Gerente o Lider puedan crear tareas
        if (request.CreatedByRole != TaskStateTransitions.RolGerente
            && request.CreatedByRole != TaskStateTransitions.RolLider)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "No tiene permisos para crear tareas.",
                new List<string> { "Solo Gerente y Lider pueden crear tareas." }
            );
        }

        var taskItem = new TaskItem
        {
            Title = request.Title,
            Description = request.Description,
            Status = TaskStatuses.Creada,
            DueDate = request.DueDate,
            EstimatedTime = request.EstimatedTime,
            Insumos = request.Insumos,
            Observations = request.Observations,
            CreatedAt = DateTime.UtcNow,
            CreatedBy = request.CreatedByEmail,
            UpdatedAt = DateTime.UtcNow,
            UpdatedBy = request.CreatedByEmail
        };

        // Si el creador es Lider, auto-asignarse como lider de la tarea
        if (request.CreatedByRole == TaskStateTransitions.RolLider)
        {
            // Buscar datos del lider creador por email
            var lider = await _colaboradorRepository.GetByCorreoAsync(request.CreatedByEmail);
            if (lider != null)
            {
                taskItem.AssignedLeaderId = lider.Id;
                taskItem.AssignedLeaderName = lider.NombreCompleto;
                taskItem.AssignedLeaderEmail = lider.Correo;
            }
            else
            {
                // Fallback con datos del JWT
                taskItem.AssignedLeaderId = request.CreatedById;
                taskItem.AssignedLeaderName = request.CreatedByName;
                taskItem.AssignedLeaderEmail = request.CreatedByEmail;
            }

            // Si el lider asigna un colaborador al crear
            if (!string.IsNullOrEmpty(request.AssigneeId))
            {
                var assignee = await _colaboradorRepository.GetByIdAsync(request.AssigneeId);
                if (assignee == null)
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "Colaborador no encontrado.",
                        new List<string> { $"No se encontro un colaborador con el ID '{request.AssigneeId}'." }
                    );
                }

                // H-03: Validar que el assignee tenga rol Colaborador
                var rolColaborador = await _roleRepository.GetByNameAsync(TaskStateTransitions.RolColaborador);
                if (rolColaborador == null || !assignee.RolIds.Contains(rolColaborador.Id))
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "El usuario asignado no tiene rol de Colaborador.",
                        new List<string> { "Solo se pueden asignar tareas a usuarios con rol Colaborador." }
                    );
                }

                taskItem.AssignedToId = assignee.Id;
                taskItem.AssignedToName = assignee.NombreCompleto;
                taskItem.AssignedToEmail = assignee.Correo;
                taskItem.Status = TaskStatuses.Asignada;
            }
        }

        // Validar archivos de insumo antes de crear la tarea
        if (request.InsumoFiles != null && request.InsumoFiles.Count > 0)
        {
            foreach (var file in request.InsumoFiles)
            {
                if (file.Length > MaxFileSize)
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "El archivo excede el tamano maximo permitido.",
                        new List<string> { $"El archivo '{file.FileName}' excede el tamano maximo de 20MB." }
                    );
                }

                var extension = Path.GetExtension(file.FileName);
                using var validationStream = file.OpenReadStream();
                if (!FileValidationHelper.ValidateMagicBytes(validationStream, extension))
                {
                    return ApiResponse<TaskItemDto>.Fail(
                        "Archivo invalido.",
                        new List<string> { $"El archivo '{file.FileName}' no coincide con el tipo esperado ({extension})." }
                    );
                }
            }

            // Crear tarea primero para obtener el Id
            var created = await _taskItemRepository.CreateAsync(taskItem);

            // Guardar cada archivo de insumo en disco
            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            Directory.CreateDirectory(Path.Combine(FilesBasePath, InsumosRelativeDir));

            for (int i = 0; i < request.InsumoFiles.Count; i++)
            {
                var file = request.InsumoFiles[i];
                var safeFileName = Path.GetFileName(file.FileName);
                var diskFileName = $"{created.Id}_{timestamp}_{i}_{safeFileName}";
                var relativePath = Path.Combine(InsumosRelativeDir, diskFileName);
                var absolutePath = Path.Combine(FilesBasePath, relativePath);

                using (var stream = new FileStream(absolutePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream, cancellationToken);
                }

                created.InsumoFiles.Add(new FileAttachment
                {
                    FileName = file.FileName,
                    FilePath = relativePath,
                    ContentType = file.ContentType,
                    UploadedAt = DateTime.UtcNow
                });
            }

            await _taskItemRepository.UpdateAsync(created);

            _logger.LogInformation("Tarea creada exitosamente con {Count} insumo(s): {Title} ({TaskId})",
                request.InsumoFiles.Count, created.Title, created.Id);

            return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(created), "Tarea creada exitosamente.");
        }

        var createdTask = await _taskItemRepository.CreateAsync(taskItem);

        _logger.LogInformation("Tarea creada exitosamente: {Title} ({TaskId})", createdTask.Title, createdTask.Id);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(createdTask), "Tarea creada exitosamente.");
    }
}
