cmake_minimum_required(VERSION 3.16)

project(EnsteinStockManager VERSION 2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ---- Windows: force shared Qt (fix MinGW entrypoint issue) ----
if (WIN32)
    set(BUILD_SHARED_LIBS ON)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "")
endif()

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    Network
    Widgets
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
)

# Generate a deploy script when available (Qt 6.2+). This helps bundle
# Qt runtime and QML imports during install for Windows/Linux releases.
if (COMMAND qt_generate_deploy_qml_app_script)
    # Qt 6.10+ uses OUTPUT_SCRIPT, older versions use FILENAME_VARIABLE.
    if (Qt6_VERSION VERSION_GREATER_EQUAL "6.10")
        qt_generate_deploy_qml_app_script(
            TARGET EnsteinStockManager
            OUTPUT_SCRIPT deploy_script
            NO_UNSUPPORTED_PLATFORM_ERROR
        )
    else()
        qt_generate_deploy_qml_app_script(
            TARGET EnsteinStockManager
            FILENAME_VARIABLE deploy_script
            NO_UNSUPPORTED_PLATFORM_ERROR
        )
    endif()
endif()

set_target_properties(EnsteinStockManager PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING
        ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
)

target_link_libraries(EnsteinStockManager
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::Network
        Qt6::Widgets
        QXlsx::QXlsx
)

include(GNUInstallDirs)

install(TARGETS EnsteinStockManager
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

if (COMMAND qt_generate_deploy_qml_app_script)
    install(SCRIPT ${deploy_script})
endif()
