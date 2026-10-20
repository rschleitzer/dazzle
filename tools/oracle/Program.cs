// tools/oracle: set a document with Dazzle.Pdf, the C# backend this port's PDF
// backend is held against (tools/oracle/compare.py).
//
//   dotnet run --project tools/oracle -- doc.xml style.dsl out.pdf out.json [font-directory]
//
// Writes the PDF and, as JSON, where every element with an ID begins
// ({"id": [page, x, y]}, page from 1, x and y in points from the top left).
// With a font directory the fonts come from its TrueType files, found by the
// family and style each file states -- as the port finds them in
// DAZZLE_FONTS -- so both sides set with the same files; without one,
// Dazzle.Pdf's own resolver looks in the system's font directories.

using System.Text;
using System.Text.Json;
using Dazzle.Pdf;
using PdfSharp.Fonts;

if (args.Length < 4)
{
    Console.Error.WriteLine("usage: oracle doc.xml style.dsl out.pdf out.json [font-directory]");
    return 2;
}
if (args.Length > 4)
    GlobalFontSettings.FontResolver = new DirectoryFontResolver(args[4]);

PdfResult result;
try
{
    result = DssslProcessor.GeneratePdfWithLocations(args[0], args[1]);
}
catch (Exception e)
{
    Console.Error.WriteLine("oracle: " + e.Message);
    return 1;
}
File.WriteAllBytes(args[2], result.Pdf);
var locations = result.Locations.ToDictionary(kv => kv.Key, kv => new[] { kv.Value.Page, kv.Value.X, kv.Value.Y });
File.WriteAllText(args[3], JsonSerializer.Serialize(locations));
return 0;

// The TrueType files of one directory by the family name and the style their
// `name` table states (name ids 1 and 2, or 16 and 17 where a family has more
// than four styles).
sealed class DirectoryFontResolver : IFontResolver
{
    readonly Dictionary<string, string> faces = new(StringComparer.OrdinalIgnoreCase);

    public DirectoryFontResolver(string directory)
    {
        foreach (var path in Directory.EnumerateFiles(directory))
        {
            if (!path.EndsWith(".ttf", StringComparison.OrdinalIgnoreCase))
                continue;
            var (family, style) = Names(File.ReadAllBytes(path));
            if (family is null)
                continue;
            var bold = style.Contains("Bold", StringComparison.OrdinalIgnoreCase);
            var italic = style.Contains("Italic", StringComparison.OrdinalIgnoreCase) || style.Contains("Oblique", StringComparison.OrdinalIgnoreCase);
            faces.TryAdd(Key(family, bold, italic), path);
            if (Environment.GetEnvironmentVariable("ORACLE_FONTS_TRACE") is not null)
                Console.Error.WriteLine($"oracle: {Key(family, bold, italic)} {Path.GetFileName(path)} ({style})");
        }
    }

    static string Key(string family, bool bold, bool italic) => family + "|" + (bold ? "b" : "") + (italic ? "i" : "");

    public FontResolverInfo? ResolveTypeface(string familyName, bool bold, bool italic)
    {
        if (faces.ContainsKey(Key(familyName, bold, italic)))
            return new FontResolverInfo(Key(familyName, bold, italic));
        // the regular face, made bold or italic by the PDF writer
        if (faces.ContainsKey(Key(familyName, false, false)))
            return new FontResolverInfo(Key(familyName, false, false), bold, italic);
        return null;
    }

    public byte[]? GetFont(string faceName) => faces.TryGetValue(faceName, out var path) ? File.ReadAllBytes(path) : null;

    static (string? family, string style) Names(byte[] f)
    {
        int U16(int at) => (f[at] << 8) | f[at + 1];
        int U32(int at) => (int)(((uint)f[at] << 24) | ((uint)f[at + 1] << 16) | ((uint)f[at + 2] << 8) | f[at + 3]);
        if (f.Length < 12)
            return (null, "");
        int tables = U16(4), name = -1;
        for (int i = 0; i < tables; i++)
        {
            int rec = 12 + 16 * i;
            if (Encoding.ASCII.GetString(f, rec, 4) == "name")
                name = U32(rec + 8);
        }
        if (name < 0)
            return (null, "");
        int count = U16(name + 2), strings = name + U16(name + 4);
        var found = new Dictionary<int, string>();
        for (int i = 0; i < count; i++)
        {
            int rec = name + 6 + 12 * i;
            int platform = U16(rec), language = U16(rec + 4), id = U16(rec + 6), length = U16(rec + 8), offset = U16(rec + 10);
            if (id != 1 && id != 2 && id != 16 && id != 17)
                continue;
            string text = platform == 3 || platform == 0
                ? Encoding.BigEndianUnicode.GetString(f, strings + offset, length)
                : Encoding.Latin1.GetString(f, strings + offset, length);
            // the English name of the Windows table (a font also states its
            // names in other languages: "Gras Italique"), else the first
            if ((platform == 3 && language == 0x0409) || !found.ContainsKey(id))
                found[id] = text;
        }
        var family = found.GetValueOrDefault(16) ?? found.GetValueOrDefault(1);
        var style = found.GetValueOrDefault(17) ?? found.GetValueOrDefault(2) ?? "";
        return (family, style);
    }
}
