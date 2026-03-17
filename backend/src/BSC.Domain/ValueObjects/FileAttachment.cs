using MongoDB.Bson.Serialization.Attributes;

namespace BSC.Domain.ValueObjects;

/// <summary>
/// Value object que representa un archivo adjunto (insumo o evidencia).
/// </summary>
public class FileAttachment
{
    [BsonElement("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [BsonElement("fileName")]
    public string FileName { get; set; } = string.Empty;

    [BsonElement("filePath")]
    public string FilePath { get; set; } = string.Empty;

    [BsonElement("contentType")]
    public string ContentType { get; set; } = string.Empty;

    [BsonElement("uploadedAt")]
    public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
}
