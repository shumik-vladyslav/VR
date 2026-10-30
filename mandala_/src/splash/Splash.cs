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
		{
			AnimationPlayer.Play("RESET");
			EmitSignal(SignalName.End);
		}
	}

	public void StartSplashScreen()
	{
		AnimationPlayer.Play("intro", customSpeed: 0.3f);
	}
}
