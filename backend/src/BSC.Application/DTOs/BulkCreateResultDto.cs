namespace BSC.Application.DTOs;

/// <summary>
/// DTO con el resultado de una operacion de carga masiva de tareas.
/// </summary>
public class BulkCreateResultDto
{
    public int TotalReceived { get; set; }
    public int TotalCreated { get; set; }
    public int TotalFailed { get; set; }
    public List<BulkTaskResultItem> Results { get; set; } = new();
}

/// <summary>
/// Resultado individual de cada tarea procesada en la carga masiva.
/// </summary>
public class BulkTaskResultItem
{
    public int Row { get; set; }
    public string Title { get; set; } = string.Empty;
    public bool Success { get; set; }
    public string? TaskId { get; set; }
    public string? Error { get; set; }
}
