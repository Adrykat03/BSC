using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace BSC.Domain.Entities;

/// <summary>
/// Entidad de dominio que representa un registro del historial de cambios de estado
/// de una notificacion del modulo Alertas Payroll.
/// La tabla principal (Avisos.notificacionesConsolidadas) vive en SQL Server y se actualiza
/// via DAB; este historial se persiste en MongoDB (no se crea ninguna tabla nueva en SQL).
/// </summary>
[BsonIgnoreExtraElements]
public class AlertaEstadoHistorial
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// idNotificacion en la tabla Avisos.notificacionesConsolidadas (BIGINT en SQL).
    /// </summary>
    [BsonElement("idNotificacion")]
    public long IdNotificacion { get; set; }

    /// <summary>
    /// Estado anterior. char(1): A | R | C | E | P. Puede coincidir con EstadoNuevo
    /// si solo se actualiza el comentario sin cambiar de estado.
    /// </summary>
    [BsonElement("estadoAnterior")]
    public string EstadoAnterior { get; set; } = string.Empty;

    /// <summary>
    /// Estado nuevo. char(1): A | R | C | E | P.
    /// </summary>
    [BsonElement("estadoNuevo")]
    public string EstadoNuevo { get; set; } = string.Empty;

    [BsonElement("comentario")]
    public string? Comentario { get; set; }

    [BsonElement("usuarioEmail")]
    public string UsuarioEmail { get; set; } = string.Empty;

    [BsonElement("usuarioRol")]
    public string UsuarioRol { get; set; } = string.Empty;

    [BsonElement("fecha")]
    public DateTime Fecha { get; set; }
}
