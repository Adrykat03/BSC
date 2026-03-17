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

    [BsonElement("assignedTo")]
    public string? AssignedTo { get; set; }

    [BsonElement("status")]
    public string Status { get; set; } = "Creada";

    [BsonElement("estimatedTime")]
    public decimal? EstimatedTime { get; set; }

    [BsonElement("actualTime")]
    public decimal? ActualTime { get; set; }

    [BsonElement("evidenceFileName")]
    public string? EvidenceFileName { get; set; }

    [BsonElement("evidenceFilePath")]
    public string? EvidenceFilePath { get; set; }

    [BsonElement("evidenceContentType")]
    public string? EvidenceContentType { get; set; }

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
