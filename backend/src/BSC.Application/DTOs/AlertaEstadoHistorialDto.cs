namespace BSC.Application.DTOs;

/// <summary>
/// DTO de un registro del historial de cambios de estado de una alerta.
/// </summary>
public class AlertaEstadoHistorialDto
{
    public string Id { get; set; } = string.Empty;
    public long IdNotificacion { get; set; }
    public string EstadoAnterior { get; set; } = string.Empty;
    public string EstadoNuevo { get; set; } = string.Empty;
    public string? Comentario { get; set; }
    public string UsuarioEmail { get; set; } = string.Empty;
    public string UsuarioRol { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
}
