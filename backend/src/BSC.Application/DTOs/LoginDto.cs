namespace BSC.Application.DTOs;

/// <summary>
/// DTO para la solicitud de login.
/// </summary>
public class LoginRequestDto
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

/// <summary>
/// DTO para la respuesta de login.
/// </summary>
public class LoginResponseDto
{
    public string Token { get; set; } = string.Empty;
    public LoginUserDto User { get; set; } = new();
}

/// <summary>
/// DTO con datos del usuario autenticado.
/// </summary>
public class LoginUserDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public List<string> Roles { get; set; } = new();
}

/// <summary>
/// DTO para la solicitud de cambio de rol activo.
/// </summary>
public class SwitchRoleRequestDto
{
    public string Role { get; set; } = string.Empty;
}
