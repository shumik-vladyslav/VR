using Godot;

namespace Mandala.splash;

public partial class Splash : Control
{
	private AnimationPlayer AnimationPlayer { get; set; } = default!;
	private ColorRect Background { get; set; } = default!;

	[Signal]
	public delegate void EndEventHandler();

	public override void _Ready()
	{
		base._Ready();
		AnimationPlayer = GetNode<AnimationPlayer>("%AnimationPlayer");
		Background = GetNode<ColorRect>("%Background");
		AnimationPlayer.AnimationFinished += OnAnimationFinished;
	}

	private void OnAnimationFinished(StringName animationName)
	{
		if (animationName == "intro")
			Finish();
	}

	// Клик мышью или любая клавиша — пропустить заставку
	public override void _Input(InputEvent @event)
	{
		if (!Visible || AnimationPlayer.CurrentAnimation != "intro")
			return;
		if ((@event is InputEventMouseButton mouse && mouse.Pressed) || (@event is InputEventKey key && key.Pressed && !key.Echo))
		{
			GetViewport().SetInputAsHandled();
			Finish();
		}
	}

	private void Finish()
	{
		AnimationPlayer.Play("RESET");
		EmitSignal(SignalName.End);
	}

	public void StartSplashScreen()
	{
		AnimationPlayer.Play("intro", customSpeed: 0.3f);
	}
}
