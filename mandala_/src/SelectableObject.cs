using Godot;

namespace Mandala;

public partial class SelectableObject: Node3D
{
	[Export] public string Name { get; set; } = "";
	[Export] public Node3D TargetObject { get; set; } = default!;
}
