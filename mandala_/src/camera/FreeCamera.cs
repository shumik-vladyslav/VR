using Godot;

namespace Zarn3D.shared.domain.player;

[GlobalClass]
public partial class FreeCamera : Camera3D
{
	// Эту камеру надо размещать вне коллизий изначально.
	private const float sensitivity = 3;
	private const float default_velocity = 5;
	private const float speed_scale = 1.17f;
	private const float boost_speed_multiplier = 3.0f;
	private const float max_speed = 1000;
	private const float min_speed = 0.2f;

	private float _velocity = default_velocity;
	private Area3D _area3D = default!;
	
	private bool _isCollide = false;
	private Node3D? _collidedObject;
	private float _delta = 0;

	private Camera3D? main_cam;
	public override void _Ready()
	{
		base._Ready();
		TopLevel = true;
		_area3D = new Area3D();
		CollisionShape3D shape3D = new CollisionShape3D();
		shape3D.Shape = new SphereShape3D() {Radius = 0.2f};
		_area3D.AddChild(shape3D);
		AddChild(_area3D);
		_area3D.AreaEntered += Area3DOnBodyEntered;
		_area3D.AreaExited += Area3DOnBodyExited;
	}

	private void Area3DOnBodyEntered(Node3D body)
	{
		_isCollide = true;
		_collidedObject = body;
	}
	
	private void Area3DOnBodyExited(Node3D body)
	{
		_isCollide = false;
		_collidedObject = null;
	}

	private int cnt = 0;
	public override void _PhysicsProcess(double delta)
	{
		_delta = (float)delta;
		if (!Current)
		{
			return;
		}

		Vector3 direction = new Vector3(
			GetAxis(Key.D, Key.A),
			GetAxis(Key.E, Key.Q),
			GetAxis(Key.S, Key.W)
		).Normalized();
		Vector3 translateVector = Input.IsPhysicalKeyPressed(Key.Shift) ?
			_velocity * (float)delta * boost_speed_multiplier * direction 
			: _velocity * (float)delta * direction;
		
		Vector3 currentPos = GlobalPosition;
		Vector3 translatedVectorGlobal = GlobalTransform.Basis * translateVector;
		Vector3 pos = currentPos + translatedVectorGlobal;
		
		if (_isCollide && _collidedObject is not null)
		{
			float dist = currentPos.DistanceTo(_collidedObject.GlobalPosition);
			if (dist - pos.DistanceTo(_collidedObject.GlobalPosition) >= 0 || pos.Y < 1)
			{
			 	// если ожидается на следующем шаге приближение, то не двигаемся.
			 	return;
			}
		}

		if (pos.Y < 1)
		{
			return;
		}
		Translate(translateVector);
	}

	public override void _UnhandledInput(InputEvent e)
	{
		if (!Current)
		{
			return;
		}

		HandleMouse(e);
	}

	public void StartCamera()
	{
		var currentActiveCamera = GetViewport().GetCamera3D();
		if (currentActiveCamera != this)
		{
			main_cam = currentActiveCamera;
			Position = main_cam.GlobalPosition;
			Rotation = main_cam.GlobalRotation;
			main_cam.Current = false;
			Current = true;
		}
	}
	
	public void StopCamera()
	{
		var currentActiveCamera = GetViewport().GetCamera3D();
		if (currentActiveCamera == this && main_cam is not null)
		{
			Current = false;
			main_cam.Current = true;
			main_cam = null;
		}
	}


	private void HandleMouse(InputEvent e)
	{
		if (Input.GetMouseMode() == Input.MouseModeEnum.Captured)
		{
			if (e is InputEventMouseMotion mouseMotion)
			{
				Vector3 rotation = Rotation;
				rotation.Y -= mouseMotion.Relative.X / 1000 * sensitivity ;
				rotation.X -= mouseMotion.Relative.Y / 1000 * sensitivity ;
				rotation.X = Mathf.Clamp(rotation.X, Mathf.Pi / -2, Mathf.Pi / 2);
				Rotation = rotation;
			}
		}

		if (e is InputEventMouseButton inputEventMouseButton)
		{
			switch (inputEventMouseButton.ButtonIndex)
			{
				case MouseButton.Right:
					Input.SetMouseMode(inputEventMouseButton.Pressed
						? Input.MouseModeEnum.Captured
						: Input.MouseModeEnum.Visible);
					break;
				case MouseButton.WheelUp: // increase fly velocity
					_velocity = Mathf.Clamp(_velocity * speed_scale, min_speed, max_speed);
					break;
				case MouseButton.WheelDown: // decrease fly velocity
					_velocity = Mathf.Clamp(_velocity / speed_scale, min_speed, max_speed);
					break;
			}
		}
	}



	private float GetAxis(Key key1, Key key2)
	{
		if (Input.IsPhysicalKeyPressed(key1))
		{
			return 1;
		}

		if (Input.IsPhysicalKeyPressed(key2))
		{
			return -1;
		}

		return 0;
	}

	public override void _ExitTree()
	{
		base._ExitTree();
		_area3D.AreaEntered -= Area3DOnBodyEntered;
		_area3D.AreaExited -= Area3DOnBodyExited;
	}
}
