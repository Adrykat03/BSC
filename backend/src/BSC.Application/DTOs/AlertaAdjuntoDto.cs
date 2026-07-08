namespace BSC.Application.DTOs;

/// <summary>
/// DTO de un adjunto de resolucion de alerta (sin exponer la ruta en disco).
/// </summary>
public class AlertaAdjuntoDto
{
    public string Id { get; set; } = string.Empty;
    public long IdNotificacion { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public string SubidoPorEmail { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
}
