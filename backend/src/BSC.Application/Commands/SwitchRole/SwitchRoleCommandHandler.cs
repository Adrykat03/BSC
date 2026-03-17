using BSC.Application.DTOs;
using BSC.Application.Interfaces;
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
    private readonly ILogger<SwitchRoleCommandHandler> _logger;

    public SwitchRoleCommandHandler(IJwtTokenService jwtTokenService, ILogger<SwitchRoleCommandHandler> logger)
    {
        _jwtTokenService = jwtTokenService;
        _logger = logger;
    }

    public Task<ApiResponse<LoginResponseDto>> Handle(SwitchRoleCommand request, CancellationToken cancellationToken)
    {
        // Validar que el rol solicitado esta entre los roles del usuario
        if (!request.UserRoles.Any(r => r.Equals(request.Role, StringComparison.OrdinalIgnoreCase)))
        {
            return Task.FromResult(ApiResponse<LoginResponseDto>.Fail(
                "Rol no valido.",
                new List<string> { $"El usuario no tiene el rol '{request.Role}'." }
            ));
        }

        var token = _jwtTokenService.GenerateToken(
            request.UserId,
            request.UserName,
            request.UserEmail,
            request.UserRoles,
            request.Role
        );

        var response = new LoginResponseDto
        {
            Token = token,
            User = new LoginUserDto
            {
                Id = request.UserId,
                Name = request.UserName,
                Email = request.UserEmail,
                Roles = request.UserRoles
            }
        };

        _logger.LogInformation("Cambio de rol activo para {Email}: {Role}", request.UserEmail, request.Role);

        return Task.FromResult(ApiResponse<LoginResponseDto>.Ok(response, "Rol activo cambiado exitosamente."));
    }
}
