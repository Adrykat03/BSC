using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Colaboradores.Queries.GetAll;

public class GetAllColaboradoresHandler : IRequestHandler<GetAllColaboradoresQuery, ApiResponse<List<ColaboradorDto>>>
{
    private readonly IColaboradorRepository _repository;
    private readonly ILogger<GetAllColaboradoresHandler> _logger;

    public GetAllColaboradoresHandler(IColaboradorRepository repository, ILogger<GetAllColaboradoresHandler> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<ApiResponse<List<ColaboradorDto>>> Handle(GetAllColaboradoresQuery request, CancellationToken cancellationToken)
    {
        var colaboradores = await _repository.GetAllAsync();

        var dtos = colaboradores.Select(c => new ColaboradorDto
        {
            Id = c.Id,
            NombreCompleto = c.NombreCompleto,
            Cedula = c.Cedula,
            Area = c.Area,
            Correo = c.Correo,
            CreatedAt = c.CreatedAt,
            UpdatedAt = c.UpdatedAt
        }).ToList();

        return ApiResponse<List<ColaboradorDto>>.Ok(dtos, "Colaboradores obtenidos exitosamente.");
    }
}
