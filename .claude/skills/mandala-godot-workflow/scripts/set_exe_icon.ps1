# Ставит значок на собранный .exe средствами Windows, без rcedit (Godot без него значок не меняет).
#   powershell -File set_exe_icon.ps1 <путь к exe> <путь к ico>
# Запускать после каждого экспорта: Godot пишет exe заново со своим значком.
param([string]$Exe, [string]$Ico)
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class ExeIcon {
    delegate bool EnumName(IntPtr module, IntPtr type, IntPtr name, IntPtr param);
    delegate bool EnumLang(IntPtr module, IntPtr type, IntPtr name, ushort lang, IntPtr param);
    [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr LoadLibraryExW(string file, IntPtr h, uint flags);
    [DllImport("kernel32")] static extern bool FreeLibrary(IntPtr h);
    [DllImport("kernel32", CharSet = CharSet.Unicode)] static extern bool EnumResourceNamesW(IntPtr h, IntPtr type, EnumName f, IntPtr p);
    [DllImport("kernel32", CharSet = CharSet.Unicode)] static extern bool EnumResourceLanguagesW(IntPtr h, IntPtr type, IntPtr name, EnumLang f, IntPtr p);
    [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr BeginUpdateResourceW(string file, bool deleteAll);
    [DllImport("kernel32", SetLastError = true)] static extern bool UpdateResourceW(IntPtr h, IntPtr type, IntPtr name, ushort lang, byte[] data, uint size);
    [DllImport("kernel32", SetLastError = true)] static extern bool EndUpdateResourceW(IntPtr h, bool discard);
    static readonly IntPtr RT_ICON = (IntPtr)3, RT_GROUP_ICON = (IntPtr)14;

    public static string Apply(string exe, byte[] ico) {
        // где у программы значок: первая группа значков и её язык; отдельные картинки значков — их номера заняты
        IntPtr module = LoadLibraryExW(exe, IntPtr.Zero, 2);
        if (module == IntPtr.Zero) throw new Exception("не открылся exe: " + Marshal.GetLastWin32Error());
        string groupName = null; int groupId = 0; ushort lang = 0;
        EnumName onGroup = (m, t, n, p) => {
            if ((long)n >> 16 == 0) groupId = (int)n; else groupName = Marshal.PtrToStringUni(n);
            EnumResourceLanguagesW(m, t, n, (m2, t2, n2, l, p2) => { lang = l; return false; }, IntPtr.Zero);
            return false;
        };
        EnumResourceNamesW(module, RT_GROUP_ICON, onGroup, IntPtr.Zero);
        int maxIcon = 0;
        EnumName onIcon = (m, t, n, p) => { if ((long)n >> 16 == 0) maxIcon = Math.Max(maxIcon, (int)n); return true; };
        EnumResourceNamesW(module, RT_ICON, onIcon, IntPtr.Zero);
        FreeLibrary(module);

        int count = BitConverter.ToUInt16(ico, 4);
        byte[] group = new byte[6 + 14 * count];
        Array.Copy(ico, 0, group, 0, 6);
        IntPtr update = BeginUpdateResourceW(exe, false);
        if (update == IntPtr.Zero) throw new Exception("exe занят: " + Marshal.GetLastWin32Error());
        for (int i = 0; i < count; i++) {
            int entry = 6 + 16 * i;
            int size = BitConverter.ToInt32(ico, entry + 8), offset = BitConverter.ToInt32(ico, entry + 12);
            byte[] image = new byte[size];
            Array.Copy(ico, offset, image, 0, size);
            int id = maxIcon + 1 + i;
            if (!UpdateResourceW(update, RT_ICON, (IntPtr)id, lang, image, (uint)size)) throw new Exception("значок: " + Marshal.GetLastWin32Error());
            Array.Copy(ico, entry, group, 6 + 14 * i, 12);
            BitConverter.GetBytes((ushort)id).CopyTo(group, 6 + 14 * i + 12);
        }
        IntPtr nameMem = groupName != null ? Marshal.StringToHGlobalUni(groupName) : (IntPtr)groupId;
        if (!UpdateResourceW(update, RT_GROUP_ICON, nameMem, lang, group, (uint)group.Length)) throw new Exception("группа: " + Marshal.GetLastWin32Error());
        if (!EndUpdateResourceW(update, false)) throw new Exception("запись: " + Marshal.GetLastWin32Error());
        return "группа " + (groupName ?? groupId.ToString()) + ", язык " + lang + ", картинок " + count;
    }
}
'@

[ExeIcon]::Apply((Resolve-Path $Exe).Path, [IO.File]::ReadAllBytes((Resolve-Path $Ico).Path))
