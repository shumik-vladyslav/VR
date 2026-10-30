using System.Collections.Generic;
using Godot;

namespace Mandala.selectable_menu;

public partial class SelectableMenu : CanvasLayer
{
	private OptionButton _optionButton = default!;
	private List<SelectableObject> _selectableList = new();
	private int _selectedIndex = -1;
	
	public SelectableObject? SelectedItem
	{
		get
		{
			if(_selectedIndex == -1) return null;
			return _selectableList[_selectedIndex];
		}
		set
		{
			if (value == null)
			{
				_selectedIndex = -1;
				return;
			}
			int index = _selectableList.IndexOf(value);
			_selectedIndex = index;
			_optionButton.Select(index);
		}
	}

	[Signal]
	public delegate void SelectItemEventHandler(SelectableObject selected);
	
	public override void _Ready()
	{
		base._Ready();
		_optionButton = GetNode<OptionButton>("%SelectableList");
		_optionButton.ItemSelected += OnSelectItem;
	}

	public override void _ExitTree()
	{
		base._ExitTree();
		_optionButton.ItemSelected -= OnSelectItem;
	}

	private void OnSelectItem(long index)
	{
		if(_selectedIndex != (int)index)
		{
			_selectedIndex = (int)index;
			EmitSignal(SignalName.SelectItem, _selectableList[(int)index]);
		}
	}

	public void SetList(List<SelectableObject> selectableList)
	{
		_selectableList.Clear();
		_selectableList.AddRange(selectableList);
		_optionButton.Clear();
		foreach (var selectable in _selectableList)
		{
			_optionButton.AddItem(selectable.Name);
		}

		_selectedIndex = -1;
	}
}
