using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace BSC.Domain.Entities;

/// <summary>
/// Configuracion para el dashboard BSC.
/// Define que colaboradores (por email) tienen un dashboard BSC adicional
/// y que patron de titulo de tarea se usa para filtrar tareas BSC.
/// </summary>
[BsonIgnoreExtraElements]
public class BscDashboardConfig
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = string.Empty;

    [BsonElement("emails")]
    public List<string> Emails { get; set; } = new();

    [BsonElement("taskTitlePattern")]
    public string TaskTitlePattern { get; set; } = string.Empty;

    [BsonElement("isActive")]
    public bool IsActive { get; set; } = true;

    [BsonElement("createdAt")]
    public DateTime CreatedAt { get; set; }

    [BsonElement("updatedAt")]
    public DateTime UpdatedAt { get; set; }
}
