using System.Collections.Generic;
using Godot;

namespace Mandala;

public partial class AudioManager: Node
{
    private AudioStreamPlayer _player;
    private List<string> _playList = new();
    private int _currentSongIndex = -1;
    private SettingsManager _settingsManager;
    private float _playbackPosition = 0;
    
    public override void _Ready()
    {
        base._Ready();
        _player = GetNode<AudioStreamPlayer>("%Player");
        _settingsManager = SettingsManager.GetInstance();
        if (_settingsManager.PlayList.Count != 0)
        {
            _playList.AddRange(_settingsManager.PlayList);
        }
        else
        {
            _playList.Add("res://audio/OmDram.mp3");
        }
    }

    public bool IsPlaying => _player.IsPlaying();
    public bool IsPaused => !_player.IsPlaying() && _playbackPosition > 0.001;
    
    public void AddPlayList(string[] paths)
    {
        _playList.Remove("res://audio/OmDram.mp3");
        _playList.AddRange(paths);
        SavePlaylist();
    }

    public void ClearPlayList()
    {
        if (_player.IsPlaying())
        {
            _player.Stop();
        }
        _playList.Clear();
        _currentSongIndex = -1;
        SavePlaylist();
    }
    public void Play()
    {
        _playbackPosition = 0;
        if (!_player.IsPlaying() && _playList.Count > 0)
        {
            _player.VolumeDb = _settingsManager.MusicVolume;
            _currentSongIndex = 0;
            _player.Stream = LoadMp3(_playList[_currentSongIndex]);
            _player.Play();
        }
    }

    public void Resume()
    {
        if (!_player.IsPlaying() && _playList.Count > 0)
        {
            _player.VolumeDb = _settingsManager.MusicVolume; 
            if (_playbackPosition > 0.001)
            {
                _player.Play(_playbackPosition);
            }
            else
            {
                _player.Play();
            }
        } 
    }

    public void Pause()
    {
        if (_player.IsPlaying())
        {
            _playbackPosition = _player.GetPlaybackPosition();
            _player.Stop();
        }
    }

    public void Stop()
    {
        _playbackPosition = 0;
        _currentSongIndex = -1;
        if (_player.IsPlaying())
        {
            _player.Stop();
        }
    }

    public void Next()
    {
        _playbackPosition = 0;
        if (_player.IsPlaying())
        {
            _player.Stop();
        }

        if (_currentSongIndex + 1 >= _playList.Count)
        {
            _currentSongIndex = 0;
        }
        else
        {
            _currentSongIndex ++;
        }
       
        _player.Stream = LoadMp3(_playList[_currentSongIndex]);
        _player.Play();
    }
    
    private AudioStreamMP3 LoadMp3(string path)
    {
        AudioStreamMP3 sound;
        if (path.Contains("res://"))
        {
            sound = GD.Load<AudioStreamMP3>(path);
        }
        else
        {
            using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
            sound = new AudioStreamMP3();
            sound.Data = file.GetBuffer((long)file.GetLength());
        }
        
        return sound;
    }

    private void SavePlaylist()
    {
        _settingsManager.PlayList = _playList;
        _settingsManager.SaveSettings();
    }

    public static AudioManager GetInstance()
    {
        return ((SceneTree)Engine.GetMainLoop()).Root.GetNode<AudioManager>("/root/AudioManager");
    }
}