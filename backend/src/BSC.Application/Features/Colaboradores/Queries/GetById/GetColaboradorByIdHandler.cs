using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Colaboradores.Queries.GetById;

public class GetColaboradorByIdHandler : IRequestHandler<GetColaboradorByIdQuery, ApiResponse<ColaboradorDto>>
{
    private readonly IColaboradorRepository _repository;
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<GetColaboradorByIdHandler> _logger;

    public GetColaboradorByIdHandler(
        IColaboradorRepository repository,
        IRoleRepository roleRepository,
        ILogger<GetColaboradorByIdHandler> logger)
    {
        _repository = repository;
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<ColaboradorDto>> Handle(GetColaboradorByIdQuery request, CancellationToken cancellationToken)
    {
        var colaborador = await _repository.GetByIdAsync(request.Id);

        if (colaborador == null || colaborador.IsDeleted)
        {
            return ApiResponse<ColaboradorDto>.Fail("Colaborador no encontrado.");
        }

        var rolName = string.Empty;
        if (!string.IsNullOrEmpty(colaborador.RolId))
        {
            var role = await _roleRepository.GetByIdAsync(colaborador.RolId);
            rolName = role?.Name ?? string.Empty;
        }

        var dto = new ColaboradorDto
        {
            Id = colaborador.Id,
            NombreCompleto = colaborador.NombreCompleto,
            Cedula = colaborador.Cedula,
            Area = colaborador.Area,
            Correo = colaborador.Correo,
            RolId = colaborador.RolId,
            RolName = rolName,
            CreatedAt = colaborador.CreatedAt,
            UpdatedAt = colaborador.UpdatedAt
        };

        return ApiResponse<ColaboradorDto>.Ok(dto, "Colaborador obtenido exitosamente.");
    }
}
