using BSC.Application.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace BSC.API.Controllers;

/// <summary>
/// Controller para verificar el estado del servicio.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    /// <summary>
    /// Verifica que el backend esté activo.
    /// </summary>
    /// <returns>Estado del servicio.</returns>
    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    public IActionResult Get()
    {
        var response = ApiResponse<object>.Ok(null, "Backend activo");
        return Ok(response);
    }
}
