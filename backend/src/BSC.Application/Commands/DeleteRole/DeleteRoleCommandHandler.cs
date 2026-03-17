using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.DeleteRole;

/// <summary>
/// Handler para el comando de eliminacion de rol.
/// </summary>
public class DeleteRoleCommandHandler : IRequestHandler<DeleteRoleCommand, ApiResponse<object>>
{
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<DeleteRoleCommandHandler> _logger;

    public DeleteRoleCommandHandler(IRoleRepository roleRepository, ILogger<DeleteRoleCommandHandler> logger)
    {
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<object>> Handle(DeleteRoleCommand request, CancellationToken cancellationToken)
    {
        var role = await _roleRepository.GetByIdAsync(request.Id);
        if (role == null)
        {
            return ApiResponse<object>.Fail(
                "Rol no encontrado.",
                new List<string> { $"No se encontró un rol con el ID '{request.Id}'." }
            );
        }

        await _roleRepository.DeleteAsync(request.Id);

        _logger.LogInformation("Rol eliminado exitosamente: {RoleName} ({RoleId})", role.Name, role.Id);

        return ApiResponse<object>.Ok(null, "Rol eliminado exitosamente.");
    }
}
