using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Colaboradores.Queries.GetById;

public class GetColaboradorByIdHandler : IRequestHandler<GetColaboradorByIdQuery, ApiResponse<ColaboradorDto>>
{
    private readonly IColaboradorRepository _repository;
    private readonly ILogger<GetColaboradorByIdHandler> _logger;

    public GetColaboradorByIdHandler(IColaboradorRepository repository, ILogger<GetColaboradorByIdHandler> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<ApiResponse<ColaboradorDto>> Handle(GetColaboradorByIdQuery request, CancellationToken cancellationToken)
    {
        var colaborador = await _repository.GetByIdAsync(request.Id);

        if (colaborador == null || colaborador.IsDeleted)
        {
            return ApiResponse<ColaboradorDto>.Fail("Colaborador no encontrado.");
        }

        var dto = new ColaboradorDto
        {
            Id = colaborador.Id,
            NombreCompleto = colaborador.NombreCompleto,
            Cedula = colaborador.Cedula,
            Area = colaborador.Area,
            Correo = colaborador.Correo,
            CreatedAt = colaborador.CreatedAt,
            UpdatedAt = colaborador.UpdatedAt
        };

        return ApiResponse<ColaboradorDto>.Ok(dto, "Colaborador obtenido exitosamente.");
    }
}
