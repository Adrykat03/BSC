using BSC.Application.Features.Alertas.Commands.ChangeAlertaStatus;
using BSC.Application.Interfaces;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace BSC.Application.Tests.Features.Alertas;

/// <summary>
/// Tests del handler ChangeAlertaStatusHandler.
/// Cubre los 4 escenarios documentados en feature-alertas/ESTADO.md §5 P1.
/// </summary>
public class ChangeAlertaStatusHandlerTests
{
    private readonly Mock<IDabAlertasClient> _dabClient = new(MockBehavior.Strict);
    private readonly Mock<IAlertaHistorialRepository> _historialRepo = new(MockBehavior.Strict);

    private ChangeAlertaStatusHandler CreateHandler() =>
        new(_dabClient.Object, _historialRepo.Object, NullLogger<ChangeAlertaStatusHandler>.Instance);

    private static ChangeAlertaStatusCommand BuildCommand() => new()
    {
        IdNotificacion = 42,
        NuevoEstado = AlertaEstados.Resuelta,
        Comentario = "ok",
        UsuarioEmail = "user@bsc.com",
        UsuarioRol = "Gerente",
    };

    [Fact]
    public async Task Handle_DabOkAndMongoOk_ReturnsSuccessAndHistorialPersistidoTrue()
    {
        // Arrange
        var snapshot = new NotificacionConsolidadaSnapshot { IdNotificacion = 42, Estado = AlertaEstados.Activa };

        _dabClient.Setup(x => x.GetByIdAsync(42, It.IsAny<CancellationToken>()))
            .ReturnsAsync(snapshot);
        _dabClient.Setup(x => x.ActualizarAsync(42, It.IsAny<ActualizarNotificacionRequest>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _historialRepo.Setup(x => x.CreateAsync(It.IsAny<AlertaEstadoHistorial>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((AlertaEstadoHistorial e, CancellationToken _) => e);

        var handler = CreateHandler();

        // Act
        var result = await handler.Handle(BuildCommand(), CancellationToken.None);

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().NotBeNull();
        result.Data!.Success.Should().BeTrue();
        result.Data.HistorialPersistido.Should().BeTrue();

        _dabClient.VerifyAll();
        _historialRepo.VerifyAll();
    }

    [Fact]
    public async Task Handle_DabOkAndMongoFails_ReturnsSuccessAndHistorialPersistidoFalse()
    {
        // Arrange
        var snapshot = new NotificacionConsolidadaSnapshot { IdNotificacion = 42, Estado = AlertaEstados.Activa };

        _dabClient.Setup(x => x.GetByIdAsync(42, It.IsAny<CancellationToken>()))
            .ReturnsAsync(snapshot);
        _dabClient.Setup(x => x.ActualizarAsync(42, It.IsAny<ActualizarNotificacionRequest>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _historialRepo.Setup(x => x.CreateAsync(It.IsAny<AlertaEstadoHistorial>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Mongo down"));

        var handler = CreateHandler();

        // Act
        var result = await handler.Handle(BuildCommand(), CancellationToken.None);

        // Assert: handler NO debe propagar; debe responder Success=true con historialPersistido=false.
        result.Success.Should().BeTrue();
        result.Data.Should().NotBeNull();
        result.Data!.Success.Should().BeTrue();
        result.Data.HistorialPersistido.Should().BeFalse();
    }

    [Fact]
    public async Task Handle_DabGetByIdThrowsHttpRequestException_PropagatesException()
    {
        // Arrange
        _dabClient.Setup(x => x.GetByIdAsync(42, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("DAB unreachable"));

        var handler = CreateHandler();

        // Act
        var act = async () => await handler.Handle(BuildCommand(), CancellationToken.None);

        // Assert: HttpRequestException se propaga (-> middleware -> 500). Mongo no se toca.
        await act.Should().ThrowAsync<HttpRequestException>().WithMessage("DAB unreachable");
        _historialRepo.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Handle_DabGetByIdReturnsNull_ReturnsNotFoundFailure()
    {
        // Arrange
        _dabClient.Setup(x => x.GetByIdAsync(42, It.IsAny<CancellationToken>()))
            .ReturnsAsync((NotificacionConsolidadaSnapshot?)null);

        var handler = CreateHandler();

        // Act
        var result = await handler.Handle(BuildCommand(), CancellationToken.None);

        // Assert
        result.Success.Should().BeFalse();
        result.Message.Should().Contain("no encontrada");
        result.Data.Should().BeNull();

        // No se debe haber llamado a ActualizarAsync ni a CreateAsync
        _dabClient.Verify(x => x.ActualizarAsync(It.IsAny<long>(), It.IsAny<ActualizarNotificacionRequest>(), It.IsAny<CancellationToken>()), Times.Never);
        _historialRepo.VerifyNoOtherCalls();
    }
}
