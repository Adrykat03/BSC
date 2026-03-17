using BSC.Application.DTOs;
using BSC.Application.Features.Colaboradores.Commands.Create;
using BSC.Application.Features.Colaboradores.Commands.Delete;
using BSC.Application.Features.Colaboradores.Commands.Update;
using BSC.Application.Features.Colaboradores.Queries.GetAll;
using BSC.Application.Features.Colaboradores.Queries.GetById;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BSC.API.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class ColaboradoresController : ControllerBase
{
    private readonly IMediator _mediator;

    public ColaboradoresController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<ColaboradorDto>>>> GetAll()
    {
        var result = await _mediator.Send(new GetAllColaboradoresQuery());
        return Ok(result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ApiResponse<ColaboradorDto>>> GetById(string id)
    {
        var result = await _mediator.Send(new GetColaboradorByIdQuery { Id = id });

        if (!result.Success)
            return NotFound(result);

        return Ok(result);
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<ColaboradorDto>>> Create([FromBody] CreateColaboradorCommand command)
    {
        var result = await _mediator.Send(command);

        if (!result.Success)
            return BadRequest(result);

        return CreatedAtAction(nameof(GetById), new { id = result.Data?.Id }, result);
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<ApiResponse<ColaboradorDto>>> Update(string id, [FromBody] UpdateColaboradorCommand command)
    {
        command.Id = id;
        var result = await _mediator.Send(command);

        if (!result.Success)
            return BadRequest(result);

        return Ok(result);
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<bool>>> Delete(string id)
    {
        var result = await _mediator.Send(new DeleteColaboradorCommand { Id = id });

        if (!result.Success)
            return NotFound(result);

        return Ok(result);
    }
}
