idf_build_get_property(idf_path IDF_PATH)

idf_component_register(
  SRCS "video.c" "diag.c"
  INCLUDE_DIRS
    "include"
    "${idf_path}/components/driver/deprecated"
  REQUIRES driver esp_hw_support
)
