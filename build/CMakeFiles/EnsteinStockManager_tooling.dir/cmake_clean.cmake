file(REMOVE_RECURSE
  "Enstein/Main.qml"
)

# Per-language clean rules from dependency scanning.
foreach(lang )
  include(CMakeFiles/EnsteinStockManager_tooling.dir/cmake_clean_${lang}.cmake OPTIONAL)
endforeach()
