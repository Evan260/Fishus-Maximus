@echo off
rem Runs the parallax style test: it plays a demo, and the arrow keys take over (left and right row, down lets out line, up reels in).
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" res://tools/style_tests/coast_test.tscn
