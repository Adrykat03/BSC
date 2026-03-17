using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.Login;

/// <summary>
/// Comando para autenticar un usuario por email y password.
/// </summary>
public class LoginCommand : IRequest<ApiResponse<LoginResponseDto>>
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}
