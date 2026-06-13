using BSC.Application.DTOs;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.CreateRole;

/// <summary>
/// Handler para el comando de creacion de rol.
/// </summary>
public class CreateRoleCommandHandler : IRequestHandler<CreateRoleCommand, ApiResponse<RoleDto>>
{
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<CreateRoleCommandHandler> _logger;

    public CreateRoleCommandHandler(IRoleRepository roleRepository, ILogger<CreateRoleCommandHandler> logger)
    {
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<RoleDto>> Handle(CreateRoleCommand request, CancellationToken cancellationToken)
    {
        // Verificar nombre unico
        var existing = await _roleRepository.GetByNameAsync(request.Name);
        if (existing != null)
        {
            return ApiResponse<RoleDto>.Fail(
                "Ya existe un rol con ese nombre.",
                new List<string> { $"El nombre '{request.Name}' ya está en uso." }
            );
        }

        var role = new Role
        {
            Name = request.Name,
            Description = request.Description,
            Modules = request.Modules ?? new List<string>(),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        var created = await _roleRepository.CreateAsync(role);

        _logger.LogInformation("Rol creado exitosamente: {RoleName} ({RoleId})", created.Name, created.Id);

        var dto = new RoleDto
        {
            Id = created.Id,
            Name = created.Name,
            Description = created.Description,
            Modules = created.Modules,
            CreatedAt = created.CreatedAt,
            UpdatedAt = created.UpdatedAt
        };

        return ApiResponse<RoleDto>.Ok(dto, "Rol creado exitosamente.");
    }
}
