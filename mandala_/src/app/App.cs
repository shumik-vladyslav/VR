using System;
using System.Collections.Generic;
using Godot;
using Mandala.menu;
using Mandala.splash;

namespace Mandala.App;

public partial class App : CanvasLayer
{
    private readonly Stack<Action> _fadeInActions = new Stack<Action>();

    private Menu Menu { get; set; } = default!;
    private ColorRect BlankScreen { get; set; } = default!;
    private AnimationPlayer AnimationPlayer { get; set; } = default!;
    private Splash Splash { get; set; } = default!;

    public override void _Ready()
    {
        base._Ready();
        Menu = GetNode<Menu>("%Menu");
        BlankScreen = GetNode<ColorRect>("%BlankScreen");
        AnimationPlayer = GetNode<AnimationPlayer>("%AnimationPlayer");
        Splash = GetNode<Splash>("%Splash");
        Setup();
        
        Splash.StartSplashScreen();
        Splash.Show();
        Menu.HidePlayerControls();
    }

    private void Setup()
    {
        AnimationPlayer.AnimationFinished += OnAnimationFinished;
        Splash.End += SplashOnEnd;
    }

    private void SplashOnEnd()
    {
        Splash.Hide();
        MenuShow();
        //_fadeInActions.Push(MenuShow);
        //FadeInFromBlack();
    }

    private void MenuShow()
    {
        Menu.ShowMenu();
    }

    public void FadeInFromBlack()
    {
        BlankScreen.Show();
        AnimationPlayer.Play("fade_in");
    }

    public void FadeToBlack()
    {
        BlankScreen.Show();
        AnimationPlayer.Play("fade_out");
    }

    private void OnAnimationFinished(StringName animation)
    {
        if (animation == "fade_in")
        {
            while (_fadeInActions.TryPop(out Action action))
            {
                action();
            }

            BlankScreen.Hide();
        }
    }
}