using System;
using System.Collections.Generic;
using System.Text;
using Godot;

namespace Mandala;

public partial class SettingsManager : Node
{
    private ConfigFile _configFile;

    public override void _Ready()
    {
        base._Ready();
        _configFile = new ConfigFile();
        Error err = _configFile.Load("user://settings.cfg");
        if (err != Error.Ok)
        {
            SetDefaultSettings();
        }
        
        LoadSettings();
    }

    public bool IsFullScreen
    {
        get => _configFile.GetValue("Settings", "full_screen", true).AsBool();
        set => _configFile.SetValue("Settings", "full_screen", value);
    }
    
    public bool IsAutoplay
    {
        get => _configFile.GetValue("Settings", "autoplay", true).AsBool();
        set => _configFile.SetValue("Settings", "autoplay", value);
    }

    public float MusicVolume
    {
        get => _configFile.GetValue("Settings", "music_volume", 0).AsSingle();
        set => _configFile.SetValue("Settings", "music_volume", value);
    }
    public List<string> PlayList
    {
        get => ConvertFromBase64(_configFile.GetValue("Settings", "playlist", ConvertToBase64(new List<string>())).AsString());
        set => _configFile.SetValue("Settings", "playlist", ConvertToBase64(value));
    }

    private void SetDefaultSettings()
    {
        _configFile.SetValue("Settings", "full_screen", true);
        _configFile.SetValue("Settings", "autoplay", true);
        _configFile.SetValue("Settings", "music_volume", 0);
        _configFile.SetValue("Settings", "playlist", ConvertToBase64(new List<string>()));
        SaveSettings();
    }

    public void SaveSettings()
    {
        _configFile.Save("user://settings.cfg");
    }

    public void LoadSettings()
    {
        SetFullscreen(IsFullScreen);
    }

    public void SetFullscreen(bool fullscreen)
    {
        if (fullscreen)
        {
            Vector2I screenSize = DisplayServer.ScreenGetSize(DisplayServer.WindowGetCurrentScreen());
            DisplayServer.WindowSetSize(screenSize);
        }
       
        DisplayServer.WindowSetMode(
            fullscreen
                ? DisplayServer.WindowMode.Fullscreen
                : DisplayServer.WindowMode.Windowed);
        
        if (!fullscreen)
        {
            Vector2I screenSize = DisplayServer.ScreenGetSize(DisplayServer.WindowGetCurrentScreen());
            DisplayServer.WindowSetSize(screenSize);
        }
        IsFullScreen = fullscreen;
    }

    public static SettingsManager GetInstance()
    {
        return ((SceneTree)Engine.GetMainLoop()).Root.GetNode<SettingsManager>("/root/SettingsManager");
    }

    public override void _ExitTree()
    {
        base._ExitTree();
        SaveSettings();
    }
    
    // Метод для конвертации списка строк в строку Base64
    private static string ConvertToBase64(List<string> strings)
    {
        if (strings == null || strings.Count == 0)
        {
            return string.Empty;
        }

        // Соединяем строки с разделителем и конвертируем в Base64
        string combined = string.Join("\n", strings);
        byte[] bytes = Encoding.UTF8.GetBytes(combined);
        return Convert.ToBase64String(bytes);
    }

    // Метод для конвертации строки Base64 обратно в список строк
    private static List<string> ConvertFromBase64(string base64String)
    {
        if (string.IsNullOrEmpty(base64String))
        {
            return new List<string>();
        }

        // Декодируем Base64 в обычную строку и разделяем по строкам
        byte[] bytes = Convert.FromBase64String(base64String);
        string decoded = Encoding.UTF8.GetString(bytes);
        return new List<string>(decoded.Split('\n'));
    }
}