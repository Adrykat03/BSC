namespace BSC.Application.DTOs;

/// <summary>
/// Body que recibe POST /api/alertas/{id}/cambiar-estado.
/// El usuario (email + rol) NO viaja en el body: se extrae del JWT (ClaimsPrincipal)
/// en el controller para evitar impersonacion.
/// </summary>
public class ChangeAlertaStatusDto
{
    /// <summary>
    /// Nuevo estado char(1): A | R | C | E | P.
    /// </summary>
    public string NuevoEstado { get; set; } = string.Empty;

    /// <summary>
    /// Comentario opcional (max 500 chars). Se guarda en notasResolucion en SQL
    /// y en el historial en Mongo.
    /// </summary>
    public string? Comentario { get; set; }
}

/// <summary>
/// Respuesta del cambio de estado de alerta.
/// historialPersistido = false indica que el cambio se aplico en SQL via DAB
/// pero el insert en Mongo fallo (se puede recuperar despues).
/// </summary>
public class ChangeAlertaStatusResultDto
{
    public bool Success { get; set; }
    public bool HistorialPersistido { get; set; }
}

/// <summary>
/// Respuesta del listado de historial.
/// </summary>
public class AlertaHistorialListDto
{
    public List<AlertaEstadoHistorialDto> Items { get; set; } = new();
}
