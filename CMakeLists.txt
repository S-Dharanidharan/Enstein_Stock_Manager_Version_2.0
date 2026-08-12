cmake_minimum_required(VERSION 3.16)

# CI overrides this from the git tag (-DAPP_VERSION=x.y.z) so the exe metadata,
# the installer and the reported application version can never drift apart.
set(APP_VERSION "2.1.4" CACHE STRING "Application version (x.y.z)")

project(EnsteinStockManager VERSION ${APP_VERSION} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The Windows resource compiler is needed for the embedded icon + version info
# below. project(... LANGUAGES CXX) alone does not enable it.
if (WIN32)
    enable_language(RC)
endif()

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    Network
    Widgets
    Sql
)

qt_standard_project_setup()

# ---- QXlsx ----
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/QXlsx/QXlsx/CMakeLists.txt")  
    add_subdirectory(QXlsx/QXlsx)
    message(STATUS "QXlsx found and added")
else()
    message(FATAL_ERROR "QXlsx not found!")
endif()

qt_add_executable(EnsteinStockManager
    main.cpp
)

qt_add_qml_module(EnsteinStockManager
    URI Enstein
    VERSION 1.0
    QML_FILES
        Main.qml
    SOURCES
        excelhandler.h
        excelhandler.cpp
        dbmanager.h
        dbmanager.cpp
        serversetup.h
        serversetup.cpp
        podocument.h
        podocument.cpp
)

# Compile the window icon into the binary so it is present no matter how the
# app is packaged or where the exe is copied to.
qt_add_resources(EnsteinStockManager "app_assets"
    PREFIX "/"
    BASE "assets"
    FILES
        assets/app-icon.png
)

# ---- Windows: embedded exe icon and file/version metadata ----
if (WIN32)
    file(TO_CMAKE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/assets/app-icon.ico" APP_ICON_ICO)
    set(VER_MAJOR ${PROJECT_VERSION_MAJOR})
    set(VER_MINOR ${PROJECT_VERSION_MINOR})
    set(VER_PATCH ${PROJECT_VERSION_PATCH})
    set(VER_STR   "${PROJECT_VERSION}")
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/packaging/windows/app.rc.in"
        "${CMAKE_CURRENT_BINARY_DIR}/app.rc"
        @ONLY
    )
    target_sources(EnsteinStockManager PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/app.rc")
endif()

set_target_properties(EnsteinStockManager PROPERTIES
    # Windows GUI subsystem: without this the app opens a console window
    # alongside the UI on every launch.
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING
        ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
)

target_compile_definitions(EnsteinStockManager
    PRIVATE APP_VERSION_STR="${PROJECT_VERSION}"
)

target_link_libraries(EnsteinStockManager
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::Network
        Qt6::Widgets
        Qt6::Sql
        QXlsx::QXlsx
)

include(GNUInstallDirs)

install(TARGETS EnsteinStockManager
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
