namespace BSC.Application.Interfaces;

/// <summary>
/// Servicio para generacion de tokens JWT.
/// </summary>
public interface IJwtTokenService
{
    string GenerateToken(string userId, string name, string email, List<string> roles, string activeRole, List<string> modules);
}
