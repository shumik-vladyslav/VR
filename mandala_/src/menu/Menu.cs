
using Godot;


namespace Mandala.menu;


public partial class Menu : CanvasLayer
{
	private Button _dattaButton = default!;
	private Button _mandalaButton = default!;
	private Button _teurgia1Button = default!;
	private Button _exitButton = default!;
	private Button _selectAudioButton = default!;
	private Button _clearPlaylistButton = default!;
	private CheckButton _fullScreen = default!;
	private CheckButton _autoplay = default!;
	private OptionButton _resolutions = default!;
	private Panel _menuLayer = default!;
	private SettingsManager _settingsManager;
	private FileDialog _fileDialog = default!;
	private HBoxContainer _playControl;
	private AudioManager _audioManager = default!;
	private Button _playButton;
	private Button _pauseButton;
	private Button _stopButton;
	private Button _nextButton;
	private Button _mainMenuBtn;

	[Export] public bool IsStartDattaShown { get; set; }
	[Export] public bool IsStartMandalaShown { get; set; }
	[Export] public bool IsStartTeurgia1Shown { get; set; }

	[Signal]
	public delegate void OpenEventHandler();
	
	[Signal]
	public delegate void CloseEventHandler();
	
	public bool IsOpened => _menuLayer.Visible;
	
	public override void _Ready()
	{
		base._Ready();
		_settingsManager = SettingsManager.GetInstance();
		_menuLayer = GetNode<Panel>("%Panel");
		_dattaButton = GetNode<Button>("%DattaBtn");
		_mandalaButton = GetNode<Button>("%MandalaBtn");
		_teurgia1Button = GetNode<Button>("%Teurgia1Btn");
		_mainMenuBtn = GetNode<Button>("%MainMenuBtn");
		
		_dattaButton.Visible = IsStartDattaShown;
		//_mainMenuBtn.Visible = !IsStartDattaShown;
		_mandalaButton.Visible = IsStartMandalaShown;
		_teurgia1Button.Visible = IsStartTeurgia1Shown;
		_clearPlaylistButton = GetNode<Button>("%ClearPlaylistBtn");
		_selectAudioButton = GetNode<Button>("%SelectAudioBtn");
		_exitButton = GetNode<Button>("%ExitBtn");
		_resolutions = GetNode<OptionButton>("%Resolutions");
		_fullScreen = GetNode<CheckButton>("%FullScreenChb");
		_autoplay = GetNode<CheckButton>("%AutoPlayChb");
		_audioManager = AudioManager.GetInstance();
		_playControl = GetNode<HBoxContainer>("%PlayControl");
		
		_playButton = GetNode<Button>("%Play");
		_pauseButton = GetNode<Button>("%Pause");
		_stopButton = GetNode<Button>("%Stop");
		_nextButton = GetNode<Button>("%Next");
		
		_fileDialog = GetNode<FileDialog>("%FileDialog");
		// Настройка FileDialog
		_fileDialog.Filters = new[] { "*.mp3" }; // Разрешаем только MP3 файлы
		_fileDialog.FilesSelected += OnFilesSelected;
		
		_dattaButton.Pressed += DattaButtonOnPressed;
		_mandalaButton.Pressed += MandalaButtonOnPressed;
		_teurgia1Button.Pressed += Teurgia1ButtonOnPressed;
		_selectAudioButton.Pressed += SelectAudioButtonOnPressed;
		_exitButton.Pressed += ()=> GetTree().Quit();
		_fullScreen.Toggled += FullScreenToggled;
		_autoplay.Toggled += AutoplayOnToggled;
		_clearPlaylistButton.Pressed += ClearPlaylistButtonOnPressed;
		_playButton.Pressed += PlayButtonOnPressed;
		_stopButton.Pressed += StopButtonOnPressed;
		_nextButton.Pressed += NextButtonOnPressed;
		_pauseButton.Pressed += PauseButtonOnPressed;
		LoadStates();
		HidePlayerControls();
		_mainMenuBtn.Pressed += MainMenuBtnOnPressed;
		
		// настройки сохраняются при выходе из игры в SettingsManager._ExitTree
	}

