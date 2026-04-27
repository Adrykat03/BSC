using BSC.Application.Interfaces;
using MediatR;

namespace BSC.Application.Queries.DescargarAdjunto;

public class DescargarAdjuntoQueryHandler : IRequestHandler<DescargarAdjuntoQuery, AdjuntoDescargado>
{
    private readonly IUtileriasPayrollClient _client;

    public DescargarAdjuntoQueryHandler(IUtileriasPayrollClient client)
    {
        _client = client;
    }

    public Task<AdjuntoDescargado> Handle(DescargarAdjuntoQuery request, CancellationToken cancellationToken)
    {
        return _client.DescargarAsync(request.Ruta, request.NombreArchivo, cancellationToken);
    }
}
