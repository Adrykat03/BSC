using BSC.Application.DTOs;
using BSC.Domain.Entities;

namespace BSC.Application.Mappings;

/// <summary>
/// Mapper centralizado para el historial de estados de Alertas.
/// </summary>
public static class AlertaHistorialMapper
{
    public static AlertaEstadoHistorialDto ToDto(AlertaEstadoHistorial entity) => new()
    {
        Id = entity.Id,
        IdNotificacion = entity.IdNotificacion,
        EstadoAnterior = entity.EstadoAnterior,
        EstadoNuevo = entity.EstadoNuevo,
        Comentario = entity.Comentario,
        UsuarioEmail = entity.UsuarioEmail,
        UsuarioRol = entity.UsuarioRol,
        Fecha = entity.Fecha,
    };
}
