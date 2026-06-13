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

        // Resolver roles (se conservan las entidades para emitir los modulos del rol activo)
        var resolvedRoles = new List<Domain.Entities.Role>();
        foreach (var rolId in colaborador.RolIds)
        {
            var role = await _roleRepository.GetByIdAsync(rolId);
            if (role != null && !role.IsDeleted)
            {
                resolvedRoles.Add(role);
            }
        }

        var roleNames = resolvedRoles.Select(r => r.Name).ToList();

        if (roleNames.Count == 0)
        {
            return ApiResponse<LoginResponseDto>.Fail(
                "Usuario sin roles asignados.",
                new List<string> { "El usuario no tiene roles activos en el sistema." }
            );
        }

        // Track last login
        var previousLogin = colaborador.LastLoginAt;
        await _colaboradorRepository.UpdateLastLoginAsync(colaborador.Id, DateTime.UtcNow);

        // Default to highest-privilege role: Administrador > Gerente > Lider > Colaborador
        var rolePriority = new[] { "Administrador", "Gerente", "Lider", "Colaborador" };
        var activeRole = rolePriority.FirstOrDefault(r => roleNames.Contains(r)) ?? roleNames.First();

        // Los modulos se calculan a partir del ROL ACTIVO (no la union de roles).
        var activeRoleEntity = resolvedRoles.FirstOrDefault(r => r.Name == activeRole);
        var modules = activeRoleEntity?.Modules ?? new List<string>();

        var token = _jwtTokenService.GenerateToken(
            colaborador.Id,
            colaborador.NombreCompleto,
            colaborador.Correo,
            roleNames,
            activeRole,
            modules
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
            },
            LastLoginAt = previousLogin
        };

        _logger.LogInformation("Login exitoso para: {Email} con rol activo: {Role}", request.Email, activeRole);

        return ApiResponse<LoginResponseDto>.Ok(response, "Login exitoso.");
    }
}
