using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace BSC.Domain.Entities;

/// <summary>
/// Entidad de dominio que representa un rol del sistema.
/// </summary>
public class Role
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = string.Empty;

    [BsonElement("name")]
    public string Name { get; set; } = string.Empty;

    [BsonElement("description")]
    public string Description { get; set; } = string.Empty;

    /// <summary>
    /// Modulos a los que este rol da acceso. Keys del catalogo <see cref="Constants.Modules"/>.
    /// </summary>
    [BsonElement("modules")]
    public List<string> Modules { get; set; } = new();

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
