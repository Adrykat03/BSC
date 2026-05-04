using MongoDB.Bson.Serialization.Attributes;

namespace BSC.Domain.ValueObjects;

/// <summary>
/// Value object que registra una modificación manual de la calificación de una tarea.
/// Se usa como entrada del audit trail (RatingHistory) cuando un Gerente sobreescribe
/// el rating automático.
/// </summary>
public class RatingChange
{
    /// <summary>Calificación previa (puede ser la automática o un override anterior).</summary>
    [BsonElement("fromRating")]
    public int? FromRating { get; set; }

    /// <summary>Calificación nueva asignada por el Gerente.</summary>
    [BsonElement("toRating")]
    public int ToRating { get; set; }

    [BsonElement("changedById")]
    public string ChangedById { get; set; } = string.Empty;

    [BsonElement("changedByName")]
    public string ChangedByName { get; set; } = string.Empty;

    [BsonElement("changedByEmail")]
    public string ChangedByEmail { get; set; } = string.Empty;

    [BsonElement("changedAt")]
    public DateTime ChangedAt { get; set; }

    /// <summary>Justificación obligatoria del cambio (≥10 caracteres).</summary>
    [BsonElement("reason")]
    public string Reason { get; set; } = string.Empty;
}
