using BSC.Domain.ValueObjects;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace BSC.Domain.Entities;

/// <summary>
/// Entidad de dominio que representa una tarea del sistema.
/// </summary>
public class TaskItem
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = string.Empty;

    [BsonElement("title")]
    public string Title { get; set; } = string.Empty;

    [BsonElement("description")]
    public string Description { get; set; } = string.Empty;

    [BsonElement("status")]
    public string Status { get; set; } = "Creada";

    // Asignacion a Lider (el Gerente asigna a un Lider)
    [BsonElement("assignedLeaderId")]
    public string? AssignedLeaderId { get; set; }

    [BsonElement("assignedLeaderName")]
    public string? AssignedLeaderName { get; set; }

    [BsonElement("assignedLeaderEmail")]
    public string? AssignedLeaderEmail { get; set; }

    // Asignacion a Colaborador (el Lider o Gerente asigna a un Colaborador)
    [BsonElement("assignedToId")]
    public string? AssignedToId { get; set; }

    [BsonElement("assignedToName")]
    public string? AssignedToName { get; set; }

    [BsonElement("assignedToEmail")]
    public string? AssignedToEmail { get; set; }

    [BsonElement("estimatedTime")]
    public decimal? EstimatedTime { get; set; }

    [BsonElement("actualTime")]
    public decimal? ActualTime { get; set; }

    // Insumos (recursos para la tarea, los sube el Gerente al crear)
    [BsonElement("insumos")]
    public string? Insumos { get; set; }

    [BsonElement("insumoFileName")]
    public string? InsumoFileName { get; set; }

    [BsonElement("insumoFilePath")]
    public string? InsumoFilePath { get; set; }

    [BsonElement("insumoContentType")]
    public string? InsumoContentType { get; set; }

    // Evidencia (la sube el Colaborador al completar)
    [BsonElement("evidenceFileName")]
    public string? EvidenceFileName { get; set; }

    [BsonElement("evidenceFilePath")]
    public string? EvidenceFilePath { get; set; }

    [BsonElement("evidenceContentType")]
    public string? EvidenceContentType { get; set; }

    // Historial de cambios de estado (append-only)
    [BsonElement("statusHistory")]
    public List<StatusChange> StatusHistory { get; set; } = new();

    // Campos de auditoria
    [BsonElement("createdAt")]
    public DateTime CreatedAt { get; set; }

    [BsonElement("createdBy")]
    public string CreatedBy { get; set; } = string.Empty;

    [BsonElement("updatedAt")]
    public DateTime UpdatedAt { get; set; }

    [BsonElement("updatedBy")]
    public string UpdatedBy { get; set; } = string.Empty;

    [BsonElement("isDeleted")]
    public bool IsDeleted { get; set; } = false;

    [BsonElement("deletedAt")]
    public DateTime? DeletedAt { get; set; }
}
