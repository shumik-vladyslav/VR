using Godot;
using System;
using Mandala;
using Zarn3D.shared.domain.player;

public enum ControllerMode
{
	Free,
	Rotate
}

public partial class Camera : Node3D
{
	[Export] private float MaxPitchHighAngle = 60.0f; // Максимальный угол наклона по X
	[Export] private float MaxPitchLowAngle = -30.0f; // Максимальный угол наклона по X
	[Export] private float RotationSpeed = 0.05f; // Скорость вращения
	[Export] private float ZoomSpeedMouseWheel = 5f; // Скорость зума
	[Export] private float ZoomSpeedMouseMove = 0.01f; // Скорость зума
	[Export] private float MinZoomDistance = 2.5f; // Минимальная дистанция зума
	[Export] private float MaxZoomDistance = 4.5f; // Максимальная дистанция зума
	[Export] private Node3D? CameraTarget = default!;// точка привязки камеры. Ее меняют снаружи.
	[Export] private  float FreeModeSpeed = 5.0f;
	[Export] private float RetargetSpeed = 5f;  // Скорость перемещения камеры между объектами.
	
	private bool _disableControl;

	private float _pitch = 0.0f; // Для ограничения поворота по X
	private Node3D _cameraOrigin;
	private Camera3D _camera;
	private double _delta;
	private bool _moveToTarget = false;
	private FreeCamera _freeCamera;
	private Node3D _mLightContainer;
	private Node3D _fLightContainer;

	public bool IsMouseCaptured { get; private set; } = true;

	public ControllerMode Mode
	{
		get => _mode;
		private set
		{
			if (value == ControllerMode.Rotate)
			{
				_fLightContainer.Visible = false;
				_mLightContainer.Visible = true;
			}
			else
			{
				_fLightContainer.Visible = true;
				_mLightContainer.Visible = false;
			}
			_mode = value;
		}
	}

	public Vector3 FreeCameraPosition => _freeCamera.Position;

	public override void _Ready()
	{
		base._Ready();
		_cameraOrigin = this;
		
		_camera = GetNode<Camera3D>("%MainCamera");
		_freeCamera = GetNode<FreeCamera>("%FreeCamera");
		_mLightContainer = GetNode<Node3D>("%MLightContainer");
		_fLightContainer = GetNode<Node3D>("%FLightContainer");
		_camera.Current = true;
		_freeCamera.Current = false;

		Input.MouseMode = Input.MouseModeEnum.Captured;

		if (CameraTarget != null)
		{
			_cameraOrigin.GlobalPosition = CameraTarget.GlobalPosition;
			Mode = ControllerMode.Rotate;
		}
		else
		{
			Mode = ControllerMode.Free;
		}
	}

	public void SetFreeMode()
	{
		if (Mode != ControllerMode.Free)
		{
			Mode = ControllerMode.Free;
			CallDeferred(nameof(FreeCameraToggle));
		}
	}

	public void SetRotateMode(SelectableObject? target)
	{
		if (Mode != ControllerMode.Rotate)
		{
			Mode = ControllerMode.Rotate;
			MoveOriginToFreeCamera();
			CallDeferred(nameof(FreeCameraToggle));
			if(target != null) SetCameraTarget(target, true);
		}
	}

	private void MoveOriginToFreeCamera()
	{
		// переместим камеру в ориджин. далее ориджин сместим к свободной камере. Повернем его чтобы совпали оси с свободной камерой
		// подвиним ориджин вперед, а камеру назад потом на MinZoomDistance. Далее уже вступает в силу двржение к таргет
		
		_camera.GlobalPosition = _cameraOrigin.GlobalPosition;
		_cameraOrigin.GlobalPosition = _freeCamera.GlobalPosition;
		_cameraOrigin.GlobalRotation = _freeCamera.GlobalRotation;
		 
		_camera.Position += new Vector3(0, 0, MinZoomDistance);
		_camera.Rotation = Vector3.Zero;// сброс вращения камеры, если оно возникло при перемещениях.
	}

	public Node3D? GetCameraTarget() => CameraTarget;

	private void FreeCameraToggle()
	{
		if (Mode == ControllerMode.Free)
		{
			_freeCamera.Visible = true;
			_freeCamera.StartCamera();
		}
		else 
		{
			_freeCamera.StopCamera();
			_freeCamera.Visible = false;
		}
	}

	private void DisableNewCamera()
	{
		_camera.Current = true;
		_freeCamera.Current = false;
	}

	private float _currentRetargetSpeed = 0.0f;
	private ControllerMode _mode;

