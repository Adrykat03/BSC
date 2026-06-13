using BSC.Application.DTOs;
using BSC.Application.Interfaces;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.SwitchRole;

/// <summary>
/// Handler para el comando de cambio de rol activo.
/// Genera un nuevo JWT con el rol especificado como claim principal.
/// </summary>
public class SwitchRoleCommandHandler : IRequestHandler<SwitchRoleCommand, ApiResponse<LoginResponseDto>>
{
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IColaboradorRepository _colaboradorRepository;
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<SwitchRoleCommandHandler> _logger;

    public SwitchRoleCommandHandler(IJwtTokenService jwtTokenService, IColaboradorRepository colaboradorRepository, IRoleRepository roleRepository, ILogger<SwitchRoleCommandHandler> logger)
    {
        _jwtTokenService = jwtTokenService;
        _colaboradorRepository = colaboradorRepository;
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<LoginResponseDto>> Handle(SwitchRoleCommand request, CancellationToken cancellationToken)
    {
        // Validar que el rol solicitado esta entre los roles del usuario
        if (!request.UserRoles.Any(r => r.Equals(request.Role, StringComparison.OrdinalIgnoreCase)))
        {
            return ApiResponse<LoginResponseDto>.Fail(
                "Rol no valido.",
                new List<string> { $"El usuario no tiene el rol '{request.Role}'." }
            );
        }

        // Los modulos se calculan a partir del ROL ACTIVO (el rol al que se cambia).
        var activeRoleEntity = await _roleRepository.GetByNameAsync(request.Role);
        var modules = (activeRoleEntity != null && !activeRoleEntity.IsDeleted)
            ? activeRoleEntity.Modules
            : new List<string>();

        var token = _jwtTokenService.GenerateToken(
            request.UserId,
            request.UserName,
            request.UserEmail,
            request.UserRoles,
            request.Role,
            modules
        );

        // Track last login on role switch
        var colaborador = await _colaboradorRepository.GetByCorreoAsync(request.UserEmail);
        DateTime? previousLogin = colaborador?.LastLoginAt;
        if (colaborador != null)
        {
            await _colaboradorRepository.UpdateLastLoginAsync(colaborador.Id, DateTime.UtcNow);
        }

        var response = new LoginResponseDto
        {
            Token = token,
            User = new LoginUserDto
            {
                Id = request.UserId,
                Name = request.UserName,
                Email = request.UserEmail,
                Roles = request.UserRoles
            },
            LastLoginAt = previousLogin
        };

        _logger.LogInformation("Cambio de rol activo para {Email}: {Role}", request.UserEmail, request.Role);

        return ApiResponse<LoginResponseDto>.Ok(response, "Rol activo cambiado exitosamente.");
    }
}
