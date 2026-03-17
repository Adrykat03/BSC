using MongoDB.Bson.Serialization.Attributes;

namespace BSC.Domain.ValueObjects;

/// <summary>
/// Value object que representa un cambio de estado en una tarea.
/// </summary>
public class StatusChange
{
    [BsonElement("fromStatus")]
    public string FromStatus { get; set; } = string.Empty;

    [BsonElement("toStatus")]
    public string ToStatus { get; set; } = string.Empty;

    [BsonElement("changedById")]
    public string ChangedById { get; set; } = string.Empty;

    [BsonElement("changedByName")]
    public string ChangedByName { get; set; } = string.Empty;

    [BsonElement("changedByEmail")]
    public string ChangedByEmail { get; set; } = string.Empty;

    [BsonElement("changedAt")]
    public DateTime ChangedAt { get; set; }

    [BsonElement("comment")]
    public string? Comment { get; set; }
}
