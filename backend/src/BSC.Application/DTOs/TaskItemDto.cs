namespace BSC.Application.DTOs;

/// <summary>
/// DTO de respuesta para la entidad TaskItem.
/// </summary>
public class TaskItemDto
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? AssignedTo { get; set; }
    public string Status { get; set; } = string.Empty;
    public decimal? EstimatedTime { get; set; }
    public decimal? ActualTime { get; set; }
    public string? EvidenceFileName { get; set; }
    public bool HasEvidence { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
