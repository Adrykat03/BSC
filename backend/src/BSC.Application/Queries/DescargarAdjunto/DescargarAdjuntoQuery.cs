using BSC.Application.Interfaces;
using MediatR;

namespace BSC.Application.Queries.DescargarAdjunto;

/// <summary>
/// Query para descargar un adjunto registrado en Avisos.notificacionesConsolidadas.
/// Reenvia la peticion al API interna de Utilerias Payroll que sirve el blob.
/// </summary>
public class DescargarAdjuntoQuery : IRequest<AdjuntoDescargado>
{
    public string Ruta { get; set; } = string.Empty;
    public string NombreArchivo { get; set; } = string.Empty;
}
