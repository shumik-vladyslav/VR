using Godot;
using Mandala.menu;

namespace Mandala;

public partial class Scene: Node3D
{
    [Export] private float MaxPitchHighAngle = 60.0f; // Максимальный угол наклона по X
    [Export] private float MaxPitchLowAngle = -30.0f; // Максимальный угол наклона по X
    [Export] private float RotationSpeed = 0.05f; // Скорость вращения
    [Export] private float ZoomSpeedMouseWheel = 5f; // Скорость зума
    [Export] private float ZoomSpeedMouseMove = 0.01f; // Скорость зума
    [Export] private float MinZoomDistance = 2.5f; // Минимальная дистанция зума
    [Export] private float MaxZoomDistance = 4.5f; // Максимальная дистанция зума
    
    private Menu _menu;
    private bool _isMouseCaptured = true; // Флаг захвата мыши
    private float _pitch = 0.0f; // Для ограничения поворота по X
    private AudioManager _audioManager;
    private SettingsManager _settingsManager;
    private Node3D _cameraOrigin;
    private Camera3D _camera;
    private double _delta;

    public override void _Ready()
    {
        base._Ready();
        _audioManager = AudioManager.GetInstance();
        _settingsManager = SettingsManager.GetInstance();
        _cameraOrigin = GetNode<Node3D>("%CameraOrigin");
        _menu = GetNode<Menu>("%Menu");
        _camera = GetNode<Camera3D>("%MainCamera");
        
        _menu.HideMenu();
        Input.MouseMode = Input.MouseModeEnum.Captured;
        _menu.Open += () =>
        {
            Input.MouseMode = Input.MouseModeEnum.Visible;
            _isMouseCaptured = false;
        };
        _menu.Close += () =>
        {
            Input.MouseMode = Input.MouseModeEnum.Captured;
            _isMouseCaptured = true;
        };
        
        _menu.ShowPlayerControls();
        CallDeferred("PlayAudio");
    }

    public override void _PhysicsProcess(double delta)
    {
        base._PhysicsProcess(delta);
        _delta = delta;

        // Зум движением
        if (Input.IsMouseButtonPressed(MouseButton.Left) || Input.IsMouseButtonPressed(MouseButton.Right))
        {
            Vector2 lastMouseVelocity = Input.GetLastMouseVelocity();
            Vector3 newPosition = _camera.Position;
            newPosition.Z = Mathf.Clamp(newPosition.Z - lastMouseVelocity.Y * ZoomSpeedMouseMove * (float)delta, MinZoomDistance, MaxZoomDistance);
            _camera.Position = newPosition;
        }
    }

    private void PlayAudio()
    {
        if(_settingsManager.IsAutoplay)_audioManager.Play();
    }

    public override void _Input(InputEvent @event)
    {
        base._Input(@event);
        var delta = _delta;
        
        if (@event.IsActionPressed("ui_cancel"))
        {
            _menu.ToggleMenu();
        }

        // пауза на Space, отмена также.
        // поворот
        if (@event is InputEventMouseMotion motionEvent && _isMouseCaptured)
        {
            _cameraOrigin.RotateY(Mathf.DegToRad(-motionEvent.Relative.X * RotationSpeed));
            _pitch -= motionEvent.Relative.Y * RotationSpeed;
            _pitch = Mathf.Clamp(_pitch, MaxPitchLowAngle, MaxPitchHighAngle);
            Vector3 rotation = _cameraOrigin.RotationDegrees;
            _cameraOrigin.RotationDegrees = new Vector3(_pitch, rotation.Y, rotation.Z);
        }

        // Проверяем прокрутку колёсика мыши
        if (@event is InputEventMouseButton mouseEvent)
        {
            if (mouseEvent.ButtonIndex == MouseButton.WheelUp && mouseEvent.Pressed)
            {
                // При прокрутке вперёд уменьшаем расстояние (зум приближается)
                Vector3 newPosition = _camera.Position;
                newPosition.Z = Mathf.Clamp(newPosition.Z + ZoomSpeedMouseWheel * (float)delta, MinZoomDistance, MaxZoomDistance);
                _camera.Position = newPosition;
            }
            else if (mouseEvent.ButtonIndex == MouseButton.WheelDown && mouseEvent.Pressed)
            {
                // При прокрутке назад увеличиваем расстояние (зум отдаляется)
                Vector3 newPosition = _camera.Position;
                newPosition.Z = Mathf.Clamp(newPosition.Z - ZoomSpeedMouseWheel * (float)delta, MinZoomDistance, MaxZoomDistance);
                _camera.Position = newPosition;
            }
        }

       
    }
}