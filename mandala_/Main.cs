using Chickensoft.GoDotLog;
using Godot;

namespace Mandala;

public partial class Main : Node
{
	private ILog _log = new GDLog(nameof(Main));
	public override void _Ready() 
	{
		base._Ready();
		// If we don't need to run tests, we can just switch to the game scene.
		_log.Print("App starting...");
		CallDeferred("StartApp");
		_log.Print("App is started.");
	}

	private void StartApp() 
	{
		GetTree().ChangeSceneToFile("res://src/app/App.tscn");
	}
}
