using BSC.Application.Features.Alertas.Queries.GetAlertaHistorial;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace BSC.Application.Tests.Features.Alertas;

/// <summary>
/// Test minimo (happy path) del handler GetAlertaHistorialHandler.
/// </summary>
public class GetAlertaHistorialHandlerTests
{
    [Fact]
    public async Task Handle_HappyPath_ReturnsMappedItemsOrderedFromRepository()
    {
        // Arrange
        var fechaReciente = new DateTime(2026, 5, 10, 10, 0, 0, DateTimeKind.Utc);
        var fechaAntigua = new DateTime(2026, 5, 1, 10, 0, 0, DateTimeKind.Utc);

        var registros = new List<AlertaEstadoHistorial>
        {
            new()
            {
                Id = "65f000000000000000000001",
                IdNotificacion = 42,
                EstadoAnterior = AlertaEstados.Activa,
                EstadoNuevo = AlertaEstados.Resuelta,
                Comentario = "resuelta",
                UsuarioEmail = "user@bsc.com",
                UsuarioRol = "Gerente",
                Fecha = fechaReciente,
            },
            new()
            {
                Id = "65f000000000000000000002",
                IdNotificacion = 42,
                EstadoAnterior = AlertaEstados.Activa,
                EstadoNuevo = AlertaEstados.EnProceso,
                Comentario = null,
                UsuarioEmail = "user@bsc.com",
                UsuarioRol = "Lider",
                Fecha = fechaAntigua,
            },
        };

        var repo = new Mock<IAlertaHistorialRepository>(MockBehavior.Strict);
        repo.Setup(x => x.GetByIdNotificacionAsync(42, It.IsAny<CancellationToken>()))
            .ReturnsAsync(registros);

        var handler = new GetAlertaHistorialHandler(repo.Object, NullLogger<GetAlertaHistorialHandler>.Instance);

        // Act
        var result = await handler.Handle(new GetAlertaHistorialQuery { IdNotificacion = 42 }, CancellationToken.None);

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().NotBeNull();
        result.Data!.Items.Should().HaveCount(2);
        result.Data.Items[0].IdNotificacion.Should().Be(42);
        result.Data.Items[0].EstadoNuevo.Should().Be(AlertaEstados.Resuelta);
        result.Data.Items[1].EstadoNuevo.Should().Be(AlertaEstados.EnProceso);

        repo.VerifyAll();
    }
}
