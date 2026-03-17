using BSC.Application.DTOs;
using BSC.Application.Interfaces;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.Login;

/// <summary>
/// Handler para el comando de login.
/// Verifica credenciales y genera un JWT token.
/// </summary>
public class LoginCommandHandler : IRequestHandler<LoginCommand, ApiResponse<LoginResponseDto>>
{
    private readonly IColaboradorRepository _colaboradorRepository;
    private readonly IRoleRepository _roleRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly ILogger<LoginCommandHandler> _logger;

    public LoginCommandHandler(
        IColaboradorRepository colaboradorRepository,
        IRoleRepository roleRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenService jwtTokenService,
        ILogger<LoginCommandHandler> logger)
    {
        _colaboradorRepository = colaboradorRepository;
        _roleRepository = roleRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
        _logger = logger;
    }

    public async Task<ApiResponse<LoginResponseDto>> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        var colaborador = await _colaboradorRepository.GetByCorreoAsync(request.Email);

        if (colaborador == null || colaborador.IsDeleted)
        {
            _logger.LogWarning("Intento de login fallido para email: {Email}", request.Email);
            return ApiResponse<LoginResponseDto>.Fail(
                "Credenciales invalidas.",
                new List<string> { "El email o la contraseña son incorrectos." }
            );
        }

        if (!_passwordHasher.VerifyPassword(request.Password, colaborador.PasswordHash))
        {
            _logger.LogWarning("Password incorrecto para email: {Email}", request.Email);
            return ApiResponse<LoginResponseDto>.Fail(
                "Credenciales invalidas.",
                new List<string> { "El email o la contraseña son incorrectos." }
            );
        }

        // Resolver nombres de roles
        var roleNames = new List<string>();
        foreach (var rolId in colaborador.RolIds)
        {
            var role = await _roleRepository.GetByIdAsync(rolId);
            if (role != null && !role.IsDeleted)
            {
                roleNames.Add(role.Name);
            }
        }

        if (roleNames.Count == 0)
        {
            return ApiResponse<LoginResponseDto>.Fail(
                "Usuario sin roles asignados.",
                new List<string> { "El usuario no tiene roles activos en el sistema." }
            );
        }

        var activeRole = roleNames.First();
        var token = _jwtTokenService.GenerateToken(
            colaborador.Id,
            colaborador.NombreCompleto,
            colaborador.Correo,
            roleNames,
            activeRole
        );

        var response = new LoginResponseDto
        {
            Token = token,
            User = new LoginUserDto
            {
                Id = colaborador.Id,
                Name = colaborador.NombreCompleto,
                Email = colaborador.Correo,
                Roles = roleNames
            }
        };

        _logger.LogInformation("Login exitoso para: {Email} con rol activo: {Role}", request.Email, activeRole);

        return ApiResponse<LoginResponseDto>.Ok(response, "Login exitoso.");
    }
}
