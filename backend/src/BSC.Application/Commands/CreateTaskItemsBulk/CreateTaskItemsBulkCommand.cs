using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.CreateTaskItemsBulk;

/// <summary>
/// Comando para la creacion masiva de tareas desde datos procesados de un XLSX.
/// El frontend parsea el archivo y envia un JSON con el array de tareas.
/// </summary>
public class CreateTaskItemsBulkCommand : IRequest<ApiResponse<BulkCreateResultDto>>
{
    public List<BulkTaskItemData> Tasks { get; set; } = new();
    public string CreatedByEmail { get; set; } = string.Empty;
    public string CreatedByRole { get; set; } = string.Empty;
    public string CreatedById { get; set; } = string.Empty;
    public string CreatedByName { get; set; } = string.Empty;
}

/// <summary>
/// Datos de una tarea individual dentro de la carga masiva.
/// </summary>
public class BulkTaskItemData
{
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime? DueDate { get; set; }
    public decimal? EstimatedTime { get; set; }
    public string? Insumos { get; set; }
    public string? Observations { get; set; }
    public string? LeaderEmail { get; set; }
    public string? CollaboratorEmail { get; set; }
}
