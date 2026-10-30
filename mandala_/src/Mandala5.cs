using Godot;
using System;
using System.Collections.Generic;
using Mandala;
using Mandala.menu;
using Mandala.selectable_menu;

public partial class Mandala5 : Node
{
	private Camera _camera = default!;
	[Export] private Node3D _selectable = default!;
	private List<SelectableObject> _selectableList;
	private SelectableMenu _selectableMenu;
	private Menu _menu;
	private AudioManager _audioManager;
	private SettingsManager _settingsManager;
	
	
	[Export]
	public SelectableObject[] Vectors { get; set; }
	
	public override void _Ready()
	{
		_camera = GetNode<Camera>("%Camera");
		_menu = GetNode<Menu>("%Menu");
		_audioManager = AudioManager.GetInstance();
		_settingsManager = SettingsManager.GetInstance();
		_selectableMenu = GetNode<SelectableMenu>("%SelectableMenu");
		_selectableList = LoadSelectableList();
		_selectableMenu.SetList(_selectableList);
		_selectableMenu.SelectedItem = _camera.GetCameraTarget() as SelectableObject;
		_selectableMenu.SelectItem += SelectableMenuOnSelectItem;
		_menu.HideMenu();
		_menu.ShowPlayerControls();
		CallDeferred("PlayAudio");
	}
	
	private void PlayAudio()
	{
		if(_settingsManager.IsAutoplay)_audioManager.Play();
	}

	public override void _ExitTree()
	{
		base._ExitTree();
		_selectableMenu.SelectItem -= SelectableMenuOnSelectItem;
	}

	private void SelectableMenuOnSelectItem(SelectableObject selected)
	{
		_selectableMenu.Visible = false;
		_camera.SetMouseModeCapture(true);
		if (_camera.Mode != ControllerMode.Rotate)
		{
			_camera.SetRotateMode(selected);
		}
		else
		{
			_camera.SetCameraTarget(selected, true);
		}
	}

	private List<SelectableObject> LoadSelectableList()
	{
		var children = _selectable.GetChildren();
		var list = new List<SelectableObject>();
		foreach (var child in children)
		{
			if (child is SelectableObject selectable)
			{
				list.Add(selectable);
			}
		}
		return list;
	}
	
	public override void _Process(double delta)
	{
	}

	public override void _Input(InputEvent @event)
	{
		base._Input(@event);
		
		if (@event.IsActionPressed("ui_cancel"))
		{
			_menu.ToggleMenu();
			_camera.SetMouseModeCapture(!_menu.IsOpened);
		}
		
		if (IsSelectedMenuBtnPressed(@event))
		{
			if (_selectableMenu.Visible == false)
			{
				_camera.SetMouseModeCapture(false);
				_selectableMenu.Show();
			}else 
			{
				_camera.SetMouseModeCapture(true);
				_selectableMenu.Hide();
			}
		}
		
		if (IsFreeModePressed(@event))
		{
			if (_selectableMenu.Visible)
			{
				_camera.SetMouseModeCapture(true);
				_selectableMenu.Hide();
			}
		
			if (_camera.Mode == ControllerMode.Rotate)
			{
				_camera.SetFreeMode();
			}
			else
			{
				SelectableObject? target = FindClosedSelectable(_camera.FreeCameraPosition);
				_camera.SetRotateMode(target);
			}
		}
	}

	private SelectableObject? FindClosedSelectable(Vector3 cameraFreeCameraPosition)
	{
		if(_selectableList.Count == 0) return null;

		SelectableObject? target = null;
		float minDistance = float.MaxValue;
		foreach (var obj in _selectableList)
		{
			float distance = obj.GlobalPosition.DistanceTo(cameraFreeCameraPosition);
			if(distance < minDistance)
			{
				minDistance = distance;
				target = obj;
			}
		}
		return target;
	}

	private bool IsSelectedMenuBtnPressed(InputEvent @event)
	{
		return @event is InputEventMouseButton mouseEvent
		       && mouseEvent.ButtonIndex == MouseButton.Middle
		       && mouseEvent.Pressed;
	}
	
	private bool IsFreeModePressed(InputEvent @event)
	{
		return @event.IsActionPressed("ui_accept");
	}
}
