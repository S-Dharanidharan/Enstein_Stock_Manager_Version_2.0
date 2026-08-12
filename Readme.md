# Enstein Stock Manager

**Version:** 2.1.4  
**Company:** Enstein Robots and Automations Pvt Limited

A professional inventory management application built with Qt6 and QML.

## Features

- **Excel File Support**: Create, open, edit, and save `.xlsx` files
- **Stock Management**: Track parts inventory with stock quantities
- **Purchase File Merging**: Record purchases and merge into stock database
- **Search Functionality**: Search parts by name, number, or vendor
- **Cloud Synchronization**: Sync files via shared folders (Dropbox, etc.)
- **User Authentication**: Role-based access control (owner, editor, viewer)
- **Cross-Platform**: Works on Linux, Windows, and macOS

## Project Structure

```
enstein_stock_manager/
├── CMakeLists.txt      # Build configuration
├── main.cpp            # Application entry point
├── excelhandler.h      # Header for Excel operations
├── excelhandler.cpp    # Implementation of Excel operations
├── Main.qml            # Main user interface
├── QXlsx/              # Excel library (git submodule)
└── README.md           # This file
```

## Prerequisites

### Ubuntu/Debian
```bash
sudo apt install \
    qt6-base-dev \
    qt6-declarative-dev \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-window \
    qml6-module-qtquick-templates \
    qml6-module-qtqml-workerscript \
    cmake \
    build-essential
```

### Windows
- Install Qt 6.5+ from [qt.io](https://www.qt.io/download) (Qt Widgets included)
- Install CMake 3.16+
- Install Visual Studio or MinGW

### macOS
```bash
brew install qt@6 cmake
```

## Build Instructions

### 1. Clone QXlsx Library
```bash
cd enstein_stock_manager
git clone https://github.com/QtExcel/QXlsx.git
```

### 2. Create Build Directory
```bash
mkdir build && cd build
```

### 3. Configure with CMake
```bash
# Linux
cmake ..

# Windows/macOS (specify Qt path)
cmake .. -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x.x/gcc_64
```

### 4. Build
```bash
cmake --build . -j$(nproc)
```

### 5. Run
```bash
./EnsteinStockManager
```

## Usage

### First Run
1. Click **🔒 Login** and enter credentials (default: admin/admin123)
2. Click **📌 Set Permanent** to select your main stock database file
3. Start adding items using **➕ Add Item**

### Creating Files
- **📦 Create Stock**: New inventory file with Stock column
- File includes: Part Name, Part No, Stock, Department, Prepared, Approved, Vendor

### Cloud Sync
1. Click **⚙️** to open Cloud Settings
2. Set your cloud folder path (e.g., Dropbox folder)
3. Enter your user name and role
4. Use **⬆️** to upload and **⬇️** to download

### Searching
1. Click **🔍 Search**
2. Enter part name, number, or vendor
3. Click a result to select that row

## File Columns

| Column | Description |
|--------|-------------|
| Part Name | Name of the component/part |
| Part No | Unique part identifier |
| Stock/Purchase | Quantity in stock or purchased |
| Department | Category (Electronics, Mechanical, etc.) |
| Prepared | Person who prepared the entry |
| Approved | Person who approved the entry |
| Vendor | Supplier name |

## API Reference

### ExcelHandler Class

#### Properties
| Property | Type | Description |
|----------|------|-------------|
| `model` | ExcelTableModel* | Data model for table views |
| `currentFile` | QString | Path to current file |
| `hasUnsavedChanges` | bool | Unsaved changes flag |
| `permanentFile` | QString | Permanent database file |
| `cloudFolder` | QString | Cloud sync folder |
| `currentUser` | QString | Current user name |
| `userRole` | QString | User role (owner/editor/viewer) |

#### Key Methods
| Method | Description |
|--------|-------------|
| `createStockFile(rows)` | Create new stock file |
| `loadExcel(path)` | Load Excel file |
| `saveExcel(path)` | Save to Excel file |
| `searchAllMatches(text)` | Search parts |
| `addNewItem(...)` | Add or update item |
| `syncToCloud()` | Upload to cloud |
| `syncFromCloud()` | Download from cloud |

## Downloads

Grab a build from the [Releases](../../releases) page.

**Windows** — both `.exe` files are self-contained. The Qt runtime, QML modules,
SQL drivers and PostgreSQL client libraries all travel inside them, so the
target machine needs nothing preinstalled.

- `EnsteinStockManager-Setup-<version>.exe` — installer. Start Menu entry,
  desktop icon, uninstaller, clean upgrades. Use this for normal deployment.
- `EnsteinStockManager-Portable-<version>.exe` — **one file, no install**. Copy
  it to any 64-bit Windows machine and double-click. Needs no admin rights.
- `EnsteinStockManager-Windows-<version>.zip` — the plain deployed folder.

**Linux** — `Enstein_Stock_Manager-<version>-x86_64.AppImage`. `chmod +x` it and run.

On first launch Windows SmartScreen warns about the unsigned binary; choose
*More info -> Run anyway*. See [docs/RELEASING.md](docs/RELEASING.md) for how to
cut a release and how to add code signing.

Your data is not stored next to the exe. The local SQLite fallback database
lives under `%APPDATA%\Enstein Robots and Automations Pvt Limited\Enstein Stock Manager\`,
so it survives upgrades and works from a read-only install location.

## Troubleshooting

### QML modules not found
```bash
sudo apt install qml6-module-qtquick qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts
```

### Symbol lookup error (snap conflict)
```bash
unset GTK_PATH
./EnsteinStockManager
```

### Qt not found during CMake
```bash
cmake .. -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x.x/gcc_64
```

## License

Copyright © 2025 Enstein Robots and Automations Pvt Limited.  
All rights reserved.

## Contact

For support, contact: support@einsteinrobotics.com
