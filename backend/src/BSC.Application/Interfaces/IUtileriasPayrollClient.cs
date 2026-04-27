namespace BSC.Application.Interfaces;

/// <summary>
/// Resultado de la descarga de un adjunto desde la API externa de Utilerias Payroll.
/// </summary>
public class AdjuntoDescargado
{
    public required Stream Contenido { get; init; }
    public string ContentType { get; init; } = "application/octet-stream";
    public string NombreArchivo { get; init; } = "adjunto";
    public long? TamanioBytes { get; init; }
}

/// <summary>
/// Configuracion del cliente de Utilerias Payroll. Token y URL base se cargan desde el .env.
/// </summary>
public class UtileriasPayrollOptions
{
    public string BaseUrl { get; set; } = string.Empty;
    public string Token { get; set; } = string.Empty;
}

/// <summary>
/// Cliente para la API interna de Utilerias Payroll que envuelve Azure Blob Storage.
/// Se usa para descargar los adjuntos de alertas registrados en notificacionesConsolidadas.
/// </summary>
public interface IUtileriasPayrollClient
{
    Task<AdjuntoDescargado> DescargarAsync(string ruta, string nombreArchivo, CancellationToken cancellationToken);
}