	public override void _Process(double delta)
	{
		if (CameraTarget == null || !_moveToTarget)
		{
			return;
		}
		 
		Vector3 currentPosition = _cameraOrigin.GlobalPosition;
		Vector3 targetPosition = CameraTarget.GlobalPosition;
		_cameraOrigin.GlobalPosition = currentPosition.Lerp(targetPosition, (float)delta * RetargetSpeed);
		
		// Плавное вращение _cameraOrigin, чтобы оно совпало с CameraTarget
		Vector3 currentRotation = _cameraOrigin.GlobalRotation;
		Vector3 targetRotation = CameraTarget.GlobalRotation;

		// Плавно интерполируем вращение
		Vector3 newRotation = currentRotation.Slerp(targetRotation, (float)(delta * RetargetSpeed));
		_cameraOrigin.GlobalRotation = newRotation;
		
		float dist = _cameraOrigin.GlobalPosition.DistanceTo(targetPosition);
		
		if (dist <= 0.01 && IsEqualApprox(currentRotation, targetRotation, 0.01f))
		{
			_cameraOrigin.GlobalRotation = CameraTarget.GlobalRotation;
			_cameraOrigin.GlobalPosition = CameraTarget.GlobalPosition;
			_moveToTarget = false;
			_disableControl = false;
		}
	}
	
	public bool IsEqualApprox(Vector3 v1, Vector3 v2, float eps)
	{
		return Mathf.Abs(v1.X - v2.X) < eps && Mathf.Abs(v1.Y -  v2.Y) < eps && Mathf.Abs(v1.Z - v2.Z) < eps;
	}
	
	public override void _PhysicsProcess(double delta)
	{
		base._PhysicsProcess(delta);
		
		if (_disableControl || !IsMouseCaptured)
		{
			return;
		}

		if (Mode == ControllerMode.Free)
		{
			FreeModeProcess(delta);
			return;
		}
		
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

	private void FreeModeProcess(double delta)
	{
		// Vector2 inputDir = Input.GetVector("ui_left", "ui_right", "ui_up", "ui_down");
		// Vector3 direction = (Transform.Basis * new Vector3(inputDir.X, 0, inputDir.Y)).Normalized();
		// // Двигаем объект с учетом скорости и времени кадра
		// GlobalPosition += direction * FreeModeSpeed * (float)delta;
	}

	public override void _Input(InputEvent @event)
	{
		base._Input(@event);
		
		if (_disableControl || !IsMouseCaptured)
		{
			return;
		}
		
		var delta = _delta;
		
		if (Mode == ControllerMode.Free)
		{
			//FreeModeInputProcess(delta, @event);
		}
		else
		{
			RotateModeInputProcess(delta, @event);
		}
	}

	private void RotateModeInputProcess(double delta, InputEvent @event)
	{
		InputEventMouseButton? mouseEvent = null;
		if (@event is InputEventMouseButton)
		{
			mouseEvent = @event as InputEventMouseButton;
		}
		
		// поворот
		if (@event is InputEventMouseMotion motionEvent)
		{
			_cameraOrigin.RotateY(Mathf.DegToRad(-motionEvent.Relative.X * RotationSpeed));
			_pitch -= motionEvent.Relative.Y * RotationSpeed;
			_pitch = Mathf.Clamp(_pitch, MaxPitchLowAngle, MaxPitchHighAngle);
			Vector3 rotation = _cameraOrigin.RotationDegrees;
			_cameraOrigin.RotationDegrees = new Vector3(_pitch, rotation.Y, rotation.Z);
		}

		// Проверяем прокрутку колёсика мыши
		if (mouseEvent != null)
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

	private void FreeModeInputProcess(double delta, InputEvent @event)
	{
		if (@event is InputEventMouseButton mouseEvent)
		{
			
		}

		// if (@event is InputEventMouseMotion motionEvent)
		// {
		// 	RotateY(-motionEvent.Relative.X  * (float)delta);
		// 	RotateX(-motionEvent.Relative.Y  * (float)delta);
		// 	// Vector3 rotation = Rotation;
		// 	// rotation.X = (float)Mathf.Clamp(rotation.X, -Math.PI / 2, Math.PI / 2);
		// }
	}

	public void SetCameraTarget(SelectableObject target, bool moveToTarget)
	{
		CameraTarget = target.TargetObject;
		if (moveToTarget)
		{
			_disableControl = true;
		}
		_moveToTarget = moveToTarget;
	}

	public void SetMouseModeCapture(bool isCapture)
	{
		Input.MouseMode = isCapture ? Input.MouseModeEnum.Captured : Input.MouseModeEnum.Visible;
		IsMouseCaptured = isCapture;
	}
}
