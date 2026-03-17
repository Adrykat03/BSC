using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using BSC.Application.Interfaces;
using Microsoft.IdentityModel.Tokens;

namespace BSC.Infrastructure.Services;

/// <summary>
/// Implementacion del servicio de generacion de tokens JWT.
/// </summary>
public class JwtTokenService : IJwtTokenService
{
    private readonly string _secretKey;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _expirationMinutes;

    public JwtTokenService(string secretKey, string issuer, string audience, int expirationMinutes)
    {
        _secretKey = secretKey;
        _issuer = issuer;
        _audience = audience;
        _expirationMinutes = expirationMinutes;
    }

    public string GenerateToken(string userId, string name, string email, List<string> roles, string activeRole)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_secretKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId),
            new(ClaimTypes.Name, name),
            new(ClaimTypes.Email, email),
            new("roles", JsonSerializer.Serialize(roles)),
            new(ClaimTypes.Role, activeRole)
        };

        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_expirationMinutes),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
