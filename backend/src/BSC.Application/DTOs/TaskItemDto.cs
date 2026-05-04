namespace BSC.Application.DTOs;

/// <summary>
/// DTO de respuesta para la entidad TaskItem.
/// </summary>
public class TaskItemDto
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;

    // Asignacion a Lider
    public string? AssignedLeaderId { get; set; }
    public string? AssignedLeaderName { get; set; }
    public string? AssignedLeaderEmail { get; set; }

    // Asignacion a Colaborador
    public string? AssignedToId { get; set; }
    public string? AssignedToName { get; set; }
    public string? AssignedToEmail { get; set; }

    public DateTime? DueDate { get; set; }
    public decimal EstimatedTime { get; set; }
    public decimal? ActualTime { get; set; }

    // Insumos
    public string? Insumos { get; set; }
    public List<FileAttachmentDto> InsumoFiles { get; set; } = new();

    // Evidencia
    public List<FileAttachmentDto> EvidenceFiles { get; set; } = new();
    public string? EvidenceText { get; set; }

    // Observaciones
    public string? Observations { get; set; }

    // Calificacion efectiva (0-100). Refleja override manual si existe, si no el cálculo automático.
    public int? Rating { get; set; }

    // Override manual del Gerente (null si no se ha modificado).
    public int? RatingOverride { get; set; }
    public string? RatingOverrideReason { get; set; }
    public string? RatingOverrideBy { get; set; }
    public DateTime? RatingOverrideAt { get; set; }

    // Audit trail completo de modificaciones manuales (append-only).
    public List<RatingChangeDto> RatingHistory { get; set; } = new();

    // Historial de estados
    public List<StatusChangeDto> StatusHistory { get; set; } = new();

    public DateTime CreatedAt { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
    public DateTime UpdatedAt { get; set; }
}

/// <summary>
/// DTO para una entrada del audit trail de calificaciones.
/// </summary>
public class RatingChangeDto
{
    public int? FromRating { get; set; }
    public int ToRating { get; set; }
    public string ChangedById { get; set; } = string.Empty;
    public string ChangedByName { get; set; } = string.Empty;
    public string ChangedByEmail { get; set; } = string.Empty;
    public DateTime ChangedAt { get; set; }
    public string Reason { get; set; } = string.Empty;
}

/// <summary>
/// DTO para un archivo adjunto (insumo o evidencia).
/// </summary>
public class FileAttachmentDto
{
    public string Id { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public DateTime UploadedAt { get; set; }
}

/// <summary>
/// DTO para un cambio de estado en el historial.
/// </summary>
public class StatusChangeDto
{
    public string FromStatus { get; set; } = string.Empty;
    public string ToStatus { get; set; } = string.Empty;
    public string ChangedById { get; set; } = string.Empty;
    public string ChangedByName { get; set; } = string.Empty;
    public string ChangedByEmail { get; set; } = string.Empty;
    public DateTime ChangedAt { get; set; }
    public string? Comment { get; set; }
}
