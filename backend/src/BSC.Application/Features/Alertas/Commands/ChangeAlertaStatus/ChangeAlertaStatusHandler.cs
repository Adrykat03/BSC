using BSC.Application.DTOs;
using BSC.Application.Interfaces;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Alertas.Commands.ChangeAlertaStatus;

/// <summary>
/// Handler para el cambio de estado de una alerta.
/// Orquesta DAB (SQL Server) + MongoDB con manejo de errores en 3 escenarios:
/// 1) DAB OK + Mongo OK         -> 200, historialPersistido=true.
/// 2) DAB falla                 -> 500, no se toca Mongo.
/// 3) DAB OK + Mongo falla      -> 200, historialPersistido=false (warning log).
/// </summary>
public class ChangeAlertaStatusHandler : IRequestHandler<ChangeAlertaStatusCommand, ApiResponse<ChangeAlertaStatusResultDto>>
{
    private readonly IDabAlertasClient _dabClient;
    private readonly IAlertaHistorialRepository _historialRepository;
    private readonly ILogger<ChangeAlertaStatusHandler> _logger;

    public ChangeAlertaStatusHandler(
        IDabAlertasClient dabClient,
        IAlertaHistorialRepository historialRepository,
        ILogger<ChangeAlertaStatusHandler> logger)
    {
        _dabClient = dabClient;
        _historialRepository = historialRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<ChangeAlertaStatusResultDto>> Handle(ChangeAlertaStatusCommand request, CancellationToken cancellationToken)
    {
        // 1) Leer estado actual via DAB para capturar estadoAnterior.
        NotificacionConsolidadaSnapshot? snapshot;
        try
        {
            snapshot = await _dabClient.GetByIdAsync(request.IdNotificacion, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error consultando DAB para idNotificacion={Id}", request.IdNotificacion);
            // Se propaga al middleware de excepciones (-> 500).
            throw;
        }

        if (snapshot == null)
        {
            return ApiResponse<ChangeAlertaStatusResultDto>.Fail(
                "Alerta no encontrada.",
                new List<string> { $"No se encontro una notificacion con idNotificacion '{request.IdNotificacion}'." }
            );
        }

        var estadoAnterior = string.IsNullOrEmpty(snapshot.Estado) ? AlertaEstados.Activa : snapshot.Estado;

        // Idempotencia / no se restringen transiciones: incluso si estadoAnterior == nuevoEstado,
        // se registra una entrada en historial (caso "actualizar solo el comentario").
        //
        // Manejo de zona horaria:
        // - SQL guarda literalmente lo que se manda (la columna no tiene TZ). El frontend
        //   lee el string y lo interpreta como hora local del browser. Para que el usuario
        //   vea la misma hora a la que hizo el cambio, mandamos hora Ecuador (UTC-5, no DST).
        // - Mongo guarda siempre en UTC. El frontend convierte a local automaticamente.
        var ahoraUtc = DateTime.UtcNow;
        var ahoraEcuador = ahoraUtc.AddHours(-5);

        // fechaResolucion: null si vuelve a A, hora Ecuador en cualquier otro caso.
        DateTime? fechaResolucion = request.NuevoEstado == AlertaEstados.Activa ? null : ahoraEcuador;

        // 2) PATCH a DAB. Si falla -> propagar (no se toca Mongo).
        try
        {
            await _dabClient.ActualizarAsync(request.IdNotificacion, new ActualizarNotificacionRequest
            {
                Estado = request.NuevoEstado,
                NotasResolucion = request.Comentario,
                UsuarioResolucion = request.UsuarioEmail,
                FechaResolucion = fechaResolucion,
                FechaModificacion = ahoraEcuador,
            }, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex,
                "DAB PATCH fallo. idNotificacion={Id} nuevoEstado={Estado} usuario={Email}",
                request.IdNotificacion, request.NuevoEstado, request.UsuarioEmail);
            // Se propaga al middleware -> 500. Mongo no se toca.
            throw;
        }

        // 3) Insertar en MongoDB. Si falla, el cambio en SQL ya se aplico:
        //    log warning y devolver historialPersistido=false.
        var historialPersistido = true;
        try
        {
            await _historialRepository.CreateAsync(new AlertaEstadoHistorial
            {
                IdNotificacion = request.IdNotificacion,
                EstadoAnterior = estadoAnterior,
                EstadoNuevo = request.NuevoEstado,
                Comentario = request.Comentario,
                UsuarioEmail = request.UsuarioEmail,
                UsuarioRol = request.UsuarioRol,
                Fecha = ahoraUtc,
            }, cancellationToken);
        }
        catch (Exception ex)
        {
            historialPersistido = false;
            _logger.LogWarning(ex,
                "DAB OK pero Mongo fallo persistiendo historial. idNotificacion={Id} estadoAnterior={Anterior} estadoNuevo={Nuevo} usuario={Email}",
                request.IdNotificacion, estadoAnterior, request.NuevoEstado, request.UsuarioEmail);
        }

        _logger.LogInformation(
            "Estado de alerta cambiado: idNotificacion={Id} {Anterior} -> {Nuevo} por {Email} ({Rol}). historialPersistido={Hp}",
            request.IdNotificacion, estadoAnterior, request.NuevoEstado, request.UsuarioEmail, request.UsuarioRol, historialPersistido);

        return ApiResponse<ChangeAlertaStatusResultDto>.Ok(
            new ChangeAlertaStatusResultDto
            {
                Success = true,
                HistorialPersistido = historialPersistido,
                Estado = request.NuevoEstado,
                NotasResolucion = request.Comentario,
                UsuarioResolucion = request.UsuarioEmail,
            },
            "Estado de alerta actualizado.");
    }
}
