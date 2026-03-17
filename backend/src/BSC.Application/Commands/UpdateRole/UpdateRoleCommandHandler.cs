using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.UpdateRole;

/// <summary>
/// Handler para el comando de actualizacion de rol.
/// </summary>
public class UpdateRoleCommandHandler : IRequestHandler<UpdateRoleCommand, ApiResponse<RoleDto>>
{
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<UpdateRoleCommandHandler> _logger;

    public UpdateRoleCommandHandler(IRoleRepository roleRepository, ILogger<UpdateRoleCommandHandler> logger)
    {
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<RoleDto>> Handle(UpdateRoleCommand request, CancellationToken cancellationToken)
    {
        var role = await _roleRepository.GetByIdAsync(request.Id);
        if (role == null)
        {
            return ApiResponse<RoleDto>.Fail(
                "Rol no encontrado.",
                new List<string> { $"No se encontró un rol con el ID '{request.Id}'." }
            );
        }

        // Verificar nombre unico (excluir el rol actual)
        var existing = await _roleRepository.GetByNameAsync(request.Name);
        if (existing != null && existing.Id != request.Id)
        {
            return ApiResponse<RoleDto>.Fail(
                "Ya existe un rol con ese nombre.",
                new List<string> { $"El nombre '{request.Name}' ya está en uso." }
            );
        }

        role.Name = request.Name;
        role.Description = request.Description;
        role.UpdatedAt = DateTime.UtcNow;

        var updated = await _roleRepository.UpdateAsync(role);

        _logger.LogInformation("Rol actualizado exitosamente: {RoleName} ({RoleId})", updated.Name, updated.Id);

        var dto = new RoleDto
        {
            Id = updated.Id,
            Name = updated.Name,
            Description = updated.Description,
            CreatedAt = updated.CreatedAt,
            UpdatedAt = updated.UpdatedAt
        };

        return ApiResponse<RoleDto>.Ok(dto, "Rol actualizado exitosamente.");
    }
}
