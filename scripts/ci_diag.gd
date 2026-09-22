extends SceneTree
# CI 诊断脚本：打印 Godot 编辑器模式下实际读取的 Android 导出配置
# 用法：godot --headless --editor --path . -s res://scripts/ci_diag.gd

func _init() -> void:
	var es: EditorSettings = EditorSettings.get_singleton()
	if es == null:
		print("DIAG: EditorSettings is NULL")
	else:
		print("DIAG java_sdk_path=", es.get_setting("android/java_sdk_path"))
		print("DIAG keystore_debug=", es.get_setting("android/keystore/debug"))
		print("DIAG keystore_user=", es.get_setting("android/keystore/debug_user"))
		print("DIAG keystore_password=", es.get_setting("android/keystore/debug_password"))
		var f := FileAccess.open(
			OS.get_environment("HOME") + "/.config/godot/editor_settings-4.3.tres", FileAccess.READ)
		if f:
			print("DIAG file_exists=yes first_lines:")
			for i in range(8):
				if f.eof_reached():
					break
				print("DIAG | ", f.get_line())
			f.close()
		else:
			print("DIAG file_exists=no")
	quit()
