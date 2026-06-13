using System.Text;
using System.Threading.RateLimiting;
using BSC.API.Middlewares;
using BSC.Application;
using BSC.Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using BSC.Domain.Interfaces;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// Configurar Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateLogger();

builder.Host.UseSerilog();

// Agregar servicios
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    });

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
    {
        Title = "BSC BackOffice API",
        Version = "v1",
        Description = "API del sistema de gestión BackOffice BSC"
    });

    // Configurar Swagger para soportar JWT Bearer
    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Ingrese el token JWT. Ejemplo: eyJhbGciOiJIUzI1NiIs..."
    });

    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("http://localhost:3000")
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

// JWT Authentication
//
// Hallazgo Security A02 - Fail-fast en produccion:
// appsettings.json incluye una clave default ("DEFAULT-DEV-KEY-...") para que dev arranque sin
// configuracion adicional. En produccion esa clave NO debe usarse: si JWT_SECRET_KEY no esta
// definida (o sigue siendo el default), abortamos el arranque para evitar que el sistema
// firme tokens con una clave conocida.
const string JwtDefaultDevKey = "DEFAULT-DEV-KEY-CHANGE-IN-PRODUCTION-32CHARS!";
var jwtKey = Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
    ?? builder.Configuration["JwtSettings:SecretKey"]
    ?? JwtDefaultDevKey;

if (builder.Environment.IsProduction() &&
    (string.IsNullOrWhiteSpace(jwtKey) || jwtKey == JwtDefaultDevKey || jwtKey.Length < 32))
{
    throw new InvalidOperationException(
        "JWT_SECRET_KEY no configurada en produccion. " +
        "Defina la variable de entorno JWT_SECRET_KEY con un secreto de al menos 32 caracteres " +
        "(o configure JwtSettings:SecretKey en un appsettings de produccion no commiteado). " +
        "El valor default de desarrollo NO esta permitido en produccion.");
}

var jwtIssuer = Environment.GetEnvironmentVariable("JWT_ISSUER")
    ?? builder.Configuration["JwtSettings:Issuer"]
    ?? "FlowPulse";
var jwtAudience = Environment.GetEnvironmentVariable("JWT_AUDIENCE")
    ?? builder.Configuration["JwtSettings:Audience"]
    ?? "FlowPulseApp";
var jwtExpirationMinutes = int.TryParse(
    builder.Configuration["JwtSettings:ExpirationMinutes"], out var expMin) ? expMin : 480;

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
        };
    });

builder.Services.AddAuthorization();

// Autorizacion por modulo (claim "modules" del JWT) via policies dinamicas.
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton<Microsoft.AspNetCore.Authorization.IAuthorizationPolicyProvider, BSC.API.Authorization.ModulePolicyProvider>();
builder.Services.AddSingleton<Microsoft.AspNetCore.Authorization.IAuthorizationHandler, BSC.API.Authorization.ModuleAuthorizationHandler>();

// Rate Limiting
builder.Services.AddRateLimiter(options =>
{
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 100,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));

    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        await context.HttpContext.Response.WriteAsJsonAsync(
            new { success = false, message = "Demasiadas solicitudes. Intente mas tarde." }, token);
    };
});

// Capas de la aplicación
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration, jwtKey, jwtIssuer, jwtAudience, jwtExpirationMinutes);

var app = builder.Build();

// Seed de configuracion BSC (crea documento si no existe)
using (var scope = app.Services.CreateScope())
{
    var bscConfigRepo = scope.ServiceProvider.GetRequiredService<IBscDashboardConfigRepository>();
    await bscConfigRepo.SeedIfEmptyAsync();
}

// Middleware de excepciones globales (primero en el pipeline)
app.UseMiddleware<ExceptionHandlingMiddleware>();

// Swagger solo en desarrollo
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "BSC BackOffice API v1");
    });
}

// Security headers
app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["X-XSS-Protection"] = "1; mode=block";
    context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    await next();
});

app.UseCors();

// Rate Limiting (antes de auth)
app.UseRateLimiter();

// Authentication & Authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

Log.Information("BSC Backend iniciado en puerto 8080");

await app.RunAsync();