	private void MainMenuBtnOnPressed()
	{
		HideMenu();
		GetTree().ChangeSceneToFile("res://src/app/App.tscn");
	}

	private void PauseButtonOnPressed()
	{
		if (_audioManager.IsPaused)
		{
			return;
		}
		_pauseButton.Disabled = true;
		_playButton.Disabled = false;
		_audioManager.Pause();
	}

	private void NextButtonOnPressed()
	{
		_pauseButton.Disabled = false;
		_playButton.Disabled = true;
		_audioManager.Next();
	}

	private void StopButtonOnPressed()
	{
		_pauseButton.Disabled = true;
		_playButton.Disabled = false;
		_audioManager.Stop();
	}

	private void PlayButtonOnPressed()
	{
		if (_audioManager.IsPaused)
		{
			_audioManager.Resume();
			_pauseButton.Disabled = false;
			_playButton.Disabled = true;
			return;
		}
		_pauseButton.Disabled = false;
		_playButton.Disabled = true;
		_audioManager.Play();
	}

	public void ShowPlayerControls()
	{
		LoadPauseState();
		_playControl.Visible = true;
	}
	
	public void HidePlayerControls()
	{
		_playControl.Visible = false;
	}

	private void ClearPlaylistButtonOnPressed()
	{
		_audioManager.ClearPlayList();
		_audioManager.AddPlayList(new string[]{"res://audio/OmDram.mp3"});
	}

	private void OnFilesSelected(string[] paths)
	{
		_audioManager.AddPlayList(paths);
	}

	private void LoadStates()
	{
		_fullScreen.ButtonPressed = _settingsManager.IsFullScreen;
		_autoplay.ButtonPressed = _settingsManager.IsAutoplay;
		LoadPauseState();
	}

	private void LoadPauseState()
	{
		if (_settingsManager.IsAutoplay)
		{
			_pauseButton.Disabled = false;
			_playButton.Disabled = true;
		}
		else
		{
			_pauseButton.Disabled = true;
			_playButton.Disabled = false;
		}
	}

	private void SelectAudioButtonOnPressed()
	{
		_fileDialog.PopupCentered();
	}

	private void AutoplayOnToggled(bool buttonPressed)
	{
		SettingsManager.GetInstance().IsAutoplay = buttonPressed;
	}

	private void FullScreenToggled(bool buttonPressed)
	{
		SettingsManager.GetInstance().SetFullscreen(buttonPressed);
	}

	private void DattaButtonOnPressed()
	{
		HideMenu();
		GetTree().ChangeSceneToFile("res://main.tscn");
	}
	
	private void MandalaButtonOnPressed()
	{
		HideMenu();
		GetTree().ChangeSceneToFile("res://mandala5.tscn");
	}

	private void Teurgia1ButtonOnPressed()
	{
		HideMenu();
		GetTree().ChangeSceneToFile("res://teurgia1.tscn");
	}

	public override void _ExitTree()
	{
		base._ExitTree();
		_dattaButton.Pressed -= DattaButtonOnPressed;
		_teurgia1Button.Pressed -= Teurgia1ButtonOnPressed;
		_fullScreen.Toggled -= FullScreenToggled;
		_fileDialog.FilesSelected -= OnFilesSelected;
		_selectAudioButton.Pressed -= SelectAudioButtonOnPressed;
		_autoplay.Toggled -= AutoplayOnToggled;
	}

	public void ShowMenu()
	{
		_menuLayer.Visible = true;
		EmitSignal(SignalName.Open);
	}
	public void HideMenu()
	{
		_menuLayer.Visible = false;
		EmitSignal(SignalName.Close);
	}
	
	public void ToggleMenu()
	{
		if (_menuLayer.Visible)
		{
			HideMenu();
		}
		else
		{
			ShowMenu();
		}
	}
}
