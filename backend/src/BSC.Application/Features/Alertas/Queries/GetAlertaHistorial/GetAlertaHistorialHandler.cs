using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Alertas.Queries.GetAlertaHistorial;

public class GetAlertaHistorialHandler : IRequestHandler<GetAlertaHistorialQuery, ApiResponse<AlertaHistorialListDto>>
{
    private readonly IAlertaHistorialRepository _repository;
    private readonly ILogger<GetAlertaHistorialHandler> _logger;

    public GetAlertaHistorialHandler(IAlertaHistorialRepository repository, ILogger<GetAlertaHistorialHandler> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<ApiResponse<AlertaHistorialListDto>> Handle(GetAlertaHistorialQuery request, CancellationToken cancellationToken)
    {
        var registros = await _repository.GetByIdNotificacionAsync(request.IdNotificacion, cancellationToken);

        var dto = new AlertaHistorialListDto
        {
            Items = registros.Select(AlertaHistorialMapper.ToDto).ToList(),
        };

        _logger.LogDebug(
            "Historial leido para idNotificacion={Id}. Registros={Count}",
            request.IdNotificacion, dto.Items.Count);

        return ApiResponse<AlertaHistorialListDto>.Ok(dto, "Historial obtenido exitosamente.");
    }
}
