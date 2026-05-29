using System.Globalization;
using System.Text;
using MoonBit2CSharp.Backend;
using MoonBit2CSharp.VNext.Backend;

if (args.Length >= 3 && args[0] == "--vnext")
{
    var vnextInputPath = Path.GetFullPath(args[1]);
    var vnextOutputPath = Path.GetFullPath(args[2]);
    Directory.CreateDirectory(Path.GetDirectoryName(vnextOutputPath) ?? ".");
    WriteAllTextIfChanged(vnextOutputPath, VNextBackend.Emit(File.ReadAllText(vnextInputPath)));
    Console.WriteLine(vnextOutputPath);
}

static void WriteAllTextIfChanged(string path, string contents)
{
    if (File.Exists(path) && File.ReadAllText(path) == contents)
        return;

    for (var attempt = 0; ; attempt++)
        try
        {
            File.WriteAllText(path, contents);
            return;
        }
        catch (IOException) when (attempt < 5)
        {
            Thread.Sleep(100);
        }
}
