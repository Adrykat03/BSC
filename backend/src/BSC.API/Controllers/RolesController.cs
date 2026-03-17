using BSC.Application.Commands.CreateRole;
using BSC.Application.Commands.DeleteRole;
using BSC.Application.Commands.UpdateRole;
using BSC.Application.DTOs;
using BSC.Application.Queries.GetRoleById;
using BSC.Application.Queries.GetRoles;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BSC.API.Controllers;

/// <summary>
/// Controller para la gestion de roles del sistema.
/// </summary>
[ApiController]
[Authorize]
[Route("api/[controller]")]
public class RolesController : ControllerBase
{
    private readonly IMediator _mediator;

    public RolesController(IMediator mediator)
    {
        _mediator = mediator;
    }

    /// <summary>
    /// Obtiene la lista paginada de roles.
    /// </summary>
    /// <param name="page">Numero de pagina (default: 1).</param>
    /// <param name="pageSize">Cantidad de registros por pagina (default: 10, max: 100).</param>
    /// <returns>Lista paginada de roles.</returns>
    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<PaginatedResult<RoleDto>>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var query = new GetRolesQuery { Page = page, PageSize = pageSize };
        var result = await _mediator.Send(query);
        return Ok(result);
    }

    /// <summary>
    /// Obtiene un rol por su ID.
    /// </summary>
    /// <param name="id">ID del rol.</param>
    /// <returns>Datos del rol.</returns>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(ApiResponse<RoleDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<RoleDto>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(string id)
    {
        var query = new GetRoleByIdQuery { Id = id };
        var result = await _mediator.Send(query);

        if (!result.Success)
            return NotFound(result);

        return Ok(result);
    }

    /// <summary>
    /// Crea un nuevo rol.
    /// </summary>
    /// <param name="command">Datos del rol a crear.</param>
    /// <returns>Rol creado.</returns>
    [HttpPost]
    [ProducesResponseType(typeof(ApiResponse<RoleDto>), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ApiResponse<RoleDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<RoleDto>), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Create([FromBody] CreateRoleCommand command)
    {
        var result = await _mediator.Send(command);

        if (!result.Success)
            return Conflict(result);

        return CreatedAtAction(nameof(GetById), new { id = result.Data!.Id }, result);
    }

    /// <summary>
    /// Actualiza un rol existente.
    /// </summary>
    /// <param name="id">ID del rol a actualizar.</param>
    /// <param name="command">Datos actualizados del rol.</param>
    /// <returns>Rol actualizado.</returns>
    [HttpPut("{id}")]
    [ProducesResponseType(typeof(ApiResponse<RoleDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<RoleDto>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<RoleDto>), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ApiResponse<RoleDto>), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Update(string id, [FromBody] UpdateRoleCommand command)
    {
        command.Id = id;
        var result = await _mediator.Send(command);

        if (!result.Success)
        {
            if (result.Message.Contains("no encontrado", StringComparison.OrdinalIgnoreCase))
                return NotFound(result);

            return Conflict(result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Elimina un rol (soft delete).
    /// </summary>
    /// <param name="id">ID del rol a eliminar.</param>
    /// <returns>Confirmacion de eliminacion.</returns>
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(string id)
    {
        var command = new DeleteRoleCommand { Id = id };
        var result = await _mediator.Send(command);

        if (!result.Success)
            return NotFound(result);

        return NoContent();
    }
}
