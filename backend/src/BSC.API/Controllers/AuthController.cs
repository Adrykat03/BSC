using System.Security.Claims;
using System.Text.Json;
using BSC.Application.Commands.Login;
using BSC.Application.Commands.SwitchRole;
using BSC.Application.DTOs;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BSC.API.Controllers;

/// <summary>
/// Controller para autenticacion y gestion de sesion.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IMediator _mediator;

    public AuthController(IMediator mediator)
    {
        _mediator = mediator;
    }

    /// <summary>
    /// Autentica un usuario con email y password. Retorna un JWT token.
    /// </summary>
    /// <param name="request">Credenciales de login.</param>
    /// <returns>Token JWT y datos del usuario.</returns>
    [AllowAnonymous]
    [HttpPost("login")]
    [ProducesResponseType(typeof(ApiResponse<LoginResponseDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<LoginResponseDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<LoginResponseDto>), StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Login([FromBody] LoginRequestDto request)
    {
        var command = new LoginCommand
        {
            Email = request.Email,
            Password = request.Password
        };

        var result = await _mediator.Send(command);

        if (!result.Success)
            return Unauthorized(result);

        return Ok(result);
    }

    /// <summary>
    /// Cambia el rol activo del usuario autenticado. Genera un nuevo JWT con el rol especificado.
    /// </summary>
    /// <param name="request">Rol al que se desea cambiar.</param>
    /// <returns>Nuevo token JWT con el rol activo actualizado.</returns>
    [Authorize]
    [HttpPost("switch-role")]
    [ProducesResponseType(typeof(ApiResponse<LoginResponseDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<LoginResponseDto>), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SwitchRole([FromBody] SwitchRoleRequestDto request)
    {
        var rolesJson = User.FindFirstValue("roles") ?? "[]";
        var roles = JsonSerializer.Deserialize<List<string>>(rolesJson) ?? new List<string>();

        var command = new SwitchRoleCommand
        {
            Role = request.Role,
            UserId = GetUserId(),
            UserName = GetUserName(),
            UserEmail = GetUserEmail(),
            UserRoles = roles
        };

        var result = await _mediator.Send(command);

        if (!result.Success)
            return BadRequest(result);

        return Ok(result);
    }

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? string.Empty;
    private string GetUserName() => User.FindFirstValue(ClaimTypes.Name) ?? string.Empty;
    private string GetUserEmail() => User.FindFirstValue(ClaimTypes.Email) ?? string.Empty;
}
