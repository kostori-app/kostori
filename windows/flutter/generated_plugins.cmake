#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  app_links
  battery_plus
  desktop_webview_window
  dynamic_color
  file_selector_windows
  flutter_inappwebview_windows
  flutter_qjs
  flutter_volume_controller
  local_auth_windows
  media_kit_libs_windows_video
  media_kit_video
  permission_handler_windows
  screen_retriever_windows
  share_plus
  sqlite3_flutter_libs
  url_launcher_windows
  volume_controller
  window_manager
  windows_taskbar
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  lodepng_flutter
  rhttp
  smtc_windows
  zip_flutter
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
