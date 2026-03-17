namespace BSC.Application.Common;

/// <summary>
/// Helper para validacion de archivos mediante magic bytes.
/// Verifica que el contenido real del archivo coincida con la extension declarada.
/// </summary>
public static class FileValidationHelper
{
    private static readonly Dictionary<string, byte[][]> FileSignatures = new()
    {
        { ".pdf", new[] { new byte[] { 0x25, 0x50, 0x44, 0x46 } } },           // %PDF
        { ".jpg", new[] { new byte[] { 0xFF, 0xD8, 0xFF } } },
        { ".jpeg", new[] { new byte[] { 0xFF, 0xD8, 0xFF } } },
        { ".png", new[] { new byte[] { 0x89, 0x50, 0x4E, 0x47 } } },           // .PNG
        { ".gif", new[] { new byte[] { 0x47, 0x49, 0x46 } } },                 // GIF
        { ".doc", new[] { new byte[] { 0xD0, 0xCF, 0x11, 0xE0 } } },           // MS Office
        { ".docx", new[] { new byte[] { 0x50, 0x4B, 0x03, 0x04 } } },          // ZIP (OOXML)
        { ".xlsx", new[] { new byte[] { 0x50, 0x4B, 0x03, 0x04 } } },
        { ".xls", new[] { new byte[] { 0xD0, 0xCF, 0x11, 0xE0 } } },
        { ".zip", new[] { new byte[] { 0x50, 0x4B, 0x03, 0x04 } } },
    };

    /// <summary>
    /// Valida que los magic bytes del archivo coincidan con la extension declarada.
    /// Si no se tiene una firma registrada para la extension, se permite por defecto.
    /// </summary>
    /// <param name="fileStream">Stream del archivo a validar.</param>
    /// <param name="extension">Extension del archivo (ej: ".pdf").</param>
    /// <returns>True si los magic bytes coinciden o no se tiene firma registrada.</returns>
    public static bool ValidateMagicBytes(Stream fileStream, string extension)
    {
        if (!FileSignatures.TryGetValue(extension.ToLowerInvariant(), out var signatures))
            return true; // Si no tenemos signature para esta extension, permitir

        var headerBytes = new byte[8];
        fileStream.Position = 0;
        fileStream.Read(headerBytes, 0, headerBytes.Length);
        fileStream.Position = 0; // Reset stream position

        return signatures.Any(sig => headerBytes.Take(sig.Length).SequenceEqual(sig));
    }
}
