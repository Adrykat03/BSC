using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Queries.GetRoleById;

/// <summary>
/// Handler para la query de obtener rol por ID.
/// </summary>
public class GetRoleByIdQueryHandler : IRequestHandler<GetRoleByIdQuery, ApiResponse<RoleDto>>
{
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<GetRoleByIdQueryHandler> _logger;

    public GetRoleByIdQueryHandler(IRoleRepository roleRepository, ILogger<GetRoleByIdQueryHandler> logger)
    {
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<RoleDto>> Handle(GetRoleByIdQuery request, CancellationToken cancellationToken)
    {
        var role = await _roleRepository.GetByIdAsync(request.Id);
        if (role == null)
        {
            return ApiResponse<RoleDto>.Fail(
                "Rol no encontrado.",
                new List<string> { $"No se encontró un rol con el ID '{request.Id}'." }
            );
        }

        var dto = new RoleDto
        {
            Id = role.Id,
            Name = role.Name,
            Description = role.Description,
            Modules = role.Modules,
            CreatedAt = role.CreatedAt,
            UpdatedAt = role.UpdatedAt
        };

        return ApiResponse<RoleDto>.Ok(dto);
    }
}
