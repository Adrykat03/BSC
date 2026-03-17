using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Colaboradores.Queries.GetAll;

public class GetAllColaboradoresHandler : IRequestHandler<GetAllColaboradoresQuery, ApiResponse<List<ColaboradorDto>>>
{
    private readonly IColaboradorRepository _repository;
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<GetAllColaboradoresHandler> _logger;

    public GetAllColaboradoresHandler(
        IColaboradorRepository repository,
        IRoleRepository roleRepository,
        ILogger<GetAllColaboradoresHandler> logger)
    {
        _repository = repository;
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<List<ColaboradorDto>>> Handle(GetAllColaboradoresQuery request, CancellationToken cancellationToken)
    {
        var colaboradores = await _repository.GetAllAsync();

        var dtos = new List<ColaboradorDto>();

        foreach (var c in colaboradores)
        {
            var rolName = string.Empty;
            if (!string.IsNullOrEmpty(c.RolId))
            {
                var role = await _roleRepository.GetByIdAsync(c.RolId);
                rolName = role?.Name ?? string.Empty;
            }

            dtos.Add(new ColaboradorDto
            {
                Id = c.Id,
                NombreCompleto = c.NombreCompleto,
                Cedula = c.Cedula,
                Area = c.Area,
                Correo = c.Correo,
                RolId = c.RolId,
                RolName = rolName,
                CreatedAt = c.CreatedAt,
                UpdatedAt = c.UpdatedAt
            });
        }

        return ApiResponse<List<ColaboradorDto>>.Ok(dtos, "Colaboradores obtenidos exitosamente.");
    }
}
