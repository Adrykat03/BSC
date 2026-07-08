using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace BSC.Domain.Entities;

/// <summary>
/// Adjunto de resolucion de una alerta (Alertas Payroll). Lo sube quien cambia el estado
/// de la alerta. El archivo se guarda en disco (/app/files/...) y esta metadata en MongoDB
/// (coleccion alertasResolucionAdjuntos). La tabla de alertas vive en SQL Server (via DAB);
/// esto NO crea tablas nuevas en SQL.
/// </summary>
[BsonIgnoreExtraElements]
public class AlertaResolucionAdjunto
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = string.Empty;

    /// <summary>idNotificacion en Avisos.notificacionesConsolidadas (BIGINT en SQL).</summary>
    [BsonElement("idNotificacion")]
    public long IdNotificacion { get; set; }

    [BsonElement("fileName")]
    public string FileName { get; set; } = string.Empty;

    /// <summary>Ruta relativa a /app/files (no se expone al cliente).</summary>
    [BsonElement("filePath")]
    public string FilePath { get; set; } = string.Empty;

    [BsonElement("contentType")]
    public string ContentType { get; set; } = string.Empty;

    [BsonElement("sizeBytes")]
    public long SizeBytes { get; set; }

    [BsonElement("subidoPorEmail")]
    public string SubidoPorEmail { get; set; } = string.Empty;

    [BsonElement("fecha")]
    public DateTime Fecha { get; set; } = DateTime.UtcNow;
}
