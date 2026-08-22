import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Basic 6.3 as BasicControls
import ExcelHandler 1.0

ApplicationWindow {
    id: root
    visible: true
    width: 1600
    height: 900

    property int rows: 0
    property int columns: 0
    property int dataRows: Math.max(0, rows - 1)
    property int selectedRow: -1
    property int contextRow: -1
    property string fileType: "stock"
    property int tableRefreshToken: 0
    property bool dbSetupBusy: false
    // ---- Stock overview / department segregation ----
    // Empty means "all departments"; anything else filters the grid and the chart.
    property string selectedDepartment: ""
    property var deptSummary: []
    property var stockTotalsData: ({})
    property var visibleStockRows: []
    property bool overviewExpanded: true

    // Categorical slots, in fixed order, validated for colour-vision separation
    // against a light surface. Departments take a slot by name (see
    // departmentStockSummary), never by rank, so a colour never migrates between
    // departments when quantities change. Past the sixth, holdings fold into a
    // neutral "Other" slice rather than inventing a new hue.
    readonly property var seriesColors: ["#2a78d6", "#eb6834", "#1baf7a",
                                         "#eda100", "#e87ba4", "#008300"]
    readonly property color seriesOther: "#9aa0a6"
    readonly property int maxColoredSlices: 6

    function departmentColor(colorIndex) {
        if (colorIndex < 0) return seriesOther
        return seriesColors[colorIndex % seriesColors.length]
    }

    function refreshStockOverview() {
        deptSummary = excelHandler.departmentStockSummary()
        stockTotalsData = excelHandler.stockTotals()
        visibleStockRows = excelHandler.stockRowsForDepartment(selectedDepartment)
    }

    // The slices actually drawn: the biggest holdings keep their own colour and
    // the tail becomes one labelled "Other", so the ring never carries more
    // hues than a reader can tell apart.
    function donutSlices() {
        var out = []
        var otherQty = 0
        var otherCount = 0
        for (var i = 0; i < deptSummary.length; i++) {
            var d = deptSummary[i]
            if (d.qty <= 0) continue
            if (out.length < maxColoredSlices) {
                out.push({ label: d.department, qty: d.qty,
                           color: departmentColor(d.colorIndex), isOther: false })
            } else {
                otherQty += d.qty
                otherCount++
            }
        }
        if (otherQty > 0) {
            out.push({ label: "Other (" + otherCount + ")", qty: otherQty,
                       color: seriesOther, isOther: true })
        }
        return out
    }

    property var tableBaseWidths: [350, 190, 130, 200, 180, 200, 260, 190, 140]
    property var tableMinWidths: [140, 90, 70, 90, 90, 90, 110, 90, 80]

    onRowsChanged: refreshStockOverview()
    onTableRefreshTokenChanged: refreshStockOverview()
    onSelectedDepartmentChanged: refreshStockOverview()

    function columnWidth(colIndex) {
        var available = Math.max(800, tableHeader.width - 40)
        var baseTotal = 0
        for (var i = 0; i < tableBaseWidths.length; i++) baseTotal += tableBaseWidths[i]
        var scale = available / baseTotal
        var width = Math.round(tableBaseWidths[colIndex] * scale)
        return Math.max(tableMinWidths[colIndex], width)
    }

    title: {
        var fileName = "Untitled"
        if (excelHandler.currentFile !== "") {
            var parts = excelHandler.currentFile.split("/")
            fileName = parts[parts.length - 1]
        }
        return "Enstein Stock Manager - " + fileName +
               (excelHandler.hasUnsavedChanges ? " *" : "") +
               (loginDialog.isAuthenticated ? " [Logged In]" : " [Read-Only]")
    }

    ExcelHandler {
        id: excelHandler

        onErrorOccurred: function(error) {
            errorDialog.errorText = error
            errorDialog.open()
        }

        onFileLoaded: function(fileName) {
            statusLabel.text = "Loaded: " + fileName
            root.tableRefreshToken++
            statusTimer.restart()
        }

        onFileSaved: function(fileName) {
            statusLabel.text = "Saved: " + fileName
            statusTimer.restart()
        }

        onFileMerged: function(fileName, rowsAdded, rowsUpdated) {
            statusLabel.text = "Merged - Added: " + rowsAdded + ", Updated: " + rowsUpdated
            root.tableRefreshToken++
            statusTimer.restart()
        }

        onSearchResultFound: function(row) {
            root.selectedRow = row
        }

        // Another machine changed the shared data; it has already been reloaded.
        onSharedDataChanged: {
            root.rows = excelHandler.model.rowCount()
            root.columns = excelHandler.model.columnCount()
            root.tableRefreshToken++
            refreshStockOverview()
            refreshPOList()
            refreshDCList()
            refreshPRList()
            statusLabel.text = "Updated \u2014 someone else changed the shared data"
            statusTimer.restart()
        }

        onPurchaseOrderCreated: function(poNo) {
            statusLabel.text = "PO Created: " + poNo
            statusTimer.restart()
        }

        onDeliveryChallanCreated: function(dcNo) {
            statusLabel.text = "Delivery Challan Created: " + dcNo
            statusTimer.restart()
        }

        onDeliveryChallanListChanged: {
            if (dcDialog.visible) refreshDCList()
        }

        onPurchaseRequestCreated: function(prNo) {
            statusLabel.text = "Purchase Request raised: " + prNo
            statusTimer.restart()
        }

        onPurchaseRequestListChanged: {
            if (prDialog.visible) refreshPRList()
        }

        onGoodsReceived: function(grnNo, poNo) {
            statusLabel.text = "GRN " + grnNo + " received for " + poNo
            rows = excelHandler.model.rowCount()
            root.tableRefreshToken++
            refreshPOList()
            refreshMovements()
            statusTimer.restart()
        }

        onStockIssued: function(issueNo, partName, qty) {
            statusLabel.text = "Issued: " + partName + " x" + qty + " (" + issueNo + ")"
            rows = excelHandler.model.rowCount()
            root.tableRefreshToken++
            refreshMovements()
            refreshIssuePartDropdown()
            statusTimer.restart()
        }

        onServerProvisionProgress: function(message) {
            dbStatusLabel.text = message
        }

        onServerProvisionFinished: function(success, result) {
            root.dbSetupBusy = false
            if (success) {
                // Show the admin exactly what to type into every other
                // computer's connection dialog, and switch this machine's own
                // form over to the freshly provisioned PostgreSQL server.
                dbDriverCombo.currentIndex = 1
                dbHostField.text = result.host !== undefined ? result.host : ""
                dbPortField.text = (result.port !== undefined ? result.port : 5432).toString()
                dbNameField.text = result.name !== undefined ? result.name : "stockmanager"
                dbUserField.text = result.user !== undefined ? result.user : ""
                dbPassField.text = result.password !== undefined ? result.password : ""
                serverInfoBox.visible = true
                dbStatusLabel.text = excelHandler.databaseStatus()
                statusLabel.text = "This computer is now the shared database server"
            } else {
                dbStatusLabel.text = "Server setup failed: " +
                    (result.message !== undefined ? result.message : "unknown error")
            }
        }
    }

    /* ================= COMMON DIALOGS ================= */

    Dialog {
        id: errorDialog
        title: "Error"
        modal: true
        standardButtons: Dialog.Ok
        anchors.centerIn: parent
        width: 400
        property alias errorText: errorLabel.text
        Label { id: errorLabel; wrapMode: Text.WordWrap; width: parent.width }
    }

    /* ================= LOGIN DIALOG ================= */

    Dialog {
        id: loginDialog
        title: "Authorization Required"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        property bool isAuthenticated: false

        ColumnLayout {
            spacing: 15
            Label { text: "Enter credentials to enable editing"; font.bold: true; font.pixelSize: 14 }
            Label { text: "Username:" }
            TextField { id: usernameField; placeholderText: "admin"; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "Password:" }
            TextField {
                id: passwordField; placeholderText: "password"; echoMode: TextInput.Password
                Layout.fillWidth: true; selectByMouse: true
                Keys.onReturnPressed: loginDialog.accept()
            }
            Label { id: loginError; text: ""; color: "#e74c3c"; visible: text !== "" }
        }

        onAccepted: {
            // Credentials are verified against the shared users table in the database.
            var role = excelHandler.login(usernameField.text, passwordField.text)
            if (role !== "") {
                isAuthenticated = true
                loginError.text = ""
                usernameField.text = ""; passwordField.text = ""
                statusLabel.text = "Login successful (" + role + ")"; statusTimer.restart()
            } else {
                isAuthenticated = false
                loginError.text = "Invalid credentials"; passwordField.text = ""
                loginDialog.open()
            }
        }
        
        onOpened: loginError.text = ""
    }

    /* ================= FILE ACTIONS ================= */

    function openExcelFile() {
        var selectedFile = excelHandler.browseOpenFile("Open Excel File", "Excel files (*.xlsx *.xls)")
        if (selectedFile === "") return

        var appended = false
        if (excelHandler.currentFile !== "" || excelHandler.permanentFile !== "") {
            if (root.fileType === "stock") {
                appended = excelHandler.appendStockFile(selectedFile)
                if (appended) {
                    rows = excelHandler.model.rowCount()
                    columns = excelHandler.model.columnCount()
                    selectedRow = -1
                    statusLabel.text = "Appended: " + selectedFile
                    statusTimer.restart()
                }
            }
        }

        if (!appended) {
            if (excelHandler.loadExcel(selectedFile)) {
                rows = excelHandler.model.rowCount()
                columns = excelHandler.model.columnCount()
                selectedRow = -1
                root.fileType = excelHandler.getFileType()
            }
        }
    }

    function saveAsExcelFile() {
        var selectedFile = excelHandler.browseSaveFile("Save Excel File", "Excel files (*.xlsx)")
        if (selectedFile === "") return
        excelHandler.saveExcel(selectedFile)
    }

    // Imports the user's stock xlsx into the shared database (login required).
    function importStockFileAction() {
        var selectedFile = excelHandler.browseOpenFile("Import Stock File", "Excel files (*.xlsx *.xls)")
        if (selectedFile === "") return
        if (excelHandler.importStockFile(selectedFile)) {
            rows = excelHandler.model.rowCount()
            columns = excelHandler.model.columnCount()
            root.fileType = excelHandler.getFileType()
            statusLabel.text = "Stock file imported into the database"
            statusTimer.restart()
        }
    }

    /* ================= NEW STOCK FILE DIALOG ================= */

    Dialog {
        id: newStockFileDialog
        title: "Create New Stock File"
        standardButtons: Dialog.Ok | Dialog.Cancel
        modal: true
        anchors.centerIn: parent

        ColumnLayout {
            spacing: 10
            Label { text: "Stock File (with Supply Chain columns)"; font.bold: true; font.pixelSize: 14; color: "#27ae60" }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#27ae60" }
            Label { text: "Number of Rows:"; font.bold: true }
            SpinBox { id: stockRowsSpin; from: 1; to: 1000; value: 15; editable: true }
            Label {
                text: "Columns: Part Name | Part No | Stock | Department | Prepared | Approved | Vendor | Date | Unit Price"
                font.pixelSize: 10; color: "#7f8c8d"; wrapMode: Text.WordWrap
            }
        }

        onAccepted: {
            excelHandler.createStockFile(stockRowsSpin.value)
            rows = excelHandler.model.rowCount()
            columns = excelHandler.model.columnCount()
            selectedRow = -1
            root.fileType = "stock"
            statusLabel.text = "Created new Stock file: " + rows + " rows (9 columns)"
        }
    }

    /* ================= SEARCH DIALOG ================= */

    Dialog {
        id: searchDialog
        title: "Search Parts"
        modal: true
        standardButtons: Dialog.Close
        anchors.centerIn: parent
        width: 600; height: 500

        function runSearch() {
            var query = searchField.text.trim()
            searchResultsModel.clear()
            if (query === "") {
                statusLabel.text = "Enter search text"
                return
            }
            var results = excelHandler.searchAllMatches(query)
            for (var i = 0; i < results.length; i++) searchResultsModel.append(results[i])
            statusLabel.text = results.length === 0 ? "No results found" : "Found " + results.length + " result(s)"
        }

        ColumnLayout {
            anchors.fill: parent; spacing: 10

            Label { text: "Search by Part Name, Part No, or Vendor:"; font.bold: true }

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                TextField {
                    id: searchField; Layout.fillWidth: true
                    placeholderText: "Enter search text..."; selectByMouse: true
                    Keys.onReturnPressed: searchButton.clicked()
                    onTextChanged: searchDialog.runSearch()
                }
                Button {
                    id: searchButton; text: "Search"; highlighted: true
                    onClicked: searchDialog.runSearch()
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#bdc3c7"; border.width: 1; color: "#ecf0f1"

                ListView {
                    id: searchResultsList; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 5
                    model: ListModel { id: searchResultsModel }
                    delegate: Rectangle {
                        width: searchResultsList.width - 10; height: 60; color: "white"
                        border.color: "#3498db"; border.width: 1; radius: 5
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 2
                            Label { text: model.partName; font.bold: true; font.pixelSize: 13; color: "#2c3e50" }
                            RowLayout {
                                Label { text: "Part No: " + model.partNo; font.pixelSize: 11; color: "#7f8c8d" }
                                Label { text: " | Stock: " + model.stock; font.pixelSize: 11; color: "#27ae60"; font.bold: true }
                                Label { text: " | Vendor: " + model.vendor; font.pixelSize: 11; color: "#7f8c8d" }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedRow = model.row
                                searchDialog.close()
                                var pos = model.row - 1
                                if (pos >= 0) tableListView.positionViewAtIndex(pos, ListView.Center)
                            }
                        }
                    }
                }

                Label { anchors.centerIn: parent; text: "No results"; visible: searchResultsModel.count === 0; color: "#95a5a6" }
            }
        }

        onOpened: { searchField.focus = true; searchField.selectAll() }
    }

    /* ================= ADD ITEM DIALOG ================= */

    Dialog {
        id: addItemDialog
        title: "Add Stock Item"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        width: 450

        ColumnLayout {
            spacing: 10; width: parent.width

            Label { text: "Add New Stock Item"; font.bold: true; font.pixelSize: 14 }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

            Label { text: "Part Name:" }
            TextField { id: partNameField; Layout.fillWidth: true; placeholderText: "e.g., Microcontroller"; selectByMouse: true }

            Label { text: "Department:" }
            ComboBox { id: categoryField; Layout.fillWidth: true; editable: true; model: ["Electronics", "Mechanical","Electrical","SCM", "Software", "Other"] }

            Label { text: "Stock Quantity:" }
            SpinBox { id: quantityField; Layout.fillWidth: true; from: 1; to: 10000; value: 1; editable: true }

            Label { text: "Unit Price:" }
            TextField {
                id: unitPriceField
                Layout.fillWidth: true
                placeholderText: "0.00"
                text: "0.00"
                validator: DoubleValidator { bottom: 0; decimals: 2 }
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                selectByMouse: true
            }

            Label { text: "If part exists, stock will be added to current quantity"; font.pixelSize: 10; color: "#7f8c8d"; wrapMode: Text.WordWrap }
        }

        onAccepted: {
            if (partNameField.text.trim() === "") { errorDialog.errorText = "Part name is required!"; errorDialog.open(); return }
            excelHandler.addNewItem(partNameField.text.trim(), categoryField.currentText, quantityField.value, parseAmount(unitPriceField.text))
            rows = excelHandler.model.rowCount()
            columns = excelHandler.model.columnCount()
            statusLabel.text = "Added: " + partNameField.text; statusTimer.restart()
            partNameField.text = ""; quantityField.value = 1; unitPriceField.text = "0.00"
        }
        onOpened: { partNameField.focus = true }
    }

    /* ================= VENDOR MANAGEMENT DIALOG ================= */

    Dialog {
        id: vendorDialog
        title: "Vendor Management"
        modal: true
        anchors.centerIn: parent
        // Takes most of the window instead of a fixed 700x600. The vendor list
        // is what people scan and search, so it gets every pixel the entry form
        // above does not need.
        width: Math.min(root.width - 80, 1240)
        height: Math.min(root.height - 80, 860)

        ColumnLayout {
            anchors.fill: parent; spacing: 10

            Label { text: "Vendor Master"; font.bold: true; font.pixelSize: 16; color: "#2c3e50" }  

            // Add Vendor Form
            Rectangle {
                Layout.fillWidth: true
                // Height follows the form rather than a fixed 250, which the
                // thirteen fields had already outgrown - the last row and the
                // Add button were being cut off at the bottom edge.
                Layout.preferredHeight: vendorEntryGrid.implicitHeight + 20
                color: "#f8f9fa"; border.color: "#dee2e6"; radius: 5

                GridLayout {
                    id: vendorEntryGrid
                    anchors.fill: parent; anchors.margins: 10
                    // Three label/field pairs per row when there is width for
                    // them, two when the window is narrow.
                    columns: width > 900 ? 6 : 4
                    rowSpacing: 8; columnSpacing: 10

                    Label { text: "Name:" } TextField { id: vendorNameField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Vendor name" }
                    Label { text: "Address:" } TextField { id: vendorAddressField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Address" }
                    Label { text: "Name of Bank & Branch:" } TextField { id: vendorBankBranchField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Bank and branch name" }
                    Label { text: "IFSC Code:" } TextField { id: vendorIfscField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "IFSC code" }
                    Label { text: "Bank Account Number:" } TextField { id: vendorAccountField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Account number" }
                    Label { text: "CIN Number" } TextField { id: vendorCinField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "CIN number" }
                    Label { text: "GSTIN Number:" } TextField { id: vendorGstinField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "GSTIN number" }
                    Label { text: "PAN Number:" } TextField { id: vendorPANField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "PAN number" }
                    Label { text: "Name in PAN Card:" } TextField { id: vendorPanNameField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Name as per PAN card" }
                    Label { text: "Contact Person:" } TextField { id: vendorContactPersonField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Contact person name" }
                    Label { text: "Email:" } TextField { id: vendorEmailField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Email" }
                    Label { text: "Phone No:" } TextField { id: vendorPhoneNumberField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Phone number" }
                    Label { text: "Item Category:" } TextField { id: vendorItemCategoryField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Categories supplied" }

                    // Spans the whole row so the button sits at the right edge
                    // whether the grid is showing two pairs or three.
                    Button {
                        text: "Add Vendor"; highlighted: true
                        Layout.columnSpan: vendorEntryGrid.columns
                        Layout.alignment: Qt.AlignRight
                        onClicked: {

                            console.log("Adding vendor with details:", {
                                name: vendorNameField.text,
                                address: vendorAddressField.text,
                                bankBranch: vendorBankBranchField.text,
                                ifsc: vendorIfscField.text,
                                account: vendorAccountField.text,
                                cin: vendorCinField.text,
                                gstin: vendorGstinField.text,
                                pan: vendorPANField.text,
                                panName: vendorPanNameField.text,
                                contactPerson: vendorContactPersonField.text,
                                email: vendorEmailField.text,
                                phone: vendorPhoneNumberField.text,
                                itemCategory: vendorItemCategoryField.text
                            })

                            var vendorDetails = {
                                    vendorName: vendorNameField.text,
                                    vendorAddress: vendorAddressField.text,
                                    bankBranch: vendorBankBranchField.text,
                                    ifsc: vendorIfscField.text,
                                    accountNumber: vendorAccountField.text,
                                    cin: vendorCinField.text,
                                    gstin: vendorGstinField.text,
                                    panNumber: vendorPANField.text,
                                    panName: vendorPanNameField.text,
                                    contactPerson: vendorContactPersonField.text,
                                    email: vendorEmailField.text,
                                    phone: vendorPhoneNumberField.text,
                                    itemCategory: vendorItemCategoryField.text
                                }

                            if (excelHandler.addVendorDetails(vendorDetails)) {
                                refreshVendorList()
                                refreshVendorDropdowns()
                                // vendorNameField.text = ""; vendorAddressField.text = ""; vendorBankBranchField.text = "";
                                // vendorIfscField.text = ""; vendorAccountField.text = ""; vendorCinField.text = "";
                                // vendorGstinField.text = ""; vendorPANField.text = ""; vendorPanNameField.text = "";
                                // vendorContactPersonField.text = ""; vendorEmailField.text = ""; vendorPhoneNumberField.text = "";
                                // vendorItemCategoryField.text = "";   
                            }
                        }
                    }
                }
            }

            // Vendor List
            Label { text: "Vendors (" + vendorListModel.count + ")"; font.bold: true }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Label { text: "Search:"; font.bold: true }
                TextField {
                    id: vendorSearchField
                    Layout.fillWidth: true
                    placeholderText: "Search by name, phone, email, bank, category..."
                    selectByMouse: true
                    Keys.onReturnPressed: vendorSearchButton.clicked()
                    onTextChanged: refreshVendorList(text)
                }
                Button {
                    id: vendorSearchButton
                    text: "Search"
                    onClicked: refreshVendorList(vendorSearchField.text)
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 5

                ListView {
                    id: vendorListView; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: ListModel { id: vendorListModel }
                    delegate: Rectangle {
                        width: vendorListView.width - 10; height: 50
                        color: "#fff"; border.color: "#e0e0e0"; radius: 4
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8
                            Item {
                                id: vendorInfoArea
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 2
                                    Label {
                                        text: model.name; font.bold: true; font.pixelSize: 13
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    Label {
                                        text: model.phone + "  |  " + model.email + "  |  " + model.bankBranch
                                        font.pixelSize: 11; color: "#7f8c8d"
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        openVendorDetails({
                                            name: model.name,
                                            address: model.address,
                                            phone: model.phone,
                                            email: model.email,
                                            bankBranch: model.bankBranch,
                                            ifsc: model.ifsc,
                                            accountNumber: model.accountNumber,
                                            cin: model.cin,
                                            gstin: model.gstin,
                                            pan: model.pan,
                                            panName: model.panName,
                                            contactPerson: model.contactPerson,
                                            itemCategory: model.itemCategory
                                        })
                                    }
                                }
                            }
                            Button {
                                id: vendorDeleteButton
                                Layout.alignment: Qt.AlignRight
                                text: "Delete"; flat: true
                                contentItem: Text { text: "Delete"; color: "#e74c3c"; font.pixelSize: 11 }
                                onClicked: {
                                    excelHandler.deleteVendor(model.name)
                                    refreshVendorList()
                                    refreshVendorDropdowns()
                                }
                            }
                        }

                        // Mouse handling moved to vendorInfoArea to avoid blocking the Delete button.
                    }
                }

                Label { anchors.centerIn: parent; text: "No vendors added"; visible: vendorListModel.count === 0; color: "#95a5a6" }
            }

            Button { text: "Close"; Layout.alignment: Qt.AlignRight; onClicked: vendorDialog.close() }
        }

        onOpened: {
            refreshVendorList()
            refreshVendorDropdowns()
        }
    }

    /* ================= VENDOR DETAILS DIALOG ================= */

    Dialog {
        id: vendorDetailsDialog
        title: "Vendor Details"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel
        // Wide enough for three field pairs per row, and never taller than
        // the window: the fields scroll inside rather than pushing the OK
        // and Cancel buttons off the bottom edge.
        width: Math.min(root.width - 120, 1100)
        height: Math.min(root.height - 120, 540)

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Label { text: "Edit Vendor Details"; font.bold: true; font.pixelSize: 14 }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

            ScrollView {
                id: editVendorScroll
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                GridLayout {
                    width: editVendorScroll.availableWidth
                    columns: width > 900 ? 6 : 4
                    rowSpacing: 8; columnSpacing: 10

                    Label { text: "Name:" } TextField { id: editVendorNameField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Vendor name" }
                    Label { text: "Address:" } TextField { id: editVendorAddressField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Address" }
                    Label { text: "Name of Bank & Branch:" } TextField { id: editVendorBankBranchField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Bank and branch name" }
                    Label { text: "IFSC Code:" } TextField { id: editVendorIfscField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "IFSC code" }
                    Label { text: "Bank Account Number:" } TextField { id: editVendorAccountField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Account number" }
                    Label { text: "CIN Number" } TextField { id: editVendorCinField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "CIN number" }
                    Label { text: "GSTIN Number:" } TextField { id: editVendorGstinField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "GSTIN number" }
                    Label { text: "PAN Number:" } TextField { id: editVendorPANField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "PAN number" }
                    Label { text: "Name in PAN Card:" } TextField { id: editVendorPanNameField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Name as per PAN card" }
                    Label { text: "Contact Person:" } TextField { id: editVendorContactPersonField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Contact person name" }
                    Label { text: "Email:" } TextField { id: editVendorEmailField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Email" }
                    Label { text: "Phone No:" } TextField { id: editVendorPhoneNumberField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Phone number" }
                    Label { text: "Item Category:" } TextField { id: editVendorItemCategoryField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Categories supplied" }
                }
            }
        }

        onAccepted: {
            var vendorDetails = {
                originalName: vendorOriginalName,
                vendorName: editVendorNameField.text,
                vendorAddress: editVendorAddressField.text,
                bankBranch: editVendorBankBranchField.text,
                ifsc: editVendorIfscField.text,
                accountNumber: editVendorAccountField.text,
                cin: editVendorCinField.text,
                gstin: editVendorGstinField.text,
                panNumber: editVendorPANField.text,
                panName: editVendorPanNameField.text,
                contactPerson: editVendorContactPersonField.text,
                email: editVendorEmailField.text,
                phone: editVendorPhoneNumberField.text,
                itemCategory: editVendorItemCategoryField.text
            }

            if (excelHandler.updateVendorDetails(vendorDetails)) {
                refreshVendorList()
                refreshVendorDropdowns()
            }
        }
    }

    function refreshVendorList(filterText) {
        vendorListModel.clear()
        var query = (filterText || "").toString().trim().toLowerCase()
        var vendors = excelHandler.getVendorList()
        for (var i = 0; i < vendors.length; i++){
            var v = vendors[i];
                var haystack = [
                    v.vendorName, v.vendorAddress, v.phone, v.email,
                    v.bankBranch, v.ifsc, v.gstin, v.panNumber,
                    v.contactPerson, v.itemCategory
                ].join(" ").toLowerCase()
                if (query !== "" && haystack.indexOf(query) === -1) continue
                vendorListModel.append({
                    name: v.vendorName || "",
                    address: v.vendorAddress || "",
                    phone: v.phone || "",
                    email: v.email || "",
                    bankBranch: v.bankBranch || "",
                    ifsc: v.ifsc || "",
                    accountNumber: v.accountNumber || "",
                    cin: v.cin || "",
                    gstin: v.gstin || "",
                    pan: v.panNumber || "",
                    panName: v.panName || "",
                    contactPerson: v.contactPerson || "",
                    itemCategory: v.itemCategory || ""
              })
        }
    }

    function refreshVendorDropdowns() {
        var vendorNames = excelHandler.getVendorNames()
        itemVendorField.model = vendorNames
        poVendorField.model = vendorNames
        editItemVendorField.model = vendorNames
        prVendorField.model = vendorNames
    }

    property string vendorOriginalName: ""

    function openVendorDetails(vendor) {
        vendorOriginalName = vendor.name || ""
        editVendorNameField.text = vendor.name || ""
        editVendorAddressField.text = vendor.address || ""
        editVendorBankBranchField.text = vendor.bankBranch || ""
        editVendorIfscField.text = vendor.ifsc || ""
        editVendorAccountField.text = vendor.accountNumber || ""
        editVendorCinField.text = vendor.cin || ""
        editVendorGstinField.text = vendor.gstin || ""
        editVendorPANField.text = vendor.pan || ""
        editVendorPanNameField.text = vendor.panName || ""
        editVendorContactPersonField.text = vendor.contactPerson || ""
        editVendorEmailField.text = vendor.email || ""
        editVendorPhoneNumberField.text = vendor.phone || ""
        editVendorItemCategoryField.text = vendor.itemCategory || ""
        vendorDetailsDialog.open()
    }

    function applyPoPartDetails(partName) {
        var key = (partName || "").toString().trim()
        var partNo = poPartLookup[key]
        if (partNo !== undefined && partNo !== null) {
            poPartNoField.text = partNo.toString()
        } else if (key === "") {
            poPartNoField.text = ""
        }
        var details = poPartDetailsLookup[key]
        if (details !== undefined && details !== null) {
            poUnitPriceField.text = formatAmount(details.unitPrice)
            poDepartmentField.text = details.department || ""
            poDepartmentAutoFilled = true
            // Auto-select the vendor that belongs to this item (from the
            // Item Master); the user can still change it before adding.
            if ((details.vendor || "").toString().trim() !== "") {
                poVendorField.editText = details.vendor
            }
        } else if (poDepartmentAutoFilled) {
            // Part is not in the Item Master. Only clear a department we filled
            // in ourselves, never one the user typed for a one-off item.
            poDepartmentField.text = ""
        }
    }

    // ---- Printable purchase order ----

    property string poPreviewPoNo: ""
    property var poPreviewPages: []
    property string poPreviewPdfPath: ""

    function openPoPdfPreview(poNo) {
        poPreviewPoNo = poNo
        poPreviewCommentsField.text = ""
        refreshPoPdfPreview()
        if (poPreviewPages.length > 0)
            poPdfPreviewDialog.open()
    }

    function refreshPoPdfPreview() {
        var result = excelHandler.generatePOPreview(poPreviewPoNo,
                                                    poPreviewCommentsField.text)
        if (!result || !result.pages || result.pages.length === 0) {
            poPreviewPages = []
            poPreviewPdfPath = ""
            statusLabel.text = "Could not render the purchase order PDF"
            statusTimer.restart()
            return
        }
        poPreviewPages = result.pages
        poPreviewPdfPath = result.pdfPath
    }

    function sendPoPdf() {
        var saved = excelHandler.savePOPdf(poPreviewPoNo, "",
                                           poPreviewCommentsField.text)
        if (saved === "") return
        poLastSavedPdf = saved
        statusLabel.text = "Purchase order saved to " + saved
        statusTimer.restart()
        poPdfPreviewDialog.close()
        poSavedDialog.open()
    }

    property string poLastSavedPdf: ""

    // ---- Searchable pickers for the PO line entry ----
    //
    // The plain dropdowns stop being usable once the Item Master or vendor list
    // grows past a screenful, so both fields also get a search dialog that
    // filters across every field, not just the name.

    ListModel { id: poPartPickerModel }
    ListModel { id: poVendorPickerModel }

    function refreshPoPartPicker(filter) {
        poPartPickerModel.clear()
        var f = (filter || "").toString().trim().toLowerCase()
        var items = excelHandler.getItemMasterList()
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            var partName = (it.partName || "").toString()
            if (partName.trim() === "") continue
            var dept = (it.department || it.category || "").toString()
            var partNo = (it.partNo || "").toString()
            var vendor = (it.vendor || "").toString()
            if (f !== "" &&
                (partName + " " + partNo + " " + dept + " " + vendor).toLowerCase().indexOf(f) === -1)
                continue
            poPartPickerModel.append({
                partName: partName, partNo: partNo, department: dept, vendor: vendor,
                unitPrice: it.unitPrice || 0,
                requiredQty: it.requiredQty || it.stockQty || 0
            })
        }
    }

    function refreshPoVendorPicker(filter) {
        poVendorPickerModel.clear()
        var f = (filter || "").toString().trim().toLowerCase()
        var vendors = excelHandler.getVendorList()
        for (var i = 0; i < vendors.length; i++) {
            var v = vendors[i]
            var name = (v.vendorName || "").toString()
            if (name.trim() === "") continue
            var phone = (v.phone || "").toString()
            var email = (v.email || "").toString()
            var contact = (v.contactPerson || "").toString()
            var gstin = (v.gstin || "").toString()
            if (f !== "" &&
                (name + " " + phone + " " + email + " " + contact + " " + gstin).toLowerCase().indexOf(f) === -1)
                continue
            poVendorPickerModel.append({
                name: name, phone: phone, email: email,
                contactPerson: contact, gstin: gstin
            })
        }
    }

    function openPoPartPicker() {
        poPartSearchField.text = ""
        refreshPoPartPicker("")
        poPartPickerDialog.open()
        poPartSearchField.forceActiveFocus()
    }

    // The field the vendor picker will fill in - a ComboBox or a plain
    // TextField, whichever asked for it.
    property var vendorPickerTarget: null

    function openVendorPicker(target) {
        vendorPickerTarget = target
        poVendorSearchField.text = ""
        refreshPoVendorPicker("")
        poVendorPickerDialog.open()
        poVendorSearchField.forceActiveFocus()
    }

    function choosePoPart(partName) {
        // Prefer selecting the real dropdown entry so the ComboBox stays in
        // sync; fall back to free text for anything not in the Item Master.
        var idx = poPartNameField.find(partName)
        if (idx >= 0) poPartNameField.currentIndex = idx
        else poPartNameField.editText = partName
        applyPoPartDetails(partName)
        poPartPickerDialog.close()
    }

    function chooseVendorFromPicker(name) {
        var target = vendorPickerTarget
        if (target) {
            if (target.find !== undefined) {
                // A ComboBox: prefer selecting the real entry so it stays in
                // sync, and fall back to free text for anything not listed.
                var idx = target.find(name)
                if (idx >= 0) target.currentIndex = idx
                else target.editText = name
            } else {
                target.text = name
            }
        }
        poVendorPickerDialog.close()
    }

    Connections {
        target: excelHandler
        function onItemMasterListChanged() {
            refreshItemMasterList(itemSearchField.text)
            refreshPartNameDropdown()
            if (poDialog.visible) {
                applyPoPartDetails(poPartNameField.currentText)
            }
        }
        function onVendorListChanged() {
            refreshVendorList(vendorSearchField.text)
            refreshVendorDropdowns()
        }
    }

    property string itemOriginalPartNo: ""

    function openItemDetails(item) {
        itemOriginalPartNo = item.partNo || ""
        editItemPartNameField.text = item.partName || ""
        editItemPartNoField.text = item.partNo || ""
        editItemDepartmentField.text = item.department || ""
        editItemUnitPriceField.text = formatAmount(item.unitPrice)
        editItemRequiredQtyField.value = item.requiredQty || 0
        editItemVendorField.editText = item.vendor || ""
        editItemVendorField.currentIndex = -1
        // Setting the losing radio too: leaving it checked from the previous
        // item would show two selected buttons in the same group.
        var intangible = (item.itemType || "") === "Intangible"
        editItemIntangibleRadio.checked = intangible
        editItemTangibleRadio.checked = !intangible
        editItemHsnField.text = item.hsnCode || ""
        editItemSacField.text = item.sacCode || ""
        editItemUnitField.text = item.unit || ""
        itemDetailsDialog.open()
    }

    /* =================  ITEM MASTER DIALOG =================== */             

    Dialog {
        id: itemMasterDialog
        title: "Item Master Management"
        modal: true
        anchors.centerIn: parent
        // Takes most of the window instead of a fixed 750x650, so the item list
        // below shows many more rows at once and the wider entry form fits its
        // fields three pairs to a row.
        width: Math.min(root.width - 80, 1240)
        height: Math.min(root.height - 80, 860)

        ColumnLayout{
            anchors.fill: parent; spacing: 10

            Label { text: "Item Master"; font.bold: true; font.pixelSize: 16; color: "#2c3e50"}

            Rectangle {
                Layout.fillWidth: true
                // Height follows the form rather than a fixed 245, so the
                // classification row added below cannot push the Add button
                // past the bottom edge.
                Layout.preferredHeight: itemEntryGrid.implicitHeight + 20
                color: "#f0f8ff"; border.color: "#3498db"; radius: 5

                GridLayout {
                    id: itemEntryGrid
                    anchors.fill: parent; anchors.margins: 10
                    // Three label/field pairs per row when there is width for
                    // them, two when the window is narrow.
                    columns: width > 900 ? 6 : 4
                    rowSpacing: 8; columnSpacing: 10

                    Label { text: "Part Name:" } TextField { id: itemPartNameField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Part name" }
                    Label { text: "Part No:" } TextField { id: itemPartNoField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Part number" }
                    Label { text: "Department:" } TextField { id: itemDepartmentField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Department" }
                    Label { text: "Unit Price:" }
                    TextField {
                        id: itemUnitPriceField
                        Layout.fillWidth: true
                        Layout.preferredWidth: 150
                        placeholderText: "0.00"
                        text: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        selectByMouse: true
                    }
                    Label { text: "Required Quantity:" } SpinBox { id: itemRequiredQtyField; Layout.fillWidth: true; Layout.preferredWidth: 150; from: 0; to: 100000; value: 0; editable: true }
                    Label { text: "Vendor Preferred:" }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredWidth: 150; spacing: 6
                        ComboBox { id: itemVendorField; Layout.fillWidth: true; editable: true; model: excelHandler.getVendorNames() }
                        Button {
                            text: "\u{1F50D}"
                            Layout.preferredWidth: 40
                            ToolTip.visible: hovered
                            ToolTip.text: "Search vendors"
                            onClicked: openVendorPicker(itemVendorField)
                        }
                    }

                    // A tangible good is numbered with an HSN code, an
                    // intangible service with a SAC code, so the classification
                    // decides which code field is asked for below.
                    Label { text: "Classification:" }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredWidth: 150; spacing: 14
                        RadioButton {
                            id: itemTangibleRadio
                            text: "Tangible"; checked: true
                            ToolTip.visible: hovered
                            ToolTip.text: "A physical good, numbered with an HSN code"
                        }
                        RadioButton {
                            id: itemIntangibleRadio
                            text: "Intangible"
                            ToolTip.visible: hovered
                            ToolTip.text: "A service, numbered with a SAC code"
                        }
                    }

                    Label { text: itemTangibleRadio.checked ? "HSN Code:" : "SAC Code:" }
                    // Both codes are kept and only the one that matches the
                    // classification is shown, so flipping an item over and
                    // back never costs you the number already typed.
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 150
                        currentIndex: itemTangibleRadio.checked ? 0 : 1
                        TextField { id: itemHsnField; placeholderText: "e.g. 85015210"; selectByMouse: true }
                        TextField { id: itemSacField; placeholderText: "e.g. 998313"; selectByMouse: true }
                    }

                    // Printed on a delivery challan, so keeping it on the item
                    // saves retyping it for every delivery.
                    Label { text: "Unit:" } TextField { id: itemUnitField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Nos, Kg, Mtr..."; selectByMouse: true }

                    // Spans the whole row so the button sits at the right edge
                    // whether the grid is showing two pairs or three.
                    Button {
                        text: "Add/Update Item"; highlighted: true
                        Layout.columnSpan: itemEntryGrid.columns
                        Layout.alignment: Qt.AlignRight
                        onClicked: {
                            var itemMasterDetails = {
                                partName: itemPartNameField.text,
                                partNo: itemPartNoField.text,
                                department: itemDepartmentField.text,
                                category: itemDepartmentField.text,
                                unitPrice: parseAmount(itemUnitPriceField.text),
                                requiredQty: itemRequiredQtyField.value,
                                stockQty: itemRequiredQtyField.value,
                                vendor: itemVendorField.currentText,
                                itemType: itemTangibleRadio.checked ? "Tangible" : "Intangible",
                                hsnCode: itemHsnField.text,
                                sacCode: itemSacField.text,
                                unit: itemUnitField.text
                            }
                            if (excelHandler.addItemMasterDetails(itemMasterDetails)) {
                                refreshItemMasterList()
                                itemPartNameField.text = ""; itemPartNoField.text = ""; itemDepartmentField.text = "";
                                itemUnitPriceField.text = "0.00"; itemRequiredQtyField.value = 0; itemVendorField.currentIndex = -1;
                                itemHsnField.text = ""; itemSacField.text = ""; itemUnitField.text = "";
                                itemTangibleRadio.checked = true;
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Label { text: "Search:"; font.bold: true }
                TextField {
                    id: itemSearchField
                    Layout.fillWidth: true
                    placeholderText: "Search by part name, part no, department, vendor, HSN/SAC..."
                    selectByMouse: true
                    Keys.onReturnPressed: itemSearchButton.clicked()
                    onTextChanged: refreshItemMasterList(text)
                }
                Button {
                    id: itemSearchButton
                    text: "Search"
                    onClicked: refreshItemMasterList(itemSearchField.text)
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 5

                ListView {
                    id: itemMasterListView; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: ListModel { id: itemMasterListModel }
                    delegate: Rectangle {
                        width: itemMasterListView.width - 10; height: 70; color: "#fff"; border.color: "#e0e0e0"; radius: 4
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8
                            Item {
                                id: itemInfoArea
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 2
                                    Label {
                                        text: model.partName + " (" + model.partNo + ")"
                                        font.bold: true; font.pixelSize: 13; color: "#2c3e50"
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    Label {
                                        text: "Department: " + model.department + " | Vendor: " + model.vendor
                                        font.pixelSize: 11; color: "#7f8c8d"
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    Label {
                                        text: "Unit Price: " + formatRupees(model.unitPrice) + " | Required Qty: " + model.requiredQty +
                                              " | " + model.itemType +
                                              (model.taxCode !== "" ? " | " + (model.itemType === "Intangible" ? "SAC: " : "HSN: ") + model.taxCode : "") +
                                              (model.unit !== "" ? " | Unit: " + model.unit : "")
                                        font.pixelSize: 10; color: "#95a5a6"
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        openItemDetails({
                                            partName: model.partName,
                                            partNo: model.partNo,
                                            department: model.department,
                                            unitPrice: model.unitPrice,
                                            requiredQty: model.requiredQty,
                                            vendor: model.vendor,
                                            itemType: model.itemType,
                                            hsnCode: model.hsnCode,
                                            sacCode: model.sacCode,
                                            unit: model.unit
                                        })
                                    }
                                }
                            }
                            Button {
                                id: itemDeleteButton
                                Layout.alignment: Qt.AlignRight
                                text: "Delete"; flat: true
                                contentItem: Text { text: "Delete"; color: "#e74c3c"; font.pixelSize: 11 }
                                onClicked: { excelHandler.deleteItem(model.partName); refreshItemMasterList() }
                            }
                        }
                    }   
                }
                
                 Label { anchors.centerIn: parent; text: "No items added"; visible: itemMasterListModel.count === 0; color: "#95a5a6" }
            }

            Button { text: "Close"; Layout.alignment: Qt.AlignRight; onClicked: itemMasterDialog.close() }
        }

        onOpened: {
            refreshItemMasterList()
            refreshVendorDropdowns()
        }
    }      

    /* ================= ITEM DETAILS DIALOG ================= */

    Dialog {
        id: itemDetailsDialog
        title: "Item Details"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel
        // Wide enough for three field pairs per row, and never taller than the
        // window: the fields scroll inside rather than pushing the OK and
        // Cancel buttons off the bottom edge.
        width: Math.min(root.width - 120, 1100)
        height: Math.min(root.height - 120, 520)

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Label { text: "Edit Item Details"; font.bold: true; font.pixelSize: 14 }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

            ScrollView {
                id: editItemScroll
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                GridLayout {
                    width: editItemScroll.availableWidth
                    columns: width > 900 ? 6 : 4
                    rowSpacing: 8; columnSpacing: 10

                    Label { text: "Part Name:" } TextField { id: editItemPartNameField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Part name" }
                    Label { text: "Part No:" } TextField { id: editItemPartNoField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Part number" }
                    Label { text: "Department:" } TextField { id: editItemDepartmentField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Department" }
                    Label { text: "Unit Price:" }
                    TextField {
                        id: editItemUnitPriceField
                        Layout.fillWidth: true
                        Layout.preferredWidth: 150
                        placeholderText: "0.00"
                        text: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        selectByMouse: true
                    }
                    Label { text: "Required Quantity:" } SpinBox { id: editItemRequiredQtyField; Layout.fillWidth: true; Layout.preferredWidth: 150; from: 0; to: 100000; value: 0; editable: true }
                    Label { text: "Vendor Preferred:" }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredWidth: 150; spacing: 6
                        ComboBox { id: editItemVendorField; Layout.fillWidth: true; editable: true; model: excelHandler.getVendorNames() }
                        Button {
                            text: "\u{1F50D}"
                            Layout.preferredWidth: 40
                            ToolTip.visible: hovered
                            ToolTip.text: "Search vendors"
                            onClicked: openVendorPicker(editItemVendorField)
                        }
                    }

                    // Same pairing as the add form: the classification decides
                    // whether this item is numbered by HSN or by SAC.
                    Label { text: "Classification:" }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredWidth: 150; spacing: 14
                        RadioButton {
                            id: editItemTangibleRadio
                            text: "Tangible"; checked: true
                            ToolTip.visible: hovered
                            ToolTip.text: "A physical good, numbered with an HSN code"
                        }
                        RadioButton {
                            id: editItemIntangibleRadio
                            text: "Intangible"
                            ToolTip.visible: hovered
                            ToolTip.text: "A service, numbered with a SAC code"
                        }
                    }

                    Label { text: editItemTangibleRadio.checked ? "HSN Code:" : "SAC Code:" }
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 150
                        currentIndex: editItemTangibleRadio.checked ? 0 : 1
                        TextField { id: editItemHsnField; placeholderText: "e.g. 85015210"; selectByMouse: true }
                        TextField { id: editItemSacField; placeholderText: "e.g. 998313"; selectByMouse: true }
                    }

                    Label { text: "Unit:" } TextField { id: editItemUnitField; Layout.fillWidth: true; Layout.preferredWidth: 150; placeholderText: "Nos, Kg, Mtr..."; selectByMouse: true }
                }
            }
        }

        onAccepted: {
            var itemDetails = {
                originalPartNo: itemOriginalPartNo,
                partName: editItemPartNameField.text,
                partNo: editItemPartNoField.text,
                department: editItemDepartmentField.text,
                category: editItemDepartmentField.text,
                unitPrice: parseAmount(editItemUnitPriceField.text),
                requiredQty: editItemRequiredQtyField.value,
                stockQty: editItemRequiredQtyField.value,
                vendor: editItemVendorField.currentText,
                itemType: editItemTangibleRadio.checked ? "Tangible" : "Intangible",
                hsnCode: editItemHsnField.text,
                sacCode: editItemSacField.text,
                unit: editItemUnitField.text
            }

            if (excelHandler.updateItemMasterDetails(itemDetails)) {
                refreshItemMasterList()
            }
        }
    }
    
    function refreshItemMasterList(filterText) {
        itemMasterListModel.clear()
        var query = (filterText || "").toString().trim().toLowerCase()
        var items = excelHandler.getItemMasterList()
        for (var i = 0; i < items.length; i++){
            var item = items[i];
                var department = item.department || item.category || ""
                var requiredQty = item.requiredQty || item.stockQty || 0
                var itemType = item.itemType || "Tangible"
                var haystack = [
                    item.partName, item.partNo, department, item.vendor,
                    itemType, item.hsnCode, item.sacCode
                ].join(" ").toLowerCase()
                if (query !== "" && haystack.indexOf(query) === -1) continue
                itemMasterListModel.append({
                    partName: item.partName || "",
                    partNo: item.partNo || "",
                    department: department,
                    unitPrice: item.unitPrice || 0,
                    requiredQty: requiredQty,
                    vendor: item.vendor || "",
                    itemType: itemType,
                    hsnCode: item.hsnCode || "",
                    sacCode: item.sacCode || "",
                    // Whichever of the two the classification says to print.
                    taxCode: item.taxCode || "",
                    unit: item.unit || "",
              })
        }
        refreshPartNameDropdown(items)
    }

    property var poPartLookup: ({})
    property var poPartDetailsLookup: ({})
    // False once the user types a department by hand, which stops the Item
    // Master autofill from clearing it out from under them.
    property bool poDepartmentAutoFilled: true
    property var selectedPoPartDetails: ({})
    property var selectedPODetails: ({})
    property var selectedPOItems: []

    function refreshPartNameDropdown(items) {
        var sourceItems = items
        if (sourceItems === undefined || sourceItems === null) {
            sourceItems = excelHandler.getItemMasterList()
        }

        var partNames = []
        var lookup = ({})
        var detailsLookup = ({})

        for (var i = 0; i < sourceItems.length; i++) {
            var item = sourceItems[i]
            var partName = (item.partName || "").toString().trim()
            if (partName === "") continue

            if (lookup[partName] === undefined) {
                partNames.push(partName)
            }
            lookup[partName] = item.partNo || ""
            detailsLookup[partName] = {
                partName: partName,
                partNo: item.partNo || "",
                department: item.department || item.category || "",
                requiredQty: item.requiredQty || item.stockQty || 0,
                unitPrice: item.unitPrice || 0,
                vendor: item.vendor || "",
                // The challan has one HSN/SAC column, so it gets the code that
                // matches how the item is classified.
                hsnCode: item.taxCode || item.hsnCode || "",
                unit: item.unit || ""
            }
        }

        poPartLookup = lookup
        poPartDetailsLookup = detailsLookup
        poPartNameField.model = partNames
        dcItemNameField.model = partNames
    }

    ListModel { id: issueSearchModel }

    function refreshIssuePartDropdown(filterText) {
        issueSearchModel.clear()
        var query = (filterText || "").toString().trim().toLowerCase()
        var totalRows = excelHandler.model.rowCount()

        for (var i = 1; i < totalRows; i++) {
            var partName = (excelHandler.model.getData(i, 0) || "").toString().trim()
            if (partName === "") continue

            var stock = parseInt(excelHandler.model.getData(i, 2)) || 0
            if (stock <= 0) continue

            if (query !== "" && partName.toLowerCase().indexOf(query) === -1) continue
            issueSearchModel.append({ name: partName, stock: stock })
        }

        issuePartField.model = issueSearchModel
    }

    function parseAmount(value) {
        var n = parseFloat(value)
        return isNaN(n) ? 0 : n
    }

    function formatAmount(value) {
        return parseAmount(value).toFixed(2)
    }

    // Indian digit grouping (12,34,56,789.00) so amounts stay readable all the
    // way up to crores, matching the grouping on the printed purchase order.
    function groupIndianDigits(value) {
        var n = parseAmount(value)
        var fixed = Math.abs(n).toFixed(2)
        var dot = fixed.indexOf(".")
        var whole = fixed.substring(0, dot)
        var frac = fixed.substring(dot)
        if (whole.length > 3) {
            var last3 = whole.substring(whole.length - 3)
            var lead = whole.substring(0, whole.length - 3)
            var grouped = ""
            // Everything above the last three digits is grouped in pairs.
            while (lead.length > 2) {
                grouped = "," + lead.substring(lead.length - 2) + grouped
                lead = lead.substring(0, lead.length - 2)
            }
            whole = lead + grouped + "," + last3
        }
        return (n < 0 ? "-" : "") + whole + frac
    }

    function formatRupees(value) {
        return "\u20B9 " + groupIndianDigits(value)
    }

    // Opens the shared calendar for a date field. seedField supplies the month
    // to land on when the target is still empty, so picking the end of a period
    // starts from its beginning rather than from today.
    function openDatePicker(field, purpose, seedField) {
        expectedDateDialog.targetField = field
        expectedDateDialog.purpose = purpose
        expectedDateDialog.seedText = (field.text === "" && seedField) ? seedField.text : field.text
        expectedDateDialog.open()
    }

    // "from -> to" for a required period, collapsing to a single date when only
    // one end is known. Mirrors expectedPeriod() on the printed order.
    function formatPeriod(fromText, toText) {
        var from = (fromText || "").toString().trim()
        var to = (toText || "").toString().trim()
        if (from === "" && to === "") return "-"
        if (to === "" || from === to) return from === "" ? to : from
        if (from === "") return "up to " + to
        return from + " \u2192 " + to
    }

    // Inclusive length of the period, or 0 when it is not a usable range.
    function periodDays(fromText, toText) {
        var from = new Date(fromText)
        var to = new Date(toText)
        if (isNaN(from.getTime()) || isNaN(to.getTime())) return 0
        var days = Math.round((to.getTime() - from.getTime()) / 86400000) + 1
        return days > 0 ? days : 0
    }

    function showPoPartDetails(partName) {
        var key = (partName || "").toString().trim()
        if (key === "") return
        var details = poPartDetailsLookup[key]
        if (details === undefined || details === null) {
            statusLabel.text = "No Item Master details for: " + key
            statusTimer.restart()
            return
        }
        selectedPoPartDetails = details
        poPartDetailsDialog.open()
    }

    property string pendingPOForApproval: ""
    property string editingPONumber: ""

    /* ================= PURCHASE ORDER DIALOG ================= */

    // Items being collected for the next purchase order (the "cart").
    ListModel { id: poCartModel }
    property double poCartTotal: 0

    function recalcPoCartTotal() {
        var t = 0
        for (var i = 0; i < poCartModel.count; i++) t += poCartModel.get(i).lineTotal
        poCartTotal = t
    }

    function clearPoLineFields() {
        poPartNameField.currentIndex = -1
        poPartNameField.editText = ""
        poPartNoField.text = ""
        poDepartmentField.text = ""
        poDepartmentAutoFilled = true
        poVendorField.currentIndex = -1
        poVendorField.editText = ""
        poQtyField.value = 1
        poUnitPriceField.text = "0.00"
    }

    function addPoItemToCart() {
        var partName = (poPartNameField.editText || poPartNameField.currentText || "").toString().trim()
        var vendor = (poVendorField.editText || poVendorField.currentText || "").toString().trim()
        if (partName === "") { statusLabel.text = "Select a part first"; statusTimer.restart(); return }
        if (vendor === "") { statusLabel.text = "Select a vendor for " + partName; statusTimer.restart(); return }

        var qty = poQtyField.value
        var price = parseAmount(poUnitPriceField.text)
        poCartModel.append({
            partName: partName,
            partNo: poPartNoField.text,
            vendor: vendor,
            department: poDepartmentField.text,
            qty: qty,
            unitPrice: price,
            lineTotal: qty * price
        })
        recalcPoCartTotal()
        clearPoLineFields()
    }

    Dialog {
        id: poDialog
        title: "Purchase Order Management"
        modal: true
        anchors.centerIn: parent
        width: parent ? Math.min(1140, parent.width - 60) : 1140
        height: parent ? Math.min(840, parent.height - 60) : 840

        ColumnLayout {
            anchors.fill: parent; spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Purchase Orders"; font.bold: true; font.pixelSize: 16; color: "#2c3e50" }
                Item { Layout.fillWidth: true }
                Label {
                    text: "Raising this order for " + root.poFromRequest
                    visible: root.poFromRequest !== ""
                    font.pixelSize: 12; font.bold: true; color: "#e67e22"
                }
            }

            // Create PO Form - add one or more items to the cart, then create.
            // The card takes its height from the grid so the editors always get
            // their full height instead of being squeezed into a fixed box.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: poEntryGrid.implicitHeight + 2 * poEntryGrid.anchors.margins
                color: "#f0f8ff"; border.color: "#3498db"; radius: 5

                GridLayout {
                    id: poEntryGrid
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 14
                    columns: 4; rowSpacing: 12; columnSpacing: 16

                    // The two caption columns keep a fixed width so both field
                    // columns start on the same edge.
                    Label {
                        text: "Next PO:"; font.bold: true
                        Layout.minimumWidth: 92; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Label { text: excelHandler.getNextPONumber(); color: "#3498db"; font.bold: true; Layout.fillWidth: true }
                    Label {
                        text: "Date:"
                        Layout.minimumWidth: 92; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    Label { text: Qt.formatDate(new Date(), "yyyy-MM-dd"); Layout.fillWidth: true }

                    Label {
                        text: "Part Name*:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        ComboBox {
                            id: poPartNameField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 180
                            editable: true
                            model: []
                            onCurrentTextChanged: applyPoPartDetails(currentText)
                            onActivated: function(index) {
                                if (index >= 0) showPoPartDetails(currentText)
                            }
                        }
                        Button {
                            text: "\u{1F50D}"
                            Layout.preferredWidth: 40
                            ToolTip.visible: hovered
                            ToolTip.text: "Search the Item Master"
                            onClicked: openPoPartPicker()
                        }
                        Button {
                            text: "i"
                            font.bold: true
                            Layout.preferredWidth: 34
                            ToolTip.visible: hovered
                            ToolTip.text: "Show selected part details"
                            onClicked: showPoPartDetails(poPartNameField.currentText)
                        }
                    }
                    Label {
                        text: "Vendor*:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        ComboBox {
                            id: poVendorField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 180
                            editable: true
                            model: excelHandler.getVendorNames()
                        }
                        Button {
                            text: "\u{1F50D}"
                            Layout.preferredWidth: 40
                            ToolTip.visible: hovered
                            ToolTip.text: "Search vendors"
                            onClicked: openVendorPicker(poVendorField)
                        }
                    }

                    Label {
                        text: "Part No:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField { id: poPartNoField; Layout.fillWidth: true; placeholderText: "Part number"; selectByMouse: true }
                    Label {
                        text: "Department:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField {
                        id: poDepartmentField
                        Layout.fillWidth: true
                        selectByMouse: true
                        placeholderText: "Auto-filled from Item Master, or type one"
                        // textEdited fires only on user input, so the autofill
                        // above does not count as the user claiming the field.
                        onTextEdited: poDepartmentAutoFilled = false
                    }

                    Label {
                        text: "Qty*:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    SpinBox { id: poQtyField; from: 1; to: 100000; value: 1; editable: true; Layout.fillWidth: true }
                    Label {
                        text: "Unit Price:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Label { text: "\u20B9"; font.bold: true; color: "#2c3e50" }
                        TextField {
                            id: poUnitPriceField
                            Layout.fillWidth: true
                            // Wide enough to show a crore-scale rate in full.
                            Layout.minimumWidth: 170
                            placeholderText: "0.00"
                            text: "0.00"
                            horizontalAlignment: TextInput.AlignRight
                            validator: DoubleValidator { bottom: 0; decimals: 2 }
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            selectByMouse: true
                        }
                    }

                    Label {
                        text: "Line Total:"; font.bold: true
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    // Spans both field columns so even a crore total fits.
                    Label {
                        text: formatRupees(poQtyField.value * parseAmount(poUnitPriceField.text))
                        color: "#27ae60"
                        font.bold: true
                        font.pixelSize: 15
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                    }
                    Button {
                        text: "+ Add Item"
                        highlighted: true
                        Layout.minimumWidth: 120
                        Layout.alignment: Qt.AlignRight
                        onClicked: addPoItemToCart()
                    }
                }
            }

            // Cart: items that will go into this PO. It grows with the item
            // count up to four rows and then scrolls, so an empty cart does not
            // steal vertical room from the PO list below.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: poCartModel.count === 0
                                        ? 64
                                        : Math.min(196, 48 + poCartModel.count * 40)
                border.color: "#3498db"; radius: 5; color: "#fbfdff"

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 6

                    // Column captions, matching the delegate widths below, so
                    // the qty/rate/amount columns read as a table.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6; Layout.rightMargin: 6
                        spacing: 10
                        visible: poCartModel.count > 0
                        Label { text: "Item"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.fillWidth: true }
                        Label { text: "Vendor"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 190 }
                        Label { text: "Qty"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                        Label { text: "Rate"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 170; horizontalAlignment: Text.AlignRight }
                        Label { text: "Amount"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 180; horizontalAlignment: Text.AlignRight }
                        Item { Layout.preferredWidth: 30 }
                    }

                    ListView {
                        id: poCartView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 6
                        model: poCartModel
                        delegate: Rectangle {
                            width: poCartView.width; height: 34
                            color: "#fff"; border.color: "#e0e0e0"; radius: 3
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 3; anchors.bottomMargin: 3
                                spacing: 10
                                Label {
                                    text: (index + 1) + ". " + model.partName
                                    font.bold: true; font.pixelSize: 11
                                    Layout.fillWidth: true; Layout.minimumWidth: 120
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: model.vendor
                                    font.pixelSize: 11; color: "#7f8c8d"
                                    Layout.preferredWidth: 190; elide: Text.ElideRight
                                }
                                Label {
                                    text: model.qty
                                    font.pixelSize: 11; color: "#2c3e50"
                                    Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight
                                }
                                Label {
                                    text: formatRupees(model.unitPrice)
                                    font.pixelSize: 11; color: "#2c3e50"
                                    Layout.preferredWidth: 170; horizontalAlignment: Text.AlignRight
                                }
                                Label {
                                    text: formatRupees(model.lineTotal)
                                    font.pixelSize: 12; font.bold: true; color: "#27ae60"
                                    Layout.preferredWidth: 180; horizontalAlignment: Text.AlignRight
                                }
                                Button {
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 24
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Remove this item"
                                    onClicked: { poCartModel.remove(index); recalcPoCartTotal() }
                                    contentItem: Text { text: "X"; color: "#e74c3c"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "No items added - use \"+ Add Item\" above (a PO can hold several items)"
                    visible: poCartModel.count === 0; color: "#95a5a6"; font.pixelSize: 11
                }
            }

            // The period the goods are needed in, plus who prepared the order
            RowLayout {
                Layout.fillWidth: true; spacing: 10

                Label { text: "Needed from:"; font.bold: true }
                TextField {
                    id: poExpectedField
                    Layout.preferredWidth: 120
                    placeholderText: "YYYY-MM-DD"
                    readOnly: true
                    selectByMouse: true
                }
                Button {
                    text: "\u{1F4C5}"
                    Layout.preferredWidth: 38
                    ToolTip.visible: hovered
                    ToolTip.text: "Pick the start of the period"
                    onClicked: openDatePicker(poExpectedField, "period start")
                }

                Label { text: "to:"; font.bold: true }
                TextField {
                    id: poExpectedEndField
                    Layout.preferredWidth: 120
                    placeholderText: "YYYY-MM-DD"
                    readOnly: true
                    selectByMouse: true
                }
                Button {
                    text: "\u{1F4C5}"
                    Layout.preferredWidth: 38
                    ToolTip.visible: hovered
                    ToolTip.text: "Pick the end of the period"
                    onClicked: openDatePicker(poExpectedEndField, "period end", poExpectedField)
                }
                Button {
                    text: "\u2715"
                    Layout.preferredWidth: 32
                    enabled: poExpectedField.text !== "" || poExpectedEndField.text !== ""
                    ToolTip.visible: hovered
                    ToolTip.text: "Clear the period"
                    onClicked: { poExpectedField.text = ""; poExpectedEndField.text = "" }
                }

                // Reads back the period so the requirement is unmistakable, and
                // says so plainly when the dates are the wrong way round.
                Label {
                    property int days: periodDays(poExpectedField.text, poExpectedEndField.text)
                    property bool reversed: poExpectedField.text !== "" &&
                                            poExpectedEndField.text !== "" &&
                                            poExpectedEndField.text < poExpectedField.text
                    text: reversed
                          ? "End date is before the start date"
                          : (days > 0 ? days + (days === 1 ? " day" : " days") : "")
                    color: reversed ? "#e74c3c" : "#7f8c8d"
                    font.pixelSize: 11
                    font.bold: reversed
                }

                Item { Layout.fillWidth: true }

                Label { text: "Prepared By*:" }
                TextField {
                    id: poPreparedByField
                    Layout.preferredWidth: 180
                    placeholderText: "Enter preparer name"
                    text: excelHandler.currentUser
                    selectByMouse: true
                }
            }

            // Cart total + create
            RowLayout {
                Layout.fillWidth: true; spacing: 12

                Item { Layout.fillWidth: true }

                // Cart total gets its own boxed area so it stays legible even
                // at crore values instead of squeezing the fields beside it.
                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 38
                    Layout.leftMargin: 6
                    color: "#eafaf1"; border.color: "#27ae60"; radius: 4
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        Label { text: "Total"; font.bold: true; color: "#2c3e50"; font.pixelSize: 12 }
                        Label {
                            text: formatRupees(poCartTotal)
                            font.bold: true; font.pixelSize: 15; color: "#27ae60"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Button {
                    text: "Create PO (" + poCartModel.count + (poCartModel.count === 1 ? " item)" : " items)")
                    highlighted: true
                    enabled: poCartModel.count > 0
                    onClicked: {
                        // A backwards period would print nonsense on the order,
                        // so stop before anything is written.
                        if (poExpectedField.text !== "" && poExpectedEndField.text !== "" &&
                            poExpectedEndField.text < poExpectedField.text) {
                            statusLabel.text = "Needed period: the end date cannot be before the start date"
                            statusTimer.restart()
                            return
                        }
                        var items = []
                        for (var i = 0; i < poCartModel.count; i++) {
                            var it = poCartModel.get(i)
                            items.push({
                                partName: it.partName, partNo: it.partNo,
                                vendor: it.vendor, department: it.department,
                                qty: it.qty, unitPrice: it.unitPrice
                            })
                        }
                        var poNo = excelHandler.createPurchaseOrderItems(
                            items, poExpectedField.text, poExpectedEndField.text,
                            poPreparedByField.text)
                        if (poNo !== "") {
                            poCartModel.clear()
                            recalcPoCartTotal()
                            poExpectedField.text = ""
                            poExpectedEndField.text = ""
                            refreshPOList()
                            // Only now that the order really exists is the
                            // request marked as bought.
                            if (root.poFromRequest !== "") {
                                excelHandler.linkRequestToPO(root.poFromRequest, poNo)
                                statusLabel.text = poNo + " raised for " + root.poFromRequest
                                statusTimer.restart()
                                root.poFromRequest = ""
                                refreshPRList()
                            }
                            openPoPdfPreview(poNo)
                        }
                    }
                }
            }

            // Status filter + free-text search across the PO list
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 4; spacing: 10

                Label { text: "Filter:"; font.bold: true }
                ComboBox {
                    id: poFilterCombo
                    Layout.preferredWidth: 170
                    model: ["All", "Draft", "Sent", "Partially Received", "Received", "Closed"]
                    onCurrentTextChanged: refreshPOList()
                }

                Label { text: "Search:"; font.bold: true; Layout.leftMargin: 6 }
                TextField {
                    id: poSearchField
                    Layout.fillWidth: true
                    Layout.minimumWidth: 240
                    placeholderText: "PO number, vendor, part name, or date (e.g. 2026-08)"
                    selectByMouse: true
                    onTextChanged: applyPoSearch()
                    // Clear the search first; only pass Escape on to the dialog
                    // once there is nothing left to clear.
                    Keys.onEscapePressed: function(event) {
                        if (text !== "") text = ""
                        else event.accepted = false
                    }
                }
                Button {
                    text: "\u2715"
                    Layout.preferredWidth: 34
                    enabled: poSearchField.text !== ""
                    ToolTip.visible: hovered
                    ToolTip.text: "Clear the search"
                    onClicked: poSearchField.text = ""
                }

                Label {
                    text: poSearchField.text.trim() === ""
                          ? poListModel.count + (poListModel.count === 1 ? " PO" : " POs")
                          : poListModel.count + " of " + poRowsCache.length + " match"
                    color: "#7f8c8d"; font.pixelSize: 11
                }
                Label { text: "Pending: " + excelHandler.pendingPOCount; font.bold: true; color: "#e67e22" }
            }

            // PO List
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 5

                ListView {
                    id: poListView; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: ListModel { id: poListModel }
                    delegate: Rectangle {
                        width: poListView.width - 10; height: 78
                        color: {
                            if (model.status === "Received") return "#e8f8e8"
                            if (model.status === "Draft") return "#fff8e8"
                            return "#fff"
                        }
                        border.color: "#e0e0e0"; radius: 4

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10
                            spacing: 12
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.minimumWidth: 180; spacing: 3
                                RowLayout {
                                    spacing: 8
                                    Label { text: model.poNo; font.bold: true; font.pixelSize: 13; color: "#2c3e50" }
                                    Label {
                                        text: model.status
                                        font.pixelSize: 11; font.bold: true
                                        color: {
                                            if (model.status === "Draft") return "#f39c12"
                                            if (model.status === "Sent") return "#3498db"
                                            if (model.status === "Received") return "#27ae60"
                                            if (model.status === "Partially Received") return "#e67e22"
                                            return "#95a5a6"
                                        }
                                    }
                                }
                                Label {
                                    text: model.partName + "  |  Qty: " + model.qty + "  |  Vendor: " + model.vendor
                                    font.pixelSize: 11; color: "#7f8c8d"
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Label {
                                    text: "Date: " + model.date +
                                          "  |  Needed: " + formatPeriod(model.expectedDate, model.expectedEndDate) +
                                          "  |  Received: " + model.receivedQty + "/" + model.qty +
                                          "  |  Rec Date: " + (model.receivedDate || "-")
                                    font.pixelSize: 10
                                    color: "#95a5a6"
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            // Amounts get a dedicated right-aligned column so a
                            // crore-scale total is never elided by the details.
                            ColumnLayout {
                                Layout.preferredWidth: 200
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2
                                Label {
                                    text: formatRupees(model.totalAmount)
                                    font.bold: true; font.pixelSize: 14; color: "#27ae60"
                                    Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                                }
                                Label {
                                    // A single rate only means something on a
                                    // one-line PO; otherwise show the line count.
                                    text: model.unitPrice > 0
                                          ? formatRupees(model.unitPrice) + " / unit"
                                          : (model.itemCount > 1 ? model.itemCount + " line items" : "")
                                    visible: text !== ""
                                    font.pixelSize: 10; color: "#95a5a6"
                                    Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                                }
                            }

                            // Status buttons
                            Button {
                                text: "View"
                                onClicked: {
                                    selectedPODetails = {
                                        poNo: model.poNo,
                                        date: model.date,
                                        vendor: model.vendor,
                                        partName: model.partName,
                                        partNo: model.partNo,
                                        department: model.department || "",
                                        qty: model.qty,
                                        unitPrice: model.unitPrice,
                                        totalAmount: model.totalAmount,
                                        expectedDate: model.expectedDate,
                                        expectedEndDate: model.expectedEndDate,
                                        status: model.status,
                                        receivedQty: model.receivedQty,
                                        preparedBy: model.preparedBy || "",
                                        approvedBy: model.approvedBy || "",
                                        receivedBy: model.receivedBy || "",
                                        receivedDate: model.receivedDate || ""
                                    }
                                    selectedPOItems = excelHandler.getPOItems(model.poNo)
                                    poDetailsDialog.open()
                                }
                                contentItem: Text { text: "View"; color: "#2c3e50"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Edit"
                                visible: model.status !== "Received" && model.status !== "Closed" &&
                                         (model.itemCount === undefined || model.itemCount <= 1)
                                onClicked: {
                                    editingPONumber = model.poNo
                                    editPoVendorField.text = model.vendor || ""
                                    editPoPartNameField.text = model.partName || ""
                                    editPoPartNoField.text = model.partNo || ""
                                    editPoDepartmentField.text = model.department || ""
                                    editPoQtyField.value = model.qty || 1
                                    editPoUnitPriceField.text = formatAmount(model.unitPrice)
                                    editPoExpectedField.text = model.expectedDate || ""
                                    editPoExpectedEndField.text = model.expectedEndDate || ""
                                    editPoPreparedByField.text = model.preparedBy || excelHandler.currentUser
                                    poEditDialog.open()
                                }
                                contentItem: Text { text: "Edit"; color: "#8e44ad"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Send"
                                visible: model.status === "Draft"
                                onClicked: {
                                    pendingPOForApproval = model.poNo
                                    approvedByField.text = ""
                                    approvalDialog.open()
                                }
                                contentItem: Text { text: "Send"; color: "#3498db"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Receive"
                                visible: model.status === "Sent" || model.status === "Partially Received"
                                onClicked: {
                                    grnPOFieldText = model.poNo
                                    grnLoadItems(model.poNo)
                                    grnRejectedField.value = 0
                                    grnReceivedByField.text = excelHandler.currentUser
                                    grnDialog.open()
                                }
                                contentItem: Text { text: "Receive"; color: "#27ae60"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Close"
                                visible: model.status === "Received"
                                onClicked: { excelHandler.updatePOStatus(model.poNo, "Closed"); refreshPOList() }
                                contentItem: Text { text: "Close"; color: "#95a5a6"; font.pixelSize: 11 }
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: poSearchField.text.trim() === ""
                          ? "No purchase orders"
                          : "No purchase orders match \"" + poSearchField.text.trim() + "\""
                    visible: poListModel.count === 0; color: "#95a5a6"
                }
            }

            Button { text: "Close"; Layout.alignment: Qt.AlignRight; onClicked: poDialog.close() }
        }

        onOpened: {
            poSearchField.text = ""
            refreshPOList()
            refreshVendorDropdowns()
            refreshPartNameDropdown()
        }

        // Closing without ordering abandons the hand-off, so the request stays
        // approved and waiting rather than being marked as bought.
        onClosed: root.poFromRequest = ""
    }

    Dialog {
        id: approvalDialog
        title: "Approve PO"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 380

        ColumnLayout {
            spacing: 10
            Label { text: "PO: " + pendingPOForApproval; font.bold: true }
            Label { text: "Approved By*:" }
            TextField {
                id: approvedByField
                Layout.fillWidth: true
                placeholderText: "Enter approver name"
                selectByMouse: true
            }
        }

        onAccepted: {
            if (excelHandler.sendPOForApproval(pendingPOForApproval, approvedByField.text)) {
                refreshPOList()
            }
        }
    }

    Dialog {
        id: poEditDialog
        title: "Edit Purchase Order"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 560

        ColumnLayout {
            spacing: 10
            width: parent.width

            Label { text: "PO: " + editingPONumber; font.bold: true; color: "#2c3e50" }

            GridLayout {
                columns: 2
                rowSpacing: 8
                columnSpacing: 10
                Layout.fillWidth: true

                Label { text: "Vendor:" }
                TextField { id: editPoVendorField; Layout.fillWidth: true; selectByMouse: true }

                Label { text: "Part Name:" }
                TextField { id: editPoPartNameField; Layout.fillWidth: true; selectByMouse: true }

                Label { text: "Part No:" }
                TextField { id: editPoPartNoField; Layout.fillWidth: true; selectByMouse: true }

                Label { text: "Department:" }
                TextField { id: editPoDepartmentField; Layout.fillWidth: true; selectByMouse: true }

                Label { text: "Qty:" }
                SpinBox { id: editPoQtyField; from: 1; to: 100000; value: 1; editable: true; Layout.fillWidth: true }

                Label { text: "Unit Price:" }
                TextField {
                    id: editPoUnitPriceField
                    Layout.fillWidth: true
                    Layout.minimumWidth: 170
                    placeholderText: "0.00"
                    text: "0.00"
                    horizontalAlignment: TextInput.AlignRight
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    selectByMouse: true
                }

                Label { text: "Needed From:" }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    TextField {
                        id: editPoExpectedField
                        Layout.fillWidth: true
                        placeholderText: "YYYY-MM-DD"
                        selectByMouse: true
                    }
                    Button {
                        text: "\u{1F4C5}"
                        Layout.preferredWidth: 38
                        ToolTip.visible: hovered
                        ToolTip.text: "Pick the start of the period"
                        onClicked: openDatePicker(editPoExpectedField, "period start")
                    }
                }

                Label { text: "Needed To:" }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    TextField {
                        id: editPoExpectedEndField
                        Layout.fillWidth: true
                        placeholderText: "YYYY-MM-DD (optional)"
                        selectByMouse: true
                    }
                    Button {
                        text: "\u{1F4C5}"
                        Layout.preferredWidth: 38
                        ToolTip.visible: hovered
                        ToolTip.text: "Pick the end of the period"
                        onClicked: openDatePicker(editPoExpectedEndField, "period end", editPoExpectedField)
                    }
                }

                Label { text: "Prepared By:" }
                TextField { id: editPoPreparedByField; Layout.fillWidth: true; selectByMouse: true }
            }

            Label {
                text: "Total: " + formatRupees(editPoQtyField.value * parseAmount(editPoUnitPriceField.text))
                font.bold: true
                font.pixelSize: 15
                color: "#27ae60"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
            }
        }

        onAccepted: {
                if (editPoExpectedField.text !== "" && editPoExpectedEndField.text !== "" &&
                    editPoExpectedEndField.text < editPoExpectedField.text) {
                    statusLabel.text = "Needed period: the end date cannot be before the start date"
                    statusTimer.restart()
                    return
                }
                var payload = {
                    vendor: editPoVendorField.text,
                    partName: editPoPartNameField.text,
                    partNo: editPoPartNoField.text,
                    department: editPoDepartmentField.text,
                    qty: editPoQtyField.value,
                    unitPrice: parseAmount(editPoUnitPriceField.text),
                    expectedDate: editPoExpectedField.text,
                    expectedEndDate: editPoExpectedEndField.text,
                    preparedBy: editPoPreparedByField.text
                }

            if (excelHandler.updatePurchaseOrder(editingPONumber, payload)) {
                refreshPOList()
            }
        }
    }

    Dialog {
        id: poDetailsDialog
        title: "PO Details"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        width: 680

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            Label { text: "PO No: " + (selectedPODetails.poNo || "-"); font.bold: true; color: "#2c3e50" }

            // Line items of this PO (each with its own vendor)
            Label { text: "Items (" + selectedPOItems.length + "):"; font.bold: true }
            Repeater {
                model: selectedPOItems
                Label {
                    text: "  " + (index + 1) + ". " + (modelData.partName || "-") +
                          " (" + (modelData.partNo || "-") + ")  x" + (modelData.qty || 0) +
                          " @ " + formatRupees(modelData.unitPrice || 0) +
                          "  | Vendor: " + (modelData.vendor || "-") +
                          "  | Recv: " + (modelData.receivedQty || 0) + "/" + (modelData.qty || 0)
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            Label { text: "Department: " + (selectedPODetails.department || "-"); visible: selectedPOItems.length <= 1 }
            Label { text: "Vendor(s): " + (selectedPODetails.vendor || "-") }
            Label { text: "Total Qty: " + (selectedPODetails.qty || 0) }
            Label { text: "Total Price: " + formatRupees(selectedPODetails.totalAmount || 0); font.bold: true; color: "#27ae60" }
            Label {
                text: "Needed Period: " + formatPeriod(selectedPODetails.expectedDate,
                                                       selectedPODetails.expectedEndDate)
                font.bold: true
            }
            Label { text: "Status: " + (selectedPODetails.status || "-") }
            Label { text: "Prepared By: " + (selectedPODetails.preparedBy || "-") }
            Label { text: "Approved By: " + (selectedPODetails.approvedBy || "-") }
            Label { text: "Received By: " + (selectedPODetails.receivedBy || "-") }
            Label { text: "Received Date: " + (selectedPODetails.receivedDate || "-") }
            Label { text: "Received Qty: " + (selectedPODetails.receivedQty || 0) + " / " + (selectedPODetails.qty || 0) }
        }
    }

    Dialog {
        id: poPdfPreviewDialog
        title: "Purchase Order " + poPreviewPoNo
        modal: true
        anchors.centerIn: parent
        width: Math.min(root.width - 80, 940)
        height: Math.min(root.height - 60, 900)
        standardButtons: Dialog.NoButton

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: "Comments:" }
                TextField {
                    id: poPreviewCommentsField
                    Layout.fillWidth: true
                    placeholderText: "Optional special instructions printed on the order"
                    selectByMouse: true
                    // Re-render on commit rather than per keystroke; a full
                    // re-layout per character would be wasteful.
                    onEditingFinished: if (poPreviewPoNo !== "") refreshPoPdfPreview()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#525659"
                radius: 4

                ListView {
                    id: poPreviewView
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    spacing: 12
                    model: poPreviewPages
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        width: poPreviewView.width - 20
                        // A4 aspect ratio, so the page keeps its proportions
                        // whatever the dialog is resized to.
                        height: width * 297 / 210
                        color: "white"
                        border.color: "#2c2c2c"

                        Image {
                            anchors.fill: parent
                            source: modelData
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            cache: false
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: poPreviewPages.length + (poPreviewPages.length === 1 ? " page" : " pages")
                    font.pixelSize: 11
                    color: "#7f8c8d"
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Open in PDF viewer"
                    onClicked: excelHandler.openInSystemViewer(poPreviewPdfPath)
                }
                Button {
                    text: "Close"
                    onClicked: poPdfPreviewDialog.close()
                }
                Button {
                    text: "Send"
                    highlighted: true
                    ToolTip.visible: hovered
                    ToolTip.text: "Save this purchase order as a PDF on this computer"
                    onClicked: sendPoPdf()
                }
            }
        }
    }

    Dialog {
        id: poSavedDialog
        title: "Purchase Order Saved"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        width: 560

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Label { text: "The purchase order PDF has been saved to:"; font.bold: true }
            Label {
                text: poLastSavedPdf
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
                color: "#2c3e50"
            }
            Button {
                text: "Open the file"
                onClicked: excelHandler.openInSystemViewer(poLastSavedPdf)
            }
        }
    }

    Dialog {
        id: companyProfileDialog
        title: "Company Profile"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Save | Dialog.Cancel
        width: 560

        // These details head every printed purchase order, so they are worth
        // filling in once before sending anything to a vendor.
        onOpened: {
            var c = excelHandler.getCompanyProfile()
            companyNameField.text = c.name || ""
            companyAddr1Field.text = c.addressLine1 || ""
            companyAddr2Field.text = c.addressLine2 || ""
            companyCityField.text = c.city || ""
            companyPhoneField.text = c.phone || ""
            companyEmailField.text = c.email || ""
            companyWebsiteField.text = c.website || ""
            companyGstinField.text = c.gstin || ""
        }

        onAccepted: {
            excelHandler.saveCompanyProfile({
                name: companyNameField.text,
                addressLine1: companyAddr1Field.text,
                addressLine2: companyAddr2Field.text,
                city: companyCityField.text,
                phone: companyPhoneField.text,
                email: companyEmailField.text,
                website: companyWebsiteField.text,
                gstin: companyGstinField.text
            })
            statusLabel.text = "Company profile saved"
            statusTimer.restart()
        }

        GridLayout {
            anchors.fill: parent
            columns: 2
            columnSpacing: 10
            rowSpacing: 8

            Label { text: "Company Name:" }
            TextField { id: companyNameField; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "Address Line 1:" }
            TextField { id: companyAddr1Field; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "Address Line 2:" }
            TextField { id: companyAddr2Field; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "City / State:" }
            TextField { id: companyCityField; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "Phone:" }
            TextField { id: companyPhoneField; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "Email:" }
            TextField { id: companyEmailField; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "Website:" }
            TextField { id: companyWebsiteField; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "GSTIN:" }
            TextField { id: companyGstinField; Layout.fillWidth: true; selectByMouse: true }
        }
    }

    Dialog {
        id: poPartPickerDialog
        title: "Search Item Master"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel
        width: 640
        height: 520

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            TextField {
                id: poPartSearchField
                Layout.fillWidth: true
                placeholderText: "Search by part name, part no, department or vendor..."
                selectByMouse: true
                onTextChanged: refreshPoPartPicker(text)
                // Enter picks the top hit, so a search can be done without
                // ever leaving the keyboard.
                Keys.onReturnPressed: {
                    if (poPartPickerModel.count > 0)
                        choosePoPart(poPartPickerModel.get(0).partName)
                }
            }

            Label {
                text: poPartPickerModel.count + (poPartPickerModel.count === 1 ? " item" : " items")
                font.pixelSize: 11
                color: "#7f8c8d"
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 5

                Label {
                    anchors.centerIn: parent
                    visible: poPartPickerModel.count === 0
                    text: "No matching items"
                    color: "#95a5a6"
                }

                ListView {
                    id: poPartPickerView
                    anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: poPartPickerModel
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        width: poPartPickerView.width - 10; height: 58
                        color: partPickerMouse.containsMouse ? "#eaf4fd" : "#fff"
                        border.color: "#e0e0e0"; radius: 4

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 2
                            Label {
                                text: model.partName + (model.partNo !== "" ? "  (" + model.partNo + ")" : "")
                                font.bold: true; font.pixelSize: 13; color: "#2c3e50"
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Label {
                                text: "Dept: " + (model.department !== "" ? model.department : "-")
                                      + "  |  Vendor: " + (model.vendor !== "" ? model.vendor : "-")
                                      + "  |  " + formatRupees(model.unitPrice)
                                font.pixelSize: 11; color: "#7f8c8d"
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: partPickerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: choosePoPart(model.partName)
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: poVendorPickerDialog
        title: "Search Vendors"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel
        width: 640
        height: 520

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            TextField {
                id: poVendorSearchField
                Layout.fillWidth: true
                placeholderText: "Search by name, contact person, phone, email or GSTIN..."
                selectByMouse: true
                onTextChanged: refreshPoVendorPicker(text)
                Keys.onReturnPressed: {
                    if (poVendorPickerModel.count > 0)
                        chooseVendorFromPicker(poVendorPickerModel.get(0).name)
                }
            }

            Label {
                text: poVendorPickerModel.count + (poVendorPickerModel.count === 1 ? " vendor" : " vendors")
                font.pixelSize: 11
                color: "#7f8c8d"
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 5

                Label {
                    anchors.centerIn: parent
                    visible: poVendorPickerModel.count === 0
                    text: "No matching vendors"
                    color: "#95a5a6"
                }

                ListView {
                    id: poVendorPickerView
                    anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: poVendorPickerModel
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        width: poVendorPickerView.width - 10; height: 58
                        color: vendorPickerMouse.containsMouse ? "#eaf4fd" : "#fff"
                        border.color: "#e0e0e0"; radius: 4

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 2
                            Label {
                                text: model.name
                                font.bold: true; font.pixelSize: 13; color: "#2c3e50"
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Label {
                                text: (model.contactPerson !== "" ? model.contactPerson + "  |  " : "")
                                      + (model.phone !== "" ? model.phone : "-")
                                      + (model.email !== "" ? "  |  " + model.email : "")
                                font.pixelSize: 11; color: "#7f8c8d"
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: vendorPickerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: chooseVendorFromPicker(model.name)
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: poPartDetailsDialog
        title: "Item Master Details"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        width: 430

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Label { text: "Part Name: " + (selectedPoPartDetails.partName || "-"); font.bold: true; color: "#2c3e50" }
            Label { text: "Part No: " + (selectedPoPartDetails.partNo || "-") }
            Label { text: "Department: " + (selectedPoPartDetails.department || "-") }
            Label { text: "Required Quantity: " + (selectedPoPartDetails.requiredQty || 0) }
            Label { text: "Unit Price: " + formatRupees(selectedPoPartDetails.unitPrice || 0); color: "#27ae60"; font.bold: true }
            Label { text: "Preferred Vendor: " + (selectedPoPartDetails.vendor || "-") }
        }
    }

    // Shared by every date field in the PO screens; openDatePicker() below sets
    // which field the pick lands in and what to seed the calendar with.
    Dialog {
        id: expectedDateDialog
        title: "Select " + purpose
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 420
        height: 420
        property int displayMonth: (new Date()).getMonth() + 1
        property int displayYear: (new Date()).getFullYear()
        property date selectedDate: new Date()
        property var targetField: null
        property string purpose: "Date"
        property string seedText: ""

        onOpened: {
            var parsed = new Date(seedText)
            if (!isNaN(parsed.getTime())) {
                selectedDate = parsed
            } else {
                selectedDate = new Date()
            }
            displayMonth = selectedDate.getMonth() + 1
            displayYear = selectedDate.getFullYear()
        }

        onAccepted: {
            if (targetField) targetField.text = Qt.formatDate(selectedDate, "yyyy-MM-dd")
        }

        ColumnLayout {
            anchors.fill: parent
            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: "<"
                    onClicked: {
                        expectedDateDialog.displayMonth--
                        if (expectedDateDialog.displayMonth < 1) {
                            expectedDateDialog.displayMonth = 12
                            expectedDateDialog.displayYear--
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(new Date(expectedDateDialog.displayYear,
                                                 expectedDateDialog.displayMonth - 1, 1),
                                        "MMMM yyyy")
                    font.bold: true
                }
                Button {
                    text: ">"
                    onClicked: {
                        expectedDateDialog.displayMonth++
                        if (expectedDateDialog.displayMonth > 12) {
                            expectedDateDialog.displayMonth = 1
                            expectedDateDialog.displayYear++
                        }
                    }
                }
            }

            BasicControls.DayOfWeekRow {
                locale: Qt.locale()
                Layout.fillWidth: true
            }

            BasicControls.MonthGrid {
                id: expectedDateMonthGrid
                month: expectedDateDialog.displayMonth
                year: expectedDateDialog.displayYear
                locale: Qt.locale()
                Layout.fillWidth: true
                Layout.fillHeight: true

                onClicked: function(date) {
                    expectedDateDialog.selectedDate = date
                }

                delegate: Rectangle {
                    required property var model
                    color: {
                        var selected = Qt.formatDate(expectedDateDialog.selectedDate, "yyyy-MM-dd")
                        var current = Qt.formatDate(model.date, "yyyy-MM-dd")
                        if (selected === current) return "#3498db"
                        return "transparent"
                    }
                    radius: width / 2

                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        color: {
                            if (Qt.formatDate(expectedDateDialog.selectedDate, "yyyy-MM-dd") ===
                                Qt.formatDate(model.date, "yyyy-MM-dd")) {
                                return "white"
                            }
                            return model.month === expectedDateMonthGrid.month ? "#2c3e50" : "#bdc3c7"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: expectedDateDialog.selectedDate = model.date
                    }
                }
            }
        }
    }

    // Rows for the current status filter, plus the poNo -> searchable-text map
    // from the backend. Both are fetched once per refresh so typing in the
    // search box neither re-queries nor rebuilds any strings per keystroke.
    property var poRowsCache: []
    property var poSearchIndex: ({})

    function refreshPOList() {
        var filter = poFilterCombo.currentText === "All" ? "" : poFilterCombo.currentText
        poRowsCache = excelHandler.getPOList(filter)
        poSearchIndex = excelHandler.getPOSearchIndex()
        applyPoSearch()
    }

    // Each whitespace-separated word must appear somewhere in the order, so
    // extra words narrow the result down instead of widening it: "acme bolt"
    // wants both, and "2026-08 draft" is a date-plus-status search.
    function applyPoSearch() {
        var terms = poSearchField.text.toLowerCase().trim().split(/\s+/)
        poListModel.clear()
        for (var i = 0; i < poRowsCache.length; i++) {
            var haystack = poSearchIndex[poRowsCache[i].poNo] || ""
            var matches = true
            for (var t = 0; t < terms.length; t++) {
                if (terms[t] === "") continue
                if (haystack.indexOf(terms[t]) === -1) { matches = false; break }
            }
            if (matches) poListModel.append(poRowsCache[i])
        }
    }

    /* ================= PURCHASE REQUEST (PR) ================= */

    // What is being asked for in the request being written, and the queue of
    // requests everyone can see.
    ListModel { id: prCartModel }
    ListModel { id: prListModel }

    property var prRowsCache: []
    property var prSearchIndex: ({})

    // Empty while writing a new request; the request number while editing one.
    property string editingPRNumber: ""
    property var selectedPRDetails: ({})
    property var selectedPRItems: []
    property string prPendingDelete: ""
    property string prPendingReview: ""
    property string prReviewAction: ""

    // Set while a purchase order is being raised for a request, so the two can
    // be linked the moment the order actually exists.
    property string poFromRequest: ""

    function prCartValue() {
        var t = 0
        for (var i = 0; i < prCartModel.count; i++) {
            var it = prCartModel.get(i)
            t += it.qty * it.estimatedPrice
        }
        return t
    }

    // Fills the blank line fields from the Item Master, so asking for a
    // catalogued part means typing its name and how many, and nothing else.
    function applyPrItemDetails(itemName) {
        var key = (itemName || "").toString().trim()
        if (key === "") return
        var details = poPartDetailsLookup[key]
        if (details === undefined || details === null) return
        prPartNoField.text = details.partNo || ""
        prUnitField.text = details.unit || ""
        prEstPriceField.text = formatAmount(details.unitPrice)
        if ((details.vendor || "").toString().trim() !== "")
            prVendorField.editText = details.vendor
    }

    function clearPrLineFields() {
        prItemNameField.currentIndex = -1
        prItemNameField.editText = ""
        prPartNoField.text = ""
        prQtyField.value = 1
        prUnitField.text = ""
        prEstPriceField.text = "0.00"
        prVendorField.currentIndex = -1
        prVendorField.editText = ""
    }

    function addPrItemToCart() {
        var itemName = (prItemNameField.editText || prItemNameField.currentText || "").toString().trim()
        if (itemName === "") {
            statusLabel.text = "Enter what you need first"; statusTimer.restart(); return
        }
        prCartModel.append({
            itemName: itemName,
            partNo: prPartNoField.text.trim(),
            qty: prQtyField.value,
            unit: prUnitField.text.trim(),
            estimatedPrice: parseAmount(prEstPriceField.text),
            vendor: (prVendorField.editText || prVendorField.currentText || "").toString().trim()
        })
        clearPrLineFields()
    }

    function clearPrForm() {
        editingPRNumber = ""
        prCartModel.clear()
        clearPrLineFields()
        prDepartmentField.text = ""
        prNeededByField.text = ""
        prPriorityCombo.currentIndex = 0
        prRemarksField.text = ""
        prRequestedByField.text = excelHandler.currentUser
    }

    // Pulls a pending request back into the form so the person who raised it
    // can correct it before anyone reviews it.
    function loadPrForEdit(prNo) {
        var pr = excelHandler.getPRByNumber(prNo)
        if (!pr || pr.prNo === undefined) return

        clearPrForm()
        editingPRNumber = prNo
        prDepartmentField.text = pr.department || ""
        prNeededByField.text = pr.neededBy || ""
        prPriorityCombo.currentIndex = (pr.priority === "Urgent") ? 1 : 0
        prRemarksField.text = pr.remarks || ""
        prRequestedByField.text = pr.requestedBy || ""

        var lines = excelHandler.getPRItems(prNo)
        for (var i = 0; i < lines.length; i++) {
            prCartModel.append({
                itemName: lines[i].itemName || "",
                partNo: lines[i].partNo || "",
                qty: lines[i].qty || 0,
                unit: lines[i].unit || "",
                estimatedPrice: lines[i].estimatedPrice || 0,
                vendor: lines[i].vendor || ""
            })
        }
    }

    function prCartItems() {
        var items = []
        for (var i = 0; i < prCartModel.count; i++) {
            var it = prCartModel.get(i)
            items.push({
                itemName: it.itemName, partNo: it.partNo, qty: it.qty,
                unit: it.unit, estimatedPrice: it.estimatedPrice, vendor: it.vendor
            })
        }
        return items
    }

    function prFormPayload() {
        return {
            department: prDepartmentField.text,
            neededBy: prNeededByField.text,
            priority: prPriorityCombo.currentText,
            remarks: prRemarksField.text,
            requestedBy: prRequestedByField.text
        }
    }

    function submitPurchaseRequest() {
        var items = prCartItems()
        if (editingPRNumber !== "") {
            if (!excelHandler.updatePurchaseRequest(editingPRNumber, prFormPayload(), items)) return
            statusLabel.text = editingPRNumber + " updated"
            statusTimer.restart()
            clearPrForm()
            refreshPRList()
            return
        }

        var created = excelHandler.createPurchaseRequest(prFormPayload(), items)
        if (created === "") return
        clearPrForm()
        refreshPRList()
    }

    function refreshPRList() {
        var filter = prFilterCombo.currentText === "All" ? "" : prFilterCombo.currentText
        prRowsCache = excelHandler.getPRList(filter)
        prSearchIndex = excelHandler.getPRSearchIndex()
        applyPrSearch()
    }

    // Each whitespace-separated word must appear somewhere in the request, so
    // extra words narrow the result down instead of widening it.
    function applyPrSearch() {
        var terms = prSearchField.text.toLowerCase().trim().split(/\s+/)
        prListModel.clear()
        for (var i = 0; i < prRowsCache.length; i++) {
            var haystack = prSearchIndex[prRowsCache[i].prNo] || ""
            var matches = true
            for (var t = 0; t < terms.length; t++) {
                if (terms[t] === "") continue
                if (haystack.indexOf(terms[t]) === -1) { matches = false; break }
            }
            if (matches) prListModel.append(prRowsCache[i])
        }
    }

    // Hands an approved request over to the purchase order form: its lines
    // become the order's cart, and the two are linked once the order is made.
    function raisePOForRequest(prNo) {
        var lines = excelHandler.getPRItems(prNo)
        if (lines.length === 0) {
            statusLabel.text = prNo + " has no items"; statusTimer.restart(); return
        }

        poCartModel.clear()
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i]
            poCartModel.append({
                partName: l.itemName || "",
                partNo: l.partNo || "",
                vendor: l.vendor || "",
                department: excelHandler.getPRByNumber(prNo).department || "",
                qty: l.qty || 0,
                unitPrice: l.estimatedPrice || 0,
                lineTotal: (l.qty || 0) * (l.estimatedPrice || 0)
            })
        }
        recalcPoCartTotal()

        var pr = excelHandler.getPRByNumber(prNo)
        poExpectedField.text = pr.neededBy || ""
        poExpectedEndField.text = ""
        poFromRequest = prNo

        prDialog.close()
        poDialog.open()
        statusLabel.text = "Raising a purchase order for " + prNo +
                           " - check the vendor and rate on each line"
        statusTimer.restart()
    }

    Dialog {
        id: prDialog
        title: "Purchase Requests"
        modal: true
        anchors.centerIn: parent
        width: parent ? Math.min(1180, parent.width - 60) : 1180
        height: parent ? Math.min(880, parent.height - 40) : 880

        ColumnLayout {
            anchors.fill: parent; spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Purchase Requests"; font.bold: true; font.pixelSize: 16; color: "#2c3e50" }
                Item { Layout.fillWidth: true }
                Label {
                    text: loginDialog.isAuthenticated
                          ? "Everyone can see this queue. Supply chain approves a request, then raises the order."
                          : "Log in to raise or review a request."
                    font.pixelSize: 10; color: "#95a5a6"
                }
            }

            // ---- Who needs it, and by when ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: prEntryGrid.implicitHeight + 2 * prEntryGrid.anchors.margins
                color: "#fdf5ea"; border.color: "#e67e22"; radius: 5

                GridLayout {
                    id: prEntryGrid
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 14
                    columns: 4; rowSpacing: 10; columnSpacing: 14

                    Label {
                        text: editingPRNumber === "" ? "Next Request:" : "Editing:"
                        font.bold: true
                        Layout.minimumWidth: 104; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Label {
                            text: editingPRNumber === "" ? excelHandler.getNextPRNumber() : editingPRNumber
                            color: "#e67e22"; font.bold: true
                        }
                        Button {
                            text: "Cancel edit"
                            visible: editingPRNumber !== ""
                            flat: true
                            onClicked: clearPrForm()
                            contentItem: Text { text: "Cancel edit"; color: "#e74c3c"; font.pixelSize: 11 }
                        }
                        Item { Layout.fillWidth: true }
                    }
                    Label {
                        text: "Needed by:"
                        Layout.minimumWidth: 104; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        TextField {
                            id: prNeededByField
                            Layout.preferredWidth: 130
                            placeholderText: "YYYY-MM-DD"
                            readOnly: true
                            selectByMouse: true
                        }
                        Button {
                            text: "\u{1F4C5}"
                            Layout.preferredWidth: 38
                            ToolTip.visible: hovered
                            ToolTip.text: "Pick the date it is needed by"
                            onClicked: openDatePicker(prNeededByField, "needed-by date")
                        }
                        Button {
                            text: "✕"
                            Layout.preferredWidth: 32
                            enabled: prNeededByField.text !== ""
                            ToolTip.visible: hovered
                            ToolTip.text: "Clear the date"
                            onClicked: prNeededByField.text = ""
                        }
                        Label { text: "Priority:"; Layout.leftMargin: 8 }
                        ComboBox {
                            id: prPriorityCombo
                            Layout.preferredWidth: 110
                            model: ["Normal", "Urgent"]
                        }
                    }

                    Label {
                        text: "Requested by:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField {
                        id: prRequestedByField
                        Layout.fillWidth: true
                        text: excelHandler.currentUser
                        placeholderText: "Who is asking"
                        selectByMouse: true
                    }
                    Label {
                        text: "Department:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField {
                        id: prDepartmentField
                        Layout.fillWidth: true
                        placeholderText: "Which department needs it"
                        selectByMouse: true
                    }

                    Label {
                        text: "Reason / Remarks:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField {
                        id: prRemarksField
                        Layout.columnSpan: 3
                        Layout.fillWidth: true
                        placeholderText: "What it is for - the reviewer reads this before approving"
                        selectByMouse: true
                    }
                }
            }

            // ---- What is being asked for ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: prLineGrid.implicitHeight + 2 * prLineGrid.anchors.margins
                color: "#fffaf4"; border.color: "#e67e22"; radius: 5

                GridLayout {
                    id: prLineGrid
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 12
                    columns: 4; rowSpacing: 10; columnSpacing: 14

                    Label {
                        text: "Item Name*:"
                        Layout.minimumWidth: 104; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        ComboBox {
                            id: prItemNameField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 180
                            editable: true
                            model: []
                            onCurrentTextChanged: applyPrItemDetails(currentText)
                        }
                        Button {
                            text: "\u{1F50D}"
                            Layout.preferredWidth: 40
                            ToolTip.visible: hovered
                            ToolTip.text: "Search the Item Master"
                            onClicked: openPrPartPicker()
                        }
                    }
                    Label {
                        text: "Part No:"
                        Layout.minimumWidth: 104; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField { id: prPartNoField; Layout.fillWidth: true; placeholderText: "If it is a catalogued part"; selectByMouse: true }

                    Label {
                        text: "Quantity* / Unit:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        SpinBox { id: prQtyField; from: 1; to: 100000; value: 1; editable: true; Layout.preferredWidth: 130 }
                        TextField {
                            id: prUnitField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 80
                            placeholderText: "Nos, Kg, Mtr..."
                            selectByMouse: true
                        }
                    }
                    Label {
                        text: "Preferred Vendor:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        ComboBox {
                            id: prVendorField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 160
                            editable: true
                            model: excelHandler.getVendorNames()
                        }
                        Button {
                            text: "\u{1F50D}"
                            Layout.preferredWidth: 40
                            ToolTip.visible: hovered
                            ToolTip.text: "Search vendors"
                            onClicked: openVendorPicker(prVendorField)
                        }
                    }

                    Label {
                        text: "Est. Unit Price:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Label { text: "₹"; font.bold: true; color: "#2c3e50" }
                        TextField {
                            id: prEstPriceField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 140
                            placeholderText: "0.00"
                            text: "0.00"
                            horizontalAlignment: TextInput.AlignRight
                            validator: DoubleValidator { bottom: 0; decimals: 2 }
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            selectByMouse: true
                        }
                    }
                    Item {}
                    Button {
                        text: "+ Add Item"
                        highlighted: true
                        Layout.minimumWidth: 120
                        Layout.alignment: Qt.AlignRight
                        onClicked: addPrItemToCart()
                    }
                }
            }

            // Cart: the lines this request is asking for.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: prCartModel.count === 0
                                        ? 58
                                        : Math.min(170, 44 + prCartModel.count * 38)
                border.color: "#e67e22"; radius: 5; color: "#ffffff"

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6; Layout.rightMargin: 6
                        spacing: 10
                        visible: prCartModel.count > 0
                        Label { text: "Item"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.fillWidth: true }
                        Label { text: "Preferred Vendor"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 170 }
                        Label { text: "Qty"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                        Label { text: "Unit"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 70 }
                        Label { text: "Est. Amount"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
                        Item { Layout.preferredWidth: 30 }
                    }

                    ListView {
                        id: prCartView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 5
                        model: prCartModel
                        delegate: Rectangle {
                            width: prCartView.width; height: 32
                            color: "#fff"; border.color: "#e0e0e0"; radius: 3
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 3; anchors.bottomMargin: 3
                                spacing: 10
                                Label {
                                    text: (index + 1) + ". " + model.itemName
                                    font.bold: true; font.pixelSize: 11
                                    Layout.fillWidth: true; Layout.minimumWidth: 120
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: model.vendor !== "" ? model.vendor : "-"
                                    font.pixelSize: 11; color: "#7f8c8d"
                                    Layout.preferredWidth: 170; elide: Text.ElideRight
                                }
                                Label { text: model.qty; font.pixelSize: 11; color: "#2c3e50"; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                                Label { text: model.unit; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 70; elide: Text.ElideRight }
                                Label {
                                    text: formatRupees(model.qty * model.estimatedPrice)
                                    font.pixelSize: 12; font.bold: true; color: "#e67e22"
                                    Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight
                                }
                                Button {
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 24
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Remove this line"
                                    onClicked: prCartModel.remove(index)
                                    contentItem: Text { text: "X"; color: "#e74c3c"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "Nothing requested yet - use \"+ Add Item\" above"
                    visible: prCartModel.count === 0; color: "#95a5a6"; font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 280
                    Layout.preferredHeight: 38
                    color: "#fdf0e2"; border.color: "#e67e22"; radius: 4
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        Label { text: "Estimated"; font.bold: true; color: "#2c3e50"; font.pixelSize: 12 }
                        Label {
                            text: formatRupees(prCartValue())
                            font.bold: true; font.pixelSize: 15; color: "#e67e22"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Button {
                    text: editingPRNumber === ""
                          ? "Send Request (" + prCartModel.count + (prCartModel.count === 1 ? " item)" : " items)")
                          : "Update " + editingPRNumber
                    highlighted: true
                    enabled: prCartModel.count > 0 && loginDialog.isAuthenticated
                    ToolTip.visible: hovered && !loginDialog.isAuthenticated
                    ToolTip.text: "Log in so the request carries your name"
                    onClicked: submitPurchaseRequest()
                }
            }

            // ---- Status filter + free-text search across the queue ----
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 2; spacing: 10

                Label { text: "Filter:"; font.bold: true }
                ComboBox {
                    id: prFilterCombo
                    Layout.preferredWidth: 160
                    model: ["All", "Pending", "Approved", "Rejected", "Ordered"]
                    onCurrentTextChanged: refreshPRList()
                }

                Label { text: "Search:"; font.bold: true; Layout.leftMargin: 6 }
                TextField {
                    id: prSearchField
                    Layout.fillWidth: true
                    Layout.minimumWidth: 240
                    placeholderText: "Request number, requester, department, item, or date"
                    selectByMouse: true
                    onTextChanged: applyPrSearch()
                    Keys.onEscapePressed: function(event) {
                        if (text !== "") text = ""
                        else event.accepted = false
                    }
                }
                Button {
                    text: "✕"
                    Layout.preferredWidth: 34
                    enabled: prSearchField.text !== ""
                    ToolTip.visible: hovered
                    ToolTip.text: "Clear the search"
                    onClicked: prSearchField.text = ""
                }
                Label {
                    text: prSearchField.text.trim() === ""
                          ? prListModel.count + (prListModel.count === 1 ? " request" : " requests")
                          : prListModel.count + " of " + prRowsCache.length + " match"
                    color: "#7f8c8d"; font.pixelSize: 11
                }
                Label {
                    text: "Pending: " + excelHandler.pendingRequestCount
                    font.bold: true; color: "#e67e22"
                }
            }

            // ---- The queue ----
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumHeight: 90
                border.color: "#dee2e6"; radius: 5

                ListView {
                    id: prListView; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: prListModel
                    delegate: Rectangle {
                        width: prListView.width - 10; height: 74
                        color: {
                            if (model.status === "Approved") return "#eaf6ff"
                            if (model.status === "Ordered") return "#e8f8e8"
                            if (model.status === "Rejected") return "#f7eaea"
                            return "#fff8e8"
                        }
                        border.color: "#e0e0e0"; radius: 4

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true; Layout.minimumWidth: 200; spacing: 3
                                RowLayout {
                                    spacing: 8
                                    Label { text: model.prNo; font.bold: true; font.pixelSize: 13; color: "#2c3e50" }
                                    Label {
                                        text: model.status
                                        font.pixelSize: 11; font.bold: true
                                        color: {
                                            if (model.status === "Approved") return "#2a78d6"
                                            if (model.status === "Ordered") return "#27ae60"
                                            if (model.status === "Rejected") return "#e74c3c"
                                            return "#f39c12"
                                        }
                                    }
                                    Label {
                                        text: "URGENT"
                                        visible: model.priority === "Urgent"
                                        font.pixelSize: 10; font.bold: true; color: "#e74c3c"
                                    }
                                    Label {
                                        text: "→ " + model.poNo
                                        visible: (model.poNo || "") !== ""
                                        font.pixelSize: 11; color: "#27ae60"; font.bold: true
                                    }
                                }
                                Label {
                                    text: model.summary + "  |  Qty: " + model.totalQty +
                                          "  |  Est: " + formatRupees(model.estimatedValue)
                                    font.pixelSize: 11; color: "#7f8c8d"
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Label {
                                    text: "By: " + (model.requestedBy || "-") +
                                          (model.department !== "" ? "  |  " + model.department : "") +
                                          "  |  Raised: " + model.date +
                                          (model.neededBy !== "" ? "  |  Needed by: " + model.neededBy : "") +
                                          ((model.reviewedBy || "") !== "" ? "  |  Reviewed by: " + model.reviewedBy : "")
                                    font.pixelSize: 10; color: "#95a5a6"
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            Button {
                                text: "View"
                                onClicked: {
                                    selectedPRDetails = excelHandler.getPRByNumber(model.prNo)
                                    selectedPRItems = excelHandler.getPRItems(model.prNo)
                                    prDetailsDialog.open()
                                }
                                contentItem: Text { text: "View"; color: "#2c3e50"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Approve"
                                visible: model.status === "Pending"
                                enabled: loginDialog.isAuthenticated
                                onClicked: {
                                    prPendingReview = model.prNo
                                    prReviewAction = "Approved"
                                    prReviewNoteField.text = ""
                                    prReviewDialog.open()
                                }
                                contentItem: Text { text: "Approve"; color: parent.enabled ? "#27ae60" : "#95a5a6"; font.pixelSize: 11; font.bold: true }
                            }
                            Button {
                                text: "Reject"
                                visible: model.status === "Pending"
                                enabled: loginDialog.isAuthenticated
                                onClicked: {
                                    prPendingReview = model.prNo
                                    prReviewAction = "Rejected"
                                    prReviewNoteField.text = ""
                                    prReviewDialog.open()
                                }
                                contentItem: Text { text: "Reject"; color: parent.enabled ? "#e74c3c" : "#95a5a6"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Create PO"
                                visible: model.status === "Approved"
                                enabled: loginDialog.isAuthenticated
                                ToolTip.visible: hovered
                                ToolTip.text: "Open the purchase order form with these items"
                                onClicked: raisePOForRequest(model.prNo)
                                contentItem: Text { text: "Create PO"; color: parent.enabled ? "#3498db" : "#95a5a6"; font.pixelSize: 11; font.bold: true }
                            }
                            Button {
                                text: "Edit"
                                visible: model.status === "Pending"
                                enabled: loginDialog.isAuthenticated
                                onClicked: loadPrForEdit(model.prNo)
                                contentItem: Text { text: "Edit"; color: parent.enabled ? "#8e44ad" : "#95a5a6"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Delete"
                                visible: (model.poNo || "") === ""
                                enabled: loginDialog.isAuthenticated
                                onClicked: { prPendingDelete = model.prNo; prDeleteConfirmDialog.open() }
                                contentItem: Text { text: "Delete"; color: parent.enabled ? "#e74c3c" : "#95a5a6"; font.pixelSize: 11 }
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: prSearchField.text.trim() === ""
                          ? "No purchase requests yet"
                          : "No requests match \"" + prSearchField.text.trim() + "\""
                    visible: prListModel.count === 0; color: "#95a5a6"
                }
            }

            Button { text: "Close"; Layout.alignment: Qt.AlignRight; onClicked: prDialog.close() }
        }

        onOpened: {
            prSearchField.text = ""
            if (editingPRNumber === "" && prCartModel.count === 0)
                clearPrForm()
            refreshPartNameDropdown()
            refreshVendorDropdowns()
            refreshPRList()
        }
    }

    Dialog {
        id: prReviewDialog
        title: prReviewAction === "Approved" ? "Approve " + prPendingReview
                                             : "Reject " + prPendingReview
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 480

        ColumnLayout {
            anchors.fill: parent; spacing: 10
            Label {
                text: prReviewAction === "Approved"
                      ? "Approving lets supply chain raise a purchase order for this request."
                      : "Rejecting closes the request. Say why, so the requester knows."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Label { text: "Note (optional):" }
            TextField {
                id: prReviewNoteField
                Layout.fillWidth: true
                placeholderText: prReviewAction === "Approved" ? "e.g. buy from the usual vendor"
                                                               : "e.g. already in stock"
                selectByMouse: true
            }
        }

        onAccepted: {
            if (excelHandler.setPurchaseRequestStatus(prPendingReview, prReviewAction,
                                                      excelHandler.currentUser,
                                                      prReviewNoteField.text)) {
                statusLabel.text = prPendingReview + " " + prReviewAction.toLowerCase()
                statusTimer.restart()
                refreshPRList()
            }
            prPendingReview = ""
        }
    }

    Dialog {
        id: prDeleteConfirmDialog
        title: "Delete Purchase Request"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Yes | Dialog.No
        width: 460

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Delete " + prPendingDelete + " and its items? The request number will not be reused."
        }

        onAccepted: {
            if (excelHandler.deletePurchaseRequest(prPendingDelete)) {
                if (editingPRNumber === prPendingDelete) clearPrForm()
                statusLabel.text = "Deleted " + prPendingDelete
                statusTimer.restart()
                refreshPRList()
            }
            prPendingDelete = ""
        }
    }

    /* ---- Item Master picker for a request line ---- */

    ListModel { id: prPartPickerModel }

    function refreshPrPartPicker(filter) {
        prPartPickerModel.clear()
        var f = (filter || "").toString().trim().toLowerCase()
        var items = excelHandler.getItemMasterList()
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            var partName = (it.partName || "").toString()
            if (partName.trim() === "") continue
            var partNo = (it.partNo || "").toString()
            var dept = (it.department || it.category || "").toString()
            var vendor = (it.vendor || "").toString()
            if (f !== "" &&
                (partName + " " + partNo + " " + dept + " " + vendor).toLowerCase().indexOf(f) === -1)
                continue
            prPartPickerModel.append({
                partName: partName, partNo: partNo, department: dept, vendor: vendor,
                unit: (it.unit || "").toString(), unitPrice: it.unitPrice || 0
            })
        }
    }

    function openPrPartPicker() {
        prPartSearchField.text = ""
        refreshPrPartPicker("")
        prPartPickerDialog.open()
        prPartSearchField.forceActiveFocus()
    }

    function choosePrPart(item) {
        var idx = prItemNameField.find(item.partName)
        if (idx >= 0) prItemNameField.currentIndex = idx
        else prItemNameField.editText = item.partName
        prPartNoField.text = item.partNo
        prUnitField.text = item.unit
        prEstPriceField.text = formatAmount(item.unitPrice)
        if (item.vendor !== "") prVendorField.editText = item.vendor
        prPartPickerDialog.close()
    }

    Dialog {
        id: prPartPickerDialog
        title: "Search Item Master"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel
        width: Math.min(root.width - 120, 720)
        height: Math.min(root.height - 140, 520)

        ColumnLayout {
            anchors.fill: parent; spacing: 8

            TextField {
                id: prPartSearchField
                Layout.fillWidth: true
                placeholderText: "Item name, part number, department or vendor"
                selectByMouse: true
                onTextChanged: refreshPrPartPicker(text)
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 4

                ListView {
                    id: prPartPickerView
                    anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: prPartPickerModel
                    delegate: Rectangle {
                        width: prPartPickerView.width - 10; height: 46
                        color: "#fff"; border.color: "#e0e0e0"; radius: 3
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: choosePrPart({
                                partName: model.partName, partNo: model.partNo,
                                unit: model.unit, unitPrice: model.unitPrice,
                                vendor: model.vendor
                            })
                        }
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 6; spacing: 2
                            Label { text: model.partName; font.bold: true; font.pixelSize: 12; color: "#2c3e50" }
                            Label {
                                text: (model.partNo !== "" ? "Part No: " + model.partNo : "No part number") +
                                      (model.department !== "" ? "  |  " + model.department : "") +
                                      (model.vendor !== "" ? "  |  " + model.vendor : "") +
                                      "  |  " + formatRupees(model.unitPrice)
                                font.pixelSize: 10; color: "#7f8c8d"
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "No matching items"
                    visible: prPartPickerModel.count === 0; color: "#95a5a6"
                }
            }
        }
    }

    /* ---- Request details ---- */

    Dialog {
        id: prDetailsDialog
        title: "Purchase Request " + (selectedPRDetails.prNo || "")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Close
        width: Math.min(root.width - 120, 720)

        ColumnLayout {
            anchors.fill: parent; spacing: 8

            GridLayout {
                Layout.fillWidth: true
                columns: 4; rowSpacing: 4; columnSpacing: 10

                Label { text: "Request No:"; font.bold: true }
                Label { text: selectedPRDetails.prNo || "-"; Layout.fillWidth: true }
                Label { text: "Status:"; font.bold: true }
                Label { text: selectedPRDetails.status || "-"; Layout.fillWidth: true }

                Label { text: "Requested by:"; font.bold: true }
                Label { text: selectedPRDetails.requestedBy || "-"; Layout.fillWidth: true }
                Label { text: "Department:"; font.bold: true }
                Label { text: selectedPRDetails.department || "-"; Layout.fillWidth: true }

                Label { text: "Raised:"; font.bold: true }
                Label { text: selectedPRDetails.date || "-"; Layout.fillWidth: true }
                Label { text: "Needed by:"; font.bold: true }
                Label { text: selectedPRDetails.neededBy || "-"; Layout.fillWidth: true }

                Label { text: "Priority:"; font.bold: true }
                Label { text: selectedPRDetails.priority || "Normal"; Layout.fillWidth: true }
                Label { text: "Ordered as:"; font.bold: true }
                Label { text: selectedPRDetails.poNo || "-"; Layout.fillWidth: true }

                Label { text: "Reason:"; font.bold: true; Layout.alignment: Qt.AlignTop }
                Label { text: selectedPRDetails.remarks || "-"; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                Label { text: "Reviewed by:"; font.bold: true; Layout.alignment: Qt.AlignTop }
                Label {
                    text: (selectedPRDetails.reviewedBy || "-") +
                          ((selectedPRDetails.reviewNote || "") !== ""
                           ? "\n“" + selectedPRDetails.reviewNote + "”" : "")
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#e0e0e0" }

            Label {
                text: "Items requested (" + selectedPRItems.length + ")"
                font.bold: true; color: "#2c3e50"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(220, 8 + selectedPRItems.length * 26)
                border.color: "#dee2e6"; radius: 4

                ListView {
                    id: prDetailItemsView
                    anchors.fill: parent; anchors.margins: 4; clip: true
                    model: selectedPRItems
                    delegate: RowLayout {
                        width: prDetailItemsView.width - 8
                        height: 26
                        spacing: 10
                        Label { text: (index + 1) + ". " + modelData.itemName; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label { text: modelData.vendor; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 150; elide: Text.ElideRight }
                        Label { text: modelData.qty + " " + modelData.unit; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                        Label { text: formatRupees(modelData.qty * modelData.estimatedPrice); font.pixelSize: 11; color: "#e67e22"; Layout.preferredWidth: 140; horizontalAlignment: Text.AlignRight }
                    }
                }
            }
        }
    }

    /* ================= STOCK ROW EDITOR ================= */

    // The grid itself is read-only, so a correction goes through here: one
    // deliberate action, login-gated, with every column of the row in view.
    property int editingStockRow: -1

    function openStockRowEditor(row) {
        if (row <= 0 || !loginDialog.isAuthenticated) return
        editingStockRow = row
        stockEditPartName.text = (excelHandler.model.getData(row, 0) || "").toString()
        stockEditPartNo.text = (excelHandler.model.getData(row, 1) || "").toString()
        stockEditStock.text = (excelHandler.model.getData(row, 2) || "").toString()
        stockEditDepartment.text = (excelHandler.model.getData(row, 3) || "").toString()
        stockEditPrepared.text = (excelHandler.model.getData(row, 4) || "").toString()
        stockEditApproved.text = (excelHandler.model.getData(row, 5) || "").toString()
        stockEditVendor.text = (excelHandler.model.getData(row, 6) || "").toString()
        stockEditDate.text = (excelHandler.model.getData(row, 7) || "").toString()
        stockEditUnitPrice.text = (excelHandler.model.getData(row, 8) || "").toString()
        stockRowEditDialog.open()
    }

    Dialog {
        id: stockRowEditDialog
        title: "Edit Stock Row " + editingStockRow
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Save | Dialog.Cancel
        width: 620

        onAccepted: {
            if (editingStockRow <= 0) return
            var m = excelHandler.model
            m.setDataAt(editingStockRow, 0, stockEditPartName.text)
            m.setDataAt(editingStockRow, 1, stockEditPartNo.text)
            m.setDataAt(editingStockRow, 2, stockEditStock.text)
            m.setDataAt(editingStockRow, 3, stockEditDepartment.text)
            m.setDataAt(editingStockRow, 4, stockEditPrepared.text)
            m.setDataAt(editingStockRow, 5, stockEditApproved.text)
            m.setDataAt(editingStockRow, 6, stockEditVendor.text)
            m.setDataAt(editingStockRow, 7, stockEditDate.text)
            m.setDataAt(editingStockRow, 8, stockEditUnitPrice.text)
            // An edit can move a part between departments or change a
            // quantity, so re-roll the totals.
            root.tableRefreshToken++
            refreshStockOverview()
            statusLabel.text = "Row " + editingStockRow + " updated"
            statusTimer.restart()
        }

        GridLayout {
            anchors.fill: parent
            columns: 4; rowSpacing: 8; columnSpacing: 10

            Label { text: "Part Name:" }
            TextField { id: stockEditPartName; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "Part No:" }
            TextField { id: stockEditPartNo; Layout.fillWidth: true; selectByMouse: true }

            Label { text: "Stock:" }
            TextField {
                id: stockEditStock; Layout.fillWidth: true
                horizontalAlignment: TextInput.AlignRight
                validator: DoubleValidator { bottom: 0; decimals: 2 }
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                selectByMouse: true
            }
            Label { text: "Department:" }
            TextField { id: stockEditDepartment; Layout.fillWidth: true; selectByMouse: true }

            Label { text: "Prepared:" }
            TextField { id: stockEditPrepared; Layout.fillWidth: true; selectByMouse: true }
            Label { text: "Approved:" }
            TextField { id: stockEditApproved; Layout.fillWidth: true; selectByMouse: true }

            Label { text: "Vendor Name:" }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                TextField { id: stockEditVendor; Layout.fillWidth: true; selectByMouse: true }
                Button {
                    text: "\u{1F50D}"
                    Layout.preferredWidth: 40
                    ToolTip.visible: hovered
                    ToolTip.text: "Search vendors"
                    onClicked: openVendorPicker(stockEditVendor)
                }
            }
            Label { text: "Date:" }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                TextField { id: stockEditDate; Layout.fillWidth: true; placeholderText: "YYYY-MM-DD"; selectByMouse: true }
                Button {
                    text: "\u{1F4C5}"
                    Layout.preferredWidth: 38
                    ToolTip.visible: hovered
                    ToolTip.text: "Pick the date"
                    onClicked: openDatePicker(stockEditDate, "row date")
                }
            }

            Label { text: "Unit Price:" }
            TextField {
                id: stockEditUnitPrice; Layout.fillWidth: true
                horizontalAlignment: TextInput.AlignRight
                validator: DoubleValidator { bottom: 0; decimals: 2 }
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                selectByMouse: true
            }
            Item { Layout.columnSpan: 2 }
        }
    }

    /* ================= DELIVERY CHALLAN (DC) ================= */

    // Items being collected for the challan being written (the "cart"), and the
    // list of challans already raised.
    ListModel { id: dcCartModel }
    ListModel { id: dcListModel }
    ListModel { id: dcPartyPickerModel }

    // Both are fetched once per refresh so typing in the search box neither
    // re-queries nor rebuilds any strings per keystroke.
    property var dcRowsCache: []
    property var dcSearchIndex: ({})

    // Empty while writing a new challan; the challan number while editing one.
    property string editingDCNumber: ""
    property var selectedDCDetails: ({})
    property var selectedDCItems: []

    property string dcPreviewDcNo: ""
    property var dcPreviewPages: []
    property string dcPreviewPdfPath: ""
    property string dcLastSavedPdf: ""

    // Quantities may be weighed or metered, so a fractional amount keeps its
    // decimals while a plain count does not grow ".00".
    function formatQty(value) {
        var n = parseAmount(value)
        return (Math.abs(n - Math.round(n)) < 0.005) ? Math.round(n).toString() : n.toFixed(2)
    }

    function dcCartQty() {
        var t = 0
        for (var i = 0; i < dcCartModel.count; i++) t += dcCartModel.get(i).qty
        return t
    }

    // Fills the blank line fields from the Item Master, exactly as the PO entry
    // does, so an item's part number, HSN code and unit are typed once ever.
    function applyDcItemDetails(itemName) {
        var key = (itemName || "").toString().trim()
        if (key === "") return
        var details = poPartDetailsLookup[key]
        if (details === undefined || details === null) return
        dcPartNoField.text = details.partNo || ""
        dcHsnField.text = details.hsnCode || ""
        dcUnitField.text = details.unit || ""
    }

    function clearDcLineFields() {
        dcItemNameField.currentIndex = -1
        dcItemNameField.editText = ""
        dcPartNoField.text = ""
        dcHsnField.text = ""
        dcQtyField.text = "1"
        dcUnitField.text = ""
    }

    function addDcItemToCart() {
        var itemName = (dcItemNameField.editText || dcItemNameField.currentText || "").toString().trim()
        if (itemName === "") {
            statusLabel.text = "Enter an item name first"; statusTimer.restart(); return
        }
        var qty = parseAmount(dcQtyField.text)
        if (qty <= 0) {
            statusLabel.text = "Quantity must be greater than 0 for " + itemName
            statusTimer.restart(); return
        }
        dcCartModel.append({
            itemName: itemName,
            partNo: dcPartNoField.text.trim(),
            hsnCode: dcHsnField.text.trim(),
            qty: qty,
            unit: dcUnitField.text.trim()
        })
        clearDcLineFields()
    }

    function clearDcForm() {
        editingDCNumber = ""
        dcCartModel.clear()
        clearDcLineFields()
        dcDateField.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
        dcDeliveryTimeField.text = ""
        dcPartyNameField.text = ""
        dcPartyAddressField.text = ""
        dcPartyPhoneField.text = ""
        dcPartyEmailField.text = ""
        dcPartyGstinField.text = ""
        dcSeparateShipping.checked = false
        dcShipNameField.text = ""
        dcShipAddressField.text = ""
        dcShipPhoneField.text = ""
        dcShipEmailField.text = ""
        dcShipGstinField.text = ""
        dcTermsField.text = ""
        dcDeliveredByField.text = excelHandler.currentUser
        dcReceivedByField.text = ""
    }

    // Pulls a draft challan back into the entry form so it can be corrected
    // without burning a challan number.
    function loadDcForEdit(dcNo) {
        var dc = excelHandler.getDCByNumber(dcNo)
        if (!dc || dc.dcNo === undefined) return

        clearDcForm()
        editingDCNumber = dcNo
        dcDateField.text = dc.date || ""
        dcDeliveryTimeField.text = dc.deliveryTime || ""
        dcPartyNameField.text = dc.partyName || ""
        dcPartyAddressField.text = dc.partyAddress || ""
        dcPartyPhoneField.text = dc.partyPhone || ""
        dcPartyEmailField.text = dc.partyEmail || ""
        dcPartyGstinField.text = dc.partyGstin || ""
        dcTermsField.text = dc.terms || ""
        dcDeliveredByField.text = dc.deliveredBy || ""
        dcReceivedByField.text = dc.receivedBy || ""

        // Only show the shipping block when the goods really go somewhere else;
        // a consignee equal to the party was filled in for us on creation.
        var differs = (dc.shipName || "") !== (dc.partyName || "") ||
                      (dc.shipAddress || "") !== (dc.partyAddress || "")
        dcSeparateShipping.checked = differs
        if (differs) {
            dcShipNameField.text = dc.shipName || ""
            dcShipAddressField.text = dc.shipAddress || ""
            dcShipPhoneField.text = dc.shipPhone || ""
            dcShipEmailField.text = dc.shipEmail || ""
            dcShipGstinField.text = dc.shipGstin || ""
        }

        var lines = excelHandler.getDCItems(dcNo)
        for (var i = 0; i < lines.length; i++) {
            dcCartModel.append({
                itemName: lines[i].itemName || "",
                partNo: lines[i].partNo || "",
                hsnCode: lines[i].hsnCode || "",
                qty: lines[i].qty || 0,
                unit: lines[i].unit || ""
            })
        }
    }

    function dcFormPayload() {
        return {
            date: dcDateField.text,
            deliveryTime: dcDeliveryTimeField.text,
            partyName: dcPartyNameField.text,
            partyAddress: dcPartyAddressField.text,
            partyPhone: dcPartyPhoneField.text,
            partyEmail: dcPartyEmailField.text,
            partyGstin: dcPartyGstinField.text,
            shipName: dcSeparateShipping.checked ? dcShipNameField.text : "",
            shipAddress: dcSeparateShipping.checked ? dcShipAddressField.text : "",
            shipPhone: dcSeparateShipping.checked ? dcShipPhoneField.text : "",
            shipEmail: dcSeparateShipping.checked ? dcShipEmailField.text : "",
            shipGstin: dcSeparateShipping.checked ? dcShipGstinField.text : "",
            terms: dcTermsField.text,
            deliveredBy: dcDeliveredByField.text,
            receivedBy: dcReceivedByField.text,
            preparedBy: excelHandler.currentUser
        }
    }

    function dcCartItems() {
        var items = []
        for (var i = 0; i < dcCartModel.count; i++) {
            var it = dcCartModel.get(i)
            items.push({
                itemName: it.itemName, partNo: it.partNo, hsnCode: it.hsnCode,
                qty: it.qty, unit: it.unit
            })
        }
        return items
    }

    function submitDeliveryChallan() {
        var items = dcCartItems()
        if (editingDCNumber !== "") {
            var dcNo = editingDCNumber
            if (!excelHandler.updateDeliveryChallan(dcNo, dcFormPayload(), items)) return
            clearDcForm()
            refreshDCList()
            openDcPdfPreview(dcNo)
            return
        }

        var created = excelHandler.createDeliveryChallan(dcFormPayload(), items)
        if (created === "") return
        clearDcForm()
        refreshDCList()
        openDcPdfPreview(created)
    }

    function refreshDCList() {
        var filter = dcFilterCombo.currentText === "All" ? "" : dcFilterCombo.currentText
        dcRowsCache = excelHandler.getDCList(filter)
        dcSearchIndex = excelHandler.getDCSearchIndex()
        applyDcSearch()
    }

    // Each whitespace-separated word must appear somewhere in the challan, so
    // extra words narrow the result down instead of widening it.
    function applyDcSearch() {
        var terms = dcSearchField.text.toLowerCase().trim().split(/\s+/)
        dcListModel.clear()
        for (var i = 0; i < dcRowsCache.length; i++) {
            var haystack = dcSearchIndex[dcRowsCache[i].dcNo] || ""
            var matches = true
            for (var t = 0; t < terms.length; t++) {
                if (terms[t] === "") continue
                if (haystack.indexOf(terms[t]) === -1) { matches = false; break }
            }
            if (matches) dcListModel.append(dcRowsCache[i])
        }
    }

    // ---- Party picker: everyone this company has delivered to, plus the
    // vendors, since goods going back to a supplier travel on a challan too.
    function refreshDcPartyPicker(filter) {
        dcPartyPickerModel.clear()
        var f = (filter || "").toString().trim().toLowerCase()
        var seen = ({})

        var parties = excelHandler.getDCPartyList()
        for (var i = 0; i < parties.length; i++) {
            var p = parties[i]
            var name = (p.partyName || "").toString()
            if (name.trim() === "") continue
            seen[name.toLowerCase()] = true
            if (f !== "" && (name + " " + (p.partyAddress || "") + " " + (p.partyGstin || "") +
                             " " + (p.partyPhone || "")).toLowerCase().indexOf(f) === -1) continue
            dcPartyPickerModel.append({
                name: name, address: (p.partyAddress || "").toString(),
                phone: (p.partyPhone || "").toString(), email: (p.partyEmail || "").toString(),
                gstin: (p.partyGstin || "").toString(), source: "Delivered before"
            })
        }

        var vendors = excelHandler.getVendorList()
        for (var v = 0; v < vendors.length; v++) {
            var vn = (vendors[v].vendorName || "").toString()
            if (vn.trim() === "" || seen[vn.toLowerCase()]) continue
            var addr = (vendors[v].vendorAddress || "").toString()
            var gstin = (vendors[v].gstin || "").toString()
            var phone = (vendors[v].phone || "").toString()
            if (f !== "" && (vn + " " + addr + " " + gstin + " " + phone).toLowerCase().indexOf(f) === -1)
                continue
            dcPartyPickerModel.append({
                name: vn, address: addr, phone: phone,
                email: (vendors[v].email || "").toString(), gstin: gstin, source: "Vendor"
            })
        }
    }

    function openDcPartyPicker() {
        dcPartySearchField.text = ""
        refreshDcPartyPicker("")
        dcPartyPickerDialog.open()
        dcPartySearchField.forceActiveFocus()
    }

    function chooseDcParty(party) {
        dcPartyNameField.text = party.name
        dcPartyAddressField.text = party.address
        dcPartyPhoneField.text = party.phone
        dcPartyEmailField.text = party.email
        dcPartyGstinField.text = party.gstin
        dcPartyPickerDialog.close()
    }

    // ---- Printable delivery challan ----

    function openDcPdfPreview(dcNo) {
        dcPreviewDcNo = dcNo
        refreshDcPdfPreview()
        if (dcPreviewPages.length > 0)
            dcPdfPreviewDialog.open()
    }

    function refreshDcPdfPreview() {
        var result = excelHandler.generateDCPreview(dcPreviewDcNo)
        if (!result || !result.pages || result.pages.length === 0) {
            dcPreviewPages = []
            dcPreviewPdfPath = ""
            statusLabel.text = "Could not render the delivery challan PDF"
            statusTimer.restart()
            return
        }
        dcPreviewPages = result.pages
        dcPreviewPdfPath = result.pdfPath
    }

    function sendDcPdf() {
        var saved = excelHandler.saveDCPdf(dcPreviewDcNo, "")
        if (saved === "") return
        dcLastSavedPdf = saved
        statusLabel.text = "Delivery challan saved to " + saved
        statusTimer.restart()
        dcPdfPreviewDialog.close()
        dcSavedDialog.open()
    }

    Dialog {
        id: dcDialog
        title: "Delivery Challan"
        modal: true
        anchors.centerIn: parent
        width: parent ? Math.min(1180, parent.width - 60) : 1180
        height: parent ? Math.min(880, parent.height - 40) : 880

        ColumnLayout {
            anchors.fill: parent; spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Delivery Challans"; font.bold: true; font.pixelSize: 16; color: "#2c3e50" }
                Item { Layout.fillWidth: true }
                Label {
                    text: "A challan records what left the premises. It does not change stock levels — use Issue Stock for that."
                    font.pixelSize: 10; color: "#95a5a6"
                }
            }

            // ---- Who it goes to, and when ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: dcEntryGrid.implicitHeight + 2 * dcEntryGrid.anchors.margins
                color: "#eef8fd"; border.color: "#1b9dd9"; radius: 5

                GridLayout {
                    id: dcEntryGrid
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 14
                    columns: 4; rowSpacing: 10; columnSpacing: 14

                    Label {
                        text: editingDCNumber === "" ? "Next Challan:" : "Editing:"
                        font.bold: true
                        Layout.minimumWidth: 104; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Label {
                            text: editingDCNumber === "" ? excelHandler.getNextDCNumber() : editingDCNumber
                            color: "#1b9dd9"; font.bold: true
                        }
                        Button {
                            text: "Cancel edit"
                            visible: editingDCNumber !== ""
                            flat: true
                            onClicked: clearDcForm()
                            contentItem: Text { text: "Cancel edit"; color: "#e74c3c"; font.pixelSize: 11 }
                        }
                        Item { Layout.fillWidth: true }
                    }
                    Label {
                        text: "Date:"
                        Layout.minimumWidth: 104; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        TextField {
                            id: dcDateField
                            Layout.preferredWidth: 130
                            placeholderText: "YYYY-MM-DD"
                            readOnly: true
                            text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                            selectByMouse: true
                        }
                        Button {
                            text: "\u{1F4C5}"
                            Layout.preferredWidth: 38
                            ToolTip.visible: hovered
                            ToolTip.text: "Pick the challan date"
                            onClicked: openDatePicker(dcDateField, "challan date")
                        }
                        Label { text: "Delivery Time:"; Layout.leftMargin: 8 }
                        TextField {
                            id: dcDeliveryTimeField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 110
                            placeholderText: "e.g. 04:30 PM"
                            selectByMouse: true
                        }
                    }

                    Label {
                        text: "Party Name*:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        TextField {
                            id: dcPartyNameField
                            Layout.fillWidth: true
                            placeholderText: "Who the goods are being delivered to"
                            selectByMouse: true
                        }
                        Button {
                            text: "\u{1F50D}"
                            Layout.preferredWidth: 40
                            ToolTip.visible: hovered
                            ToolTip.text: "Search parties delivered to before, and vendors"
                            onClicked: openDcPartyPicker()
                        }
                    }
                    Label {
                        text: "GSTIN:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField { id: dcPartyGstinField; Layout.fillWidth: true; placeholderText: "Party GSTIN"; selectByMouse: true }

                    Label {
                        text: "Address:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    }
                    TextArea {
                        id: dcPartyAddressField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        placeholderText: "Street, city - PIN (one line per printed line)"
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        background: Rectangle { color: "#ffffff"; border.color: "#bdc3c7"; radius: 3 }
                    }
                    Label {
                        text: "Phone / Email:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 6
                        TextField { id: dcPartyPhoneField; Layout.fillWidth: true; placeholderText: "Phone number"; selectByMouse: true }
                        TextField { id: dcPartyEmailField; Layout.fillWidth: true; placeholderText: "Email ID"; selectByMouse: true }
                    }

                    CheckBox {
                        id: dcSeparateShipping
                        text: "Shipping to a different address"
                        Layout.columnSpan: 4
                        ToolTip.visible: hovered
                        ToolTip.text: "Leave off to ship to the party's own address"
                    }

                    Label {
                        text: "Shipping Name:"; visible: dcSeparateShipping.checked
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField {
                        id: dcShipNameField; visible: dcSeparateShipping.checked
                        Layout.fillWidth: true; placeholderText: "Consignee name"; selectByMouse: true
                    }
                    Label {
                        text: "Shipping GSTIN:"; visible: dcSeparateShipping.checked
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField {
                        id: dcShipGstinField; visible: dcSeparateShipping.checked
                        Layout.fillWidth: true; placeholderText: "Consignee GSTIN"; selectByMouse: true
                    }

                    Label {
                        text: "Shipping Address:"; visible: dcSeparateShipping.checked
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    }
                    TextArea {
                        id: dcShipAddressField; visible: dcSeparateShipping.checked
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        placeholderText: "Where the goods are actually going"
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        background: Rectangle { color: "#ffffff"; border.color: "#bdc3c7"; radius: 3 }
                    }
                    Label {
                        text: "Phone / Email:"; visible: dcSeparateShipping.checked
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    ColumnLayout {
                        visible: dcSeparateShipping.checked
                        Layout.fillWidth: true; spacing: 6
                        TextField { id: dcShipPhoneField; Layout.fillWidth: true; placeholderText: "Phone number"; selectByMouse: true }
                        TextField { id: dcShipEmailField; Layout.fillWidth: true; placeholderText: "Email ID"; selectByMouse: true }
                    }
                }
            }

            // ---- What is being delivered ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: dcLineGrid.implicitHeight + 2 * dcLineGrid.anchors.margins
                color: "#f7fbfd"; border.color: "#1b9dd9"; radius: 5

                GridLayout {
                    id: dcLineGrid
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 12
                    columns: 4; rowSpacing: 10; columnSpacing: 14

                    Label {
                        text: "Item Name*:"
                        Layout.minimumWidth: 104; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        ComboBox {
                            id: dcItemNameField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 180
                            editable: true
                            model: []
                            onCurrentTextChanged: applyDcItemDetails(currentText)
                        }
                        Button {
                            text: "\u{1F50D}"
                            Layout.preferredWidth: 40
                            ToolTip.visible: hovered
                            ToolTip.text: "Search the Item Master"
                            onClicked: openDcPartPicker()
                        }
                    }
                    Label {
                        text: "Part No:"
                        Layout.minimumWidth: 104; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField { id: dcPartNoField; Layout.fillWidth: true; placeholderText: "Printed under the item name"; selectByMouse: true }

                    Label {
                        text: "HSN/SAC Code:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    TextField {
                        id: dcHsnField; Layout.fillWidth: true
                        placeholderText: "Auto-filled from the Item Master"
                        selectByMouse: true
                    }
                    Label {
                        text: "Quantity* / Unit:"; horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        TextField {
                            id: dcQtyField
                            Layout.preferredWidth: 110
                            text: "1"
                            horizontalAlignment: TextInput.AlignRight
                            validator: DoubleValidator { bottom: 0; decimals: 2 }
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            selectByMouse: true
                            Keys.onReturnPressed: addDcItemToCart()
                        }
                        TextField {
                            id: dcUnitField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 90
                            placeholderText: "Nos, Kg, Mtr..."
                            selectByMouse: true
                            Keys.onReturnPressed: addDcItemToCart()
                        }
                        Button {
                            text: "+ Add Item"
                            highlighted: true
                            Layout.minimumWidth: 110
                            onClicked: addDcItemToCart()
                        }
                    }
                }
            }

            // Cart: the lines that will be printed on this challan.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: dcCartModel.count === 0
                                        ? 58
                                        : Math.min(180, 44 + dcCartModel.count * 38)
                border.color: "#1b9dd9"; radius: 5; color: "#ffffff"

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6; Layout.rightMargin: 6
                        spacing: 10
                        visible: dcCartModel.count > 0
                        Label { text: "Item"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.fillWidth: true }
                        Label { text: "Part No"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 160 }
                        Label { text: "HSN/SAC"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 130 }
                        Label { text: "Qty"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                        Label { text: "Unit"; font.bold: true; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 90 }
                        Item { Layout.preferredWidth: 30 }
                    }

                    ListView {
                        id: dcCartView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 5
                        model: dcCartModel
                        delegate: Rectangle {
                            width: dcCartView.width; height: 32
                            color: "#fff"; border.color: "#e0e0e0"; radius: 3
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 3; anchors.bottomMargin: 3
                                spacing: 10
                                Label {
                                    text: (index + 1) + ". " + model.itemName
                                    font.bold: true; font.pixelSize: 11
                                    Layout.fillWidth: true; Layout.minimumWidth: 120
                                    elide: Text.ElideRight
                                }
                                Label { text: model.partNo; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 160; elide: Text.ElideRight }
                                Label { text: model.hsnCode; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 130; elide: Text.ElideRight }
                                Label { text: formatQty(model.qty); font.pixelSize: 12; font.bold: true; color: "#1b9dd9"; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                                Label { text: model.unit; font.pixelSize: 11; color: "#2c3e50"; Layout.preferredWidth: 90; elide: Text.ElideRight }
                                Button {
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 24
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Remove this line"
                                    onClicked: dcCartModel.remove(index)
                                    contentItem: Text { text: "X"; color: "#e74c3c"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "No items added - use \"+ Add Item\" above"
                    visible: dcCartModel.count === 0; color: "#95a5a6"; font.pixelSize: 11
                }
            }

            // ---- Terms, who handed over, and the create button ----
            RowLayout {
                Layout.fillWidth: true; spacing: 12

                Label { text: "Terms &amp; Conditions:"; Layout.alignment: Qt.AlignTop; Layout.topMargin: 6 }
                TextArea {
                    id: dcTermsField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    placeholderText: "Printed at the foot of the challan"
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    background: Rectangle { color: "#ffffff"; border.color: "#bdc3c7"; radius: 3 }
                }

                ColumnLayout {
                    Layout.preferredWidth: 280; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Label { text: "Delivered By:"; Layout.preferredWidth: 84 }
                        TextField { id: dcDeliveredByField; Layout.fillWidth: true; text: excelHandler.currentUser; selectByMouse: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Label { text: "Received By:"; Layout.preferredWidth: 84 }
                        TextField { id: dcReceivedByField; Layout.fillWidth: true; placeholderText: "Left blank to sign on paper"; selectByMouse: true }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 210; spacing: 4
                    Label {
                        text: "Total quantity: " + formatQty(dcCartQty())
                        font.bold: true; font.pixelSize: 13; color: "#1b9dd9"
                        Layout.alignment: Qt.AlignRight
                    }
                    Button {
                        text: editingDCNumber === ""
                              ? "Create Challan (" + dcCartModel.count + (dcCartModel.count === 1 ? " item)" : " items)")
                              : "Update " + editingDCNumber
                        highlighted: true
                        enabled: dcCartModel.count > 0 && dcPartyNameField.text.trim() !== ""
                        Layout.fillWidth: true
                        onClicked: submitDeliveryChallan()
                    }
                }
            }

            // ---- Status filter + free-text search across the challan list ----
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 2; spacing: 10

                Label { text: "Filter:"; font.bold: true }
                ComboBox {
                    id: dcFilterCombo
                    Layout.preferredWidth: 160
                    model: ["All", "Draft", "Delivered", "Cancelled"]
                    onCurrentTextChanged: refreshDCList()
                }

                Label { text: "Search:"; font.bold: true; Layout.leftMargin: 6 }
                TextField {
                    id: dcSearchField
                    Layout.fillWidth: true
                    Layout.minimumWidth: 240
                    placeholderText: "Challan number, party, item, or date (e.g. 2026-08)"
                    selectByMouse: true
                    onTextChanged: applyDcSearch()
                    Keys.onEscapePressed: function(event) {
                        if (text !== "") text = ""
                        else event.accepted = false
                    }
                }
                Button {
                    text: "✕"
                    Layout.preferredWidth: 34
                    enabled: dcSearchField.text !== ""
                    ToolTip.visible: hovered
                    ToolTip.text: "Clear the search"
                    onClicked: dcSearchField.text = ""
                }
                Label {
                    text: dcSearchField.text.trim() === ""
                          ? dcListModel.count + (dcListModel.count === 1 ? " challan" : " challans")
                          : dcListModel.count + " of " + dcRowsCache.length + " match"
                    color: "#7f8c8d"; font.pixelSize: 11
                }
            }

            // ---- The challans already raised ----
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumHeight: 90
                border.color: "#dee2e6"; radius: 5

                ListView {
                    id: dcListView; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: dcListModel
                    delegate: Rectangle {
                        width: dcListView.width - 10; height: 68
                        color: {
                            if (model.status === "Delivered") return "#e8f8e8"
                            if (model.status === "Cancelled") return "#f4f4f4"
                            return "#fff8e8"
                        }
                        border.color: "#e0e0e0"; radius: 4

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true; Layout.minimumWidth: 200; spacing: 3
                                RowLayout {
                                    spacing: 8
                                    Label { text: model.dcNo; font.bold: true; font.pixelSize: 13; color: "#2c3e50" }
                                    Label {
                                        text: model.status
                                        font.pixelSize: 11; font.bold: true
                                        color: {
                                            if (model.status === "Delivered") return "#27ae60"
                                            if (model.status === "Cancelled") return "#95a5a6"
                                            return "#f39c12"
                                        }
                                    }
                                }
                                Label {
                                    text: "To: " + model.partyName +
                                          "  |  " + model.summary +
                                          "  |  Qty: " + formatQty(model.totalQty)
                                    font.pixelSize: 11; color: "#7f8c8d"
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Label {
                                    text: "Date: " + model.date +
                                          (model.deliveryTime !== "" ? "  |  Time: " + model.deliveryTime : "") +
                                          "  |  Delivered by: " + (model.deliveredBy || "-")
                                    font.pixelSize: 10; color: "#95a5a6"
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            Button {
                                text: "View"
                                onClicked: {
                                    selectedDCDetails = excelHandler.getDCByNumber(model.dcNo)
                                    selectedDCItems = excelHandler.getDCItems(model.dcNo)
                                    dcDetailsDialog.open()
                                }
                                contentItem: Text { text: "View"; color: "#2c3e50"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "PDF"
                                ToolTip.visible: hovered
                                ToolTip.text: "Preview and save the printed challan"
                                onClicked: openDcPdfPreview(model.dcNo)
                                contentItem: Text { text: "PDF"; color: "#1b9dd9"; font.pixelSize: 11; font.bold: true }
                            }
                            Button {
                                text: "Edit"
                                visible: model.status === "Draft"
                                onClicked: loadDcForEdit(model.dcNo)
                                contentItem: Text { text: "Edit"; color: "#8e44ad"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Delivered"
                                visible: model.status === "Draft"
                                onClicked: { excelHandler.updateDCStatus(model.dcNo, "Delivered"); refreshDCList() }
                                contentItem: Text { text: "Delivered"; color: "#27ae60"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Cancel"
                                visible: model.status !== "Cancelled"
                                onClicked: { excelHandler.updateDCStatus(model.dcNo, "Cancelled"); refreshDCList() }
                                contentItem: Text { text: "Cancel"; color: "#e67e22"; font.pixelSize: 11 }
                            }
                            Button {
                                text: "Delete"
                                onClicked: { dcPendingDelete = model.dcNo; dcDeleteConfirmDialog.open() }
                                contentItem: Text { text: "Delete"; color: "#e74c3c"; font.pixelSize: 11 }
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: dcSearchField.text.trim() === ""
                          ? "No delivery challans yet"
                          : "No challans match \"" + dcSearchField.text.trim() + "\""
                    visible: dcListModel.count === 0; color: "#95a5a6"
                }
            }

            Button { text: "Close"; Layout.alignment: Qt.AlignRight; onClicked: dcDialog.close() }
        }

        onOpened: {
            dcSearchField.text = ""
            if (editingDCNumber === "" && dcCartModel.count === 0)
                clearDcForm()
            refreshPartNameDropdown()
            refreshDCList()
        }
    }

    property string dcPendingDelete: ""

    Dialog {
        id: dcDeleteConfirmDialog
        title: "Delete Delivery Challan"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Yes | Dialog.No
        width: 460

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Delete " + dcPendingDelete + " and its items? The challan number will not be reused."
        }

        onAccepted: {
            if (excelHandler.deleteDeliveryChallan(dcPendingDelete)) {
                if (editingDCNumber === dcPendingDelete) clearDcForm()
                statusLabel.text = "Deleted " + dcPendingDelete
                statusTimer.restart()
                refreshDCList()
            }
            dcPendingDelete = ""
        }
    }

    /* ---- Item Master picker for a challan line ---- */

    ListModel { id: dcPartPickerModel }

    function refreshDcPartPicker(filter) {
        dcPartPickerModel.clear()
        var f = (filter || "").toString().trim().toLowerCase()
        var items = excelHandler.getItemMasterList()
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            var partName = (it.partName || "").toString()
            if (partName.trim() === "") continue
            var partNo = (it.partNo || "").toString()
            var hsn = (it.taxCode || it.hsnCode || "").toString()
            var unit = (it.unit || "").toString()
            if (f !== "" &&
                (partName + " " + partNo + " " + hsn + " " + unit).toLowerCase().indexOf(f) === -1)
                continue
            dcPartPickerModel.append({
                partName: partName, partNo: partNo, hsnCode: hsn, unit: unit
            })
        }
    }

    function openDcPartPicker() {
        dcPartSearchField.text = ""
        refreshDcPartPicker("")
        dcPartPickerDialog.open()
        dcPartSearchField.forceActiveFocus()
    }

    function chooseDcPart(item) {
        var idx = dcItemNameField.find(item.partName)
        if (idx >= 0) dcItemNameField.currentIndex = idx
        else dcItemNameField.editText = item.partName
        dcPartNoField.text = item.partNo
        dcHsnField.text = item.hsnCode
        dcUnitField.text = item.unit
        dcPartPickerDialog.close()
    }

    Dialog {
        id: dcPartPickerDialog
        title: "Search Item Master"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel
        width: Math.min(root.width - 120, 720)
        height: Math.min(root.height - 140, 520)

        ColumnLayout {
            anchors.fill: parent; spacing: 8

            TextField {
                id: dcPartSearchField
                Layout.fillWidth: true
                placeholderText: "Item name, part number, HSN code or unit"
                selectByMouse: true
                onTextChanged: refreshDcPartPicker(text)
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 4

                ListView {
                    id: dcPartPickerView
                    anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: dcPartPickerModel
                    delegate: Rectangle {
                        width: dcPartPickerView.width - 10; height: 46
                        color: "#fff"; border.color: "#e0e0e0"; radius: 3
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: chooseDcPart({
                                partName: model.partName, partNo: model.partNo,
                                hsnCode: model.hsnCode, unit: model.unit
                            })
                        }
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 6; spacing: 2
                            Label { text: model.partName; font.bold: true; font.pixelSize: 12; color: "#2c3e50" }
                            Label {
                                text: (model.partNo !== "" ? "Part No: " + model.partNo : "No part number") +
                                      (model.hsnCode !== "" ? "  |  HSN: " + model.hsnCode : "") +
                                      (model.unit !== "" ? "  |  Unit: " + model.unit : "")
                                font.pixelSize: 10; color: "#7f8c8d"
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "No matching items"
                    visible: dcPartPickerModel.count === 0; color: "#95a5a6"
                }
            }
        }
    }

    /* ---- Party picker ---- */

    Dialog {
        id: dcPartyPickerDialog
        title: "Search Parties"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel
        width: Math.min(root.width - 120, 720)
        height: Math.min(root.height - 140, 520)

        ColumnLayout {
            anchors.fill: parent; spacing: 8

            TextField {
                id: dcPartySearchField
                Layout.fillWidth: true
                placeholderText: "Party name, address, phone or GSTIN"
                selectByMouse: true
                onTextChanged: refreshDcPartyPicker(text)
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 4

                ListView {
                    id: dcPartyPickerView
                    anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: dcPartyPickerModel
                    delegate: Rectangle {
                        width: dcPartyPickerView.width - 10; height: 58
                        color: "#fff"; border.color: "#e0e0e0"; radius: 3
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: chooseDcParty({
                                name: model.name, address: model.address,
                                phone: model.phone, email: model.email, gstin: model.gstin
                            })
                        }
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 6; spacing: 2
                            RowLayout {
                                spacing: 8
                                Label { text: model.name; font.bold: true; font.pixelSize: 12; color: "#2c3e50" }
                                Label { text: model.source; font.pixelSize: 10; color: "#1b9dd9" }
                            }
                            Label {
                                text: model.address.replace(/\n/g, ", ")
                                font.pixelSize: 10; color: "#7f8c8d"
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Label {
                                text: (model.phone !== "" ? model.phone : "") +
                                      (model.gstin !== "" ? "  |  GSTIN: " + model.gstin : "")
                                font.pixelSize: 10; color: "#95a5a6"
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "No matching parties. Type the details in directly - they are remembered for next time."
                    visible: dcPartyPickerModel.count === 0; color: "#95a5a6"
                }
            }
        }
    }

    /* ---- Challan details ---- */

    Dialog {
        id: dcDetailsDialog
        title: "Delivery Challan " + (selectedDCDetails.dcNo || "")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Close
        width: Math.min(root.width - 120, 720)

        ColumnLayout {
            anchors.fill: parent; spacing: 8

            GridLayout {
                Layout.fillWidth: true
                columns: 4; rowSpacing: 4; columnSpacing: 10

                Label { text: "Challan No:"; font.bold: true }
                Label { text: selectedDCDetails.dcNo || "-"; Layout.fillWidth: true }
                Label { text: "Status:"; font.bold: true }
                Label { text: selectedDCDetails.status || "-"; Layout.fillWidth: true }

                Label { text: "Date:"; font.bold: true }
                Label { text: selectedDCDetails.date || "-"; Layout.fillWidth: true }
                Label { text: "Delivery Time:"; font.bold: true }
                Label { text: selectedDCDetails.deliveryTime || "-"; Layout.fillWidth: true }

                Label { text: "Party:"; font.bold: true }
                Label { text: selectedDCDetails.partyName || "-"; Layout.fillWidth: true; elide: Text.ElideRight }
                Label { text: "Party GSTIN:"; font.bold: true }
                Label { text: selectedDCDetails.partyGstin || "-"; Layout.fillWidth: true }

                Label { text: "Address:"; font.bold: true; Layout.alignment: Qt.AlignTop }
                Label {
                    text: (selectedDCDetails.partyAddress || "-").replace(/\n/g, ", ")
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
                Label { text: "Shipping To:"; font.bold: true; Layout.alignment: Qt.AlignTop }
                Label {
                    text: (selectedDCDetails.shipName || "-") +
                          ((selectedDCDetails.shipAddress || "") !== ""
                           ? ", " + selectedDCDetails.shipAddress.replace(/\n/g, ", ") : "")
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }

                Label { text: "Delivered By:"; font.bold: true }
                Label { text: selectedDCDetails.deliveredBy || "-"; Layout.fillWidth: true }
                Label { text: "Received By:"; font.bold: true }
                Label { text: selectedDCDetails.receivedBy || "-"; Layout.fillWidth: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#e0e0e0" }

            Label {
                text: "Items (" + selectedDCItems.length + ")"
                font.bold: true; color: "#2c3e50"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(220, 8 + selectedDCItems.length * 26)
                border.color: "#dee2e6"; radius: 4

                ListView {
                    id: dcDetailItemsView
                    anchors.fill: parent; anchors.margins: 4; clip: true
                    model: selectedDCItems
                    delegate: RowLayout {
                        width: dcDetailItemsView.width - 8
                        height: 26
                        spacing: 10
                        Label { text: (index + 1) + ". " + modelData.itemName; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label { text: modelData.hsnCode; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 120 }
                        Label { text: formatQty(modelData.qty) + " " + modelData.unit; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
                    }
                }
            }

            Button {
                text: "Open the printed challan"
                Layout.alignment: Qt.AlignRight
                onClicked: {
                    dcDetailsDialog.close()
                    openDcPdfPreview(selectedDCDetails.dcNo)
                }
            }
        }
    }

    /* ---- Printed challan preview ---- */

    Dialog {
        id: dcPdfPreviewDialog
        title: "Delivery Challan " + dcPreviewDcNo
        modal: true
        anchors.centerIn: parent
        width: Math.min(root.width - 80, 940)
        height: Math.min(root.height - 60, 900)
        standardButtons: Dialog.NoButton

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#525659"
                radius: 4

                ListView {
                    id: dcPreviewView
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    spacing: 12
                    model: dcPreviewPages
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        width: dcPreviewView.width - 20
                        // A4 aspect ratio, so the page keeps its proportions
                        // whatever the dialog is resized to.
                        height: width * 297 / 210
                        color: "white"
                        border.color: "#2c2c2c"

                        Image {
                            anchors.fill: parent
                            source: modelData
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            cache: false
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: dcPreviewPages.length + (dcPreviewPages.length === 1 ? " page" : " pages")
                    font.pixelSize: 11
                    color: "#7f8c8d"
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Open in PDF viewer"
                    onClicked: excelHandler.openInSystemViewer(dcPreviewPdfPath)
                }
                Button {
                    text: "Close"
                    onClicked: dcPdfPreviewDialog.close()
                }
                Button {
                    text: "Save PDF"
                    highlighted: true
                    ToolTip.visible: hovered
                    ToolTip.text: "Save this delivery challan as a PDF on this computer"
                    onClicked: sendDcPdf()
                }
            }
        }
    }

    Dialog {
        id: dcSavedDialog
        title: "Delivery Challan Saved"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        width: 560

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Label { text: "The delivery challan PDF has been saved to:"; font.bold: true }
            Label {
                text: dcLastSavedPdf
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
                color: "#2c3e50"
            }
            Button {
                text: "Open the file"
                onClicked: excelHandler.openInSystemViewer(dcLastSavedPdf)
            }
        }
    }

    /* ================= GRN (GOODS RECEIPT) DIALOG ================= */

    property int grnRemainingQty: 0

    // Line items of the PO being received.
    ListModel { id: grnItemsModel }

    function grnLoadItems(poNo) {
        grnItemsModel.clear()
        var lines = excelHandler.getPOItems(poNo)
        var firstOpen = -1
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i]
            grnItemsModel.append({
                itemId: l.id,
                label: l.partName + "  (" + l.receivedQty + "/" + l.qty + " received)",
                qty: l.qty,
                receivedQty: l.receivedQty
            })
            if (firstOpen === -1 && l.receivedQty < l.qty) firstOpen = i
        }
        grnItemCombo.currentIndex = firstOpen >= 0 ? firstOpen : 0
        grnApplySelection(grnItemCombo.currentIndex)
    }

    function grnApplySelection(index) {
        if (index < 0 || index >= grnItemsModel.count) {
            grnOrderQty.text = ""; grnReceivedSoFar.text = ""; grnRemainingQty = 0
            grnReceivedField.value = 0; grnAcceptedField.value = 0
            return
        }
        var line = grnItemsModel.get(index)
        grnOrderQty.text = line.qty.toString()
        grnReceivedSoFar.text = line.receivedQty.toString()
        grnRemainingQty = Math.max(0, line.qty - line.receivedQty)
        grnReceivedField.value = grnRemainingQty
        grnAcceptedField.value = grnRemainingQty
        grnRejectedField.value = 0
    }

    Dialog {
        id: grnDialog
        title: "Receive Goods (GRN)"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        width: 470

        ColumnLayout {
            spacing: 10; width: parent.width

            Label { text: "Goods Receipt Note"; font.bold: true; font.pixelSize: 14; color: "#27ae60" }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#27ae60" }

            GridLayout {
                columns: 2; rowSpacing: 8; columnSpacing: 10; Layout.fillWidth: true

                Label { text: "PO No:"; font.bold: true } Label { id: grnPOLabel; text: grnPOFieldText; font.bold: true; color: "#3498db" }
                Label { text: "Item*:"; font.bold: true }
                ComboBox {
                    id: grnItemCombo
                    Layout.fillWidth: true
                    model: grnItemsModel
                    textRole: "label"
                    onActivated: function(index) { grnApplySelection(index) }
                }
                Label { text: "Order Qty:" } Label { id: grnOrderQty; text: "" }
                Label { text: "Already Received:" } Label { id: grnReceivedSoFar; text: "" }
                Label { text: "Remaining:" ; font.bold: true } Label { text: grnRemainingQty.toString(); font.bold: true; color: "#e67e22" }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

            Label { text: "Received Qty:" }
            SpinBox { id: grnReceivedField; from: 0; to: 100000; value: 0; editable: true; Layout.fillWidth: true }

            Label { text: "Accepted Qty:" }
            SpinBox { id: grnAcceptedField; from: 0; to: 100000; value: 0; editable: true; Layout.fillWidth: true }

            Label { text: "Rejected Qty:" }
            SpinBox { id: grnRejectedField; from: 0; to: 100000; value: 0; editable: true; Layout.fillWidth: true }

            Label { text: "Received By*:" }
            TextField {
                id: grnReceivedByField
                Layout.fillWidth: true
                text: excelHandler.currentUser
                selectByMouse: true
            }

            Label { text: "Remarks:" }
            TextField { id: grnRemarksField; Layout.fillWidth: true; placeholderText: "Any remarks..." }
        }

        onAccepted: {
            if (grnItemCombo.currentIndex < 0 || grnItemsModel.count === 0) return
            var itemId = grnItemsModel.get(grnItemCombo.currentIndex).itemId
            var grnNo = excelHandler.receiveGoodsForItem(
                itemId, grnReceivedField.value,
                grnAcceptedField.value, grnRejectedField.value,
                grnRemarksField.text, grnReceivedByField.text)
            if (grnNo !== "") {
                refreshPOList()
                refreshMovements()
                rows = excelHandler.model.rowCount()
            }
        }
    }

    property string grnPOFieldText: ""

    /* ================= ISSUE STOCK DIALOG ================= */

    // Parts collected for the next material issue (the "cart").
    ListModel { id: issueCartModel }

    function addIssueItemToCart() {
        var partName = (issuePartField.editText || issuePartField.currentText || "").toString().trim()
        if (partName === "") { statusLabel.text = "Select a part first"; statusTimer.restart(); return }
        // Merge duplicate parts into one line.
        for (var i = 0; i < issueCartModel.count; i++) {
            if (issueCartModel.get(i).partName === partName) {
                issueCartModel.setProperty(i, "qty", issueCartModel.get(i).qty + issueQtyField.value)
                issuePartField.currentIndex = -1; issuePartField.editText = ""; issueQtyField.value = 1
                return
            }
        }
        issueCartModel.append({ partName: partName, qty: issueQtyField.value })
        issuePartField.currentIndex = -1
        issuePartField.editText = ""
        issueQtyField.value = 1
    }

    Dialog {
        id: issueDialog
        title: "Issue Stock to Department"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        width: 470

        ColumnLayout {
            spacing: 10; width: parent.width

            Label { text: "Material Issue Note"; font.bold: true; font.pixelSize: 14; color: "#e67e22" }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#e67e22" }

            Label { text: "Search Part:" }
            TextField {
                id: issueSearchField
                Layout.fillWidth: true
                placeholderText: "Type to filter available parts..."
                selectByMouse: true
                onTextChanged: refreshIssuePartDropdown(text)
            }

            Rectangle {
                Layout.fillWidth: true; height: 100
                border.color: "#dee2e6"; radius: 4; color: "#f8f9fa"

                ListView {
                    anchors.fill: parent; anchors.margins: 4; clip: true; spacing: 4
                    model: issueSearchModel
                    delegate: Rectangle {
                        width: parent.width; height: 28
                        color: "#fff"; border.color: "#e0e0e0"; radius: 3
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 6
                            Label { text: model.name; font.pixelSize: 12; font.bold: true; color: "#2c3e50"; Layout.fillWidth: true }
                            Label { text: "Stock: " + model.stock; font.pixelSize: 11; color: "#27ae60" }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                issuePartField.editText = model.name
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "No matching parts"
                    visible: issueSearchModel.count === 0
                    color: "#95a5a6"
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Label { text: "Part Name*:" }
                    ComboBox {
                        id: issuePartField
                        Layout.fillWidth: true
                        editable: true
                        model: issueSearchModel
                        textRole: "name"
                    }
                }
                ColumnLayout {
                    spacing: 2
                    Label { text: "Quantity*:" }
                    SpinBox { id: issueQtyField; from: 1; to: 100000; value: 1; editable: true }
                }
                ColumnLayout {
                    spacing: 2
                    Label { text: " " }
                    Button { text: "+ Add"; highlighted: true; onClicked: addIssueItemToCart() }
                }
            }

            // Cart: parts that will be issued together under one issue number
            Rectangle {
                Layout.fillWidth: true; height: 96
                border.color: "#e67e22"; radius: 4; color: "#fffaf5"

                ListView {
                    id: issueCartView
                    anchors.fill: parent; anchors.margins: 4; clip: true; spacing: 2
                    model: issueCartModel
                    delegate: Rectangle {
                        width: issueCartView.width - 8; height: 24
                        color: "#fff"; border.color: "#e0e0e0"; radius: 3
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 4
                            Label { text: (index + 1) + ". " + model.partName; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                            Label { text: "Qty: " + model.qty; font.pixelSize: 11; color: "#e67e22" }
                            Button {
                                text: "X"
                                Layout.preferredWidth: 24; Layout.preferredHeight: 18
                                onClicked: issueCartModel.remove(index)
                                contentItem: Text { text: "X"; color: "#e74c3c"; font.pixelSize: 9; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "No parts added - use \"+ Add\" (several parts can go in one issue)"
                    visible: issueCartModel.count === 0
                    color: "#95a5a6"; font.pixelSize: 11
                }
            }

            Label { text: "Issue To Department*:" }
            ComboBox { id: issueDeptField; Layout.fillWidth: true; editable: true; model: ["Electronics", "Mechanical", "Hardware", "Software", "Production", "R&D", "Other"] }

            Label { text: "Issued By:" }
            TextField { id: issueByField; Layout.fillWidth: true; text: excelHandler.currentUser; selectByMouse: true }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

            Label { text: "Stock will be deducted automatically for every part in the list"; font.pixelSize: 10; color: "#e67e22"; wrapMode: Text.WordWrap }
        }

        onAccepted: {
            // Anything still sitting in the entry fields counts as one more line.
            var pendingPart = (issuePartField.editText || issuePartField.currentText || "").toString().trim()
            if (pendingPart !== "") addIssueItemToCart()

            if (issueCartModel.count === 0) {
                statusLabel.text = "Add at least one part to issue"
                statusTimer.restart()
                return
            }

            var items = []
            for (var i = 0; i < issueCartModel.count; i++) {
                var it = issueCartModel.get(i)
                items.push({ partName: it.partName, qty: it.qty })
            }
            var issueNo = excelHandler.issueMultipleStock(
                items, issueDeptField.currentText, issueByField.text)
            if (issueNo !== "") {
                issueCartModel.clear()
                issuePartField.currentIndex = -1
                issuePartField.editText = ""
                issueQtyField.value = 1
                rows = excelHandler.model.rowCount()
                refreshMovements()
            }
        }

        onOpened: {
            issueSearchField.text = ""
            issueCartModel.clear()
            refreshIssuePartDropdown("")
            issueByField.text = excelHandler.currentUser
        }
    }

    /* ================= STOCK MOVEMENTS DIALOG ================= */

    Dialog {
        id: movementsDialog
        title: "Stock Movement History"
        modal: true
        anchors.centerIn: parent
        width: 800; height: 600

        ColumnLayout {
            anchors.fill: parent; spacing: 10

            Label { text: "Audit Trail - All Stock Movements"; font.bold: true; font.pixelSize: 16; color: "#2c3e50" }

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                TextField {
                    id: movFilterField; Layout.fillWidth: true
                    placeholderText: "Filter by part name..."; selectByMouse: true
                    onTextChanged: refreshMovements()
                }
                Label { text: movementsModel.count + " records"; font.bold: true; color: "#7f8c8d" }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 5

                // Header
                Rectangle {
                    id: movHeader; width: parent.width; height: 30; color: "#2c3e50"
                    Row {
                        anchors.fill: parent; spacing: 0
                        Repeater {
                            model: [
                                {text: "Date", w: 150}, {text: "Part Name", w: 180},
                                {text: "Type", w: 80}, {text: "Qty", w: 60},
                                {text: "Reference", w: 200}, {text: "Done By", w: 110}
                            ]
                            Rectangle {
                                width: modelData.w; height: 30; color: "transparent"
                                Text { anchors.centerIn: parent; text: modelData.text; color: "white"; font.bold: true; font.pixelSize: 11 }
                            }
                        }
                    }
                }

                ListView {
                    id: movListView
                    anchors.top: movHeader.bottom; anchors.left: parent.left
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 2; clip: true; spacing: 1
                    model: ListModel { id: movementsModel }
                    delegate: Rectangle {
                        width: movListView.width; height: 30
                        color: index % 2 === 0 ? "#fff" : "#f8f9fa"
                        Row {
                            anchors.fill: parent; spacing: 0
                            Rectangle { width: 150; height: 30; color: "transparent"; Text { anchors.verticalCenter: parent.verticalCenter; x: 5; text: model.date; font.pixelSize: 11 } }
                            Rectangle { width: 180; height: 30; color: "transparent"; Text { anchors.verticalCenter: parent.verticalCenter; x: 5; text: model.partName; font.pixelSize: 11; font.bold: true } }
                            Rectangle {
                                width: 80; height: 30; color: "transparent"
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter; x: 5; text: model.type; font.pixelSize: 11; font.bold: true
                                    color: {
                                        if (model.type === "IN") return "#27ae60"
                                        if (model.type === "OUT") return "#e74c3c"
                                        if (model.type === "REJECTED") return "#e67e22"
                                        return "#3498db"
                                    }
                                }
                            }
                            Rectangle { width: 60; height: 30; color: "transparent"; Text { anchors.verticalCenter: parent.verticalCenter; x: 5; text: model.qty; font.pixelSize: 11; font.bold: true } }
                            Rectangle { width: 200; height: 30; color: "transparent"; Text { anchors.verticalCenter: parent.verticalCenter; x: 5; text: model.reference; font.pixelSize: 11; color: "#7f8c8d" } }
                            Rectangle { width: 110; height: 30; color: "transparent"; Text { anchors.verticalCenter: parent.verticalCenter; x: 5; text: model.doneBy; font.pixelSize: 11 } }
                        }
                    }
                }

                Label { anchors.centerIn: parent; y: 30; text: "No movements recorded"; visible: movementsModel.count === 0; color: "#95a5a6" }
            }

            Button { text: "Close"; Layout.alignment: Qt.AlignRight; onClicked: movementsDialog.close() }
        }

        onOpened: { refreshMovements() }
    }

    /* ================= REPORTS DIALOG ================= */

    Dialog {
        id: reportsDialog
        title: "Export Reports"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Close
        width: 420

        ColumnLayout {
            anchors.fill: parent; spacing: 10
            Label { text: "Export stock movements, issues, GRN, and POs"; font.bold: true }

            Label { text: "From Date (YYYY-MM-DD):" }
            TextField { id: reportFromField; Layout.fillWidth: true; placeholderText: "2025-01-01" }

            Label { text: "To Date (YYYY-MM-DD):" }
            TextField { id: reportToField; Layout.fillWidth: true; placeholderText: "2025-01-31" }

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: "Export"
                    highlighted: true
                    onClicked: {
                        var path = excelHandler.browseSaveFile("Save Report", "Excel files (*.xlsx)")
                        if (path === "") return
                        if (excelHandler.exportReport(reportFromField.text, reportToField.text, path)) {
                            statusLabel.text = "Report saved"
                            statusTimer.restart()
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    function refreshMovements() {
        movementsModel.clear()
        var movements = excelHandler.getStockMovements(movFilterField.text)
        for (var i = movements.length - 1; i >= 0; i--) movementsModel.append(movements[i])
    }

    /* ================= LOW STOCK ALERT DIALOG ================= */

    Dialog {
        id: lowStockDialog
        title: "Low Stock Alerts"
        modal: true
        anchors.centerIn: parent
        width: 700; height: 500

        ColumnLayout {
            anchors.fill: parent; spacing: 10

            Label { text: "Items Below Reorder Level"; font.bold: true; font.pixelSize: 16; color: "#e74c3c" }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 5

                ListView {
                    id: lowStockListView; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: ListModel { id: lowStockModel }
                    delegate: Rectangle {
                        width: lowStockListView.width - 10; height: 60
                        color: "#fff5f5"; border.color: "#e74c3c"; border.width: 1; radius: 4
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label { text: model.partName + (model.partNo ? "  (" + model.partNo + ")" : ""); font.bold: true; font.pixelSize: 13 }
                                Label {
                                    text: "Stock: " + model.stock + " | Required: " + model.requiredQty + " | On order: " + model.onOrder + " | Shortage: " + model.shortage
                                    font.pixelSize: 11; color: "#e74c3c"
                                }
                            }
                            Label { text: model.vendor ? "Vendor: " + model.vendor : "No vendor set!"; font.pixelSize: 11; color: model.vendor ? "#7f8c8d" : "#e74c3c" }
                        }
                    }
                }

                Label { anchors.centerIn: parent; text: "All stock levels are OK!"; visible: lowStockModel.count === 0; color: "#27ae60"; font.pixelSize: 14 }
            }

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: "Auto-Generate PO for Low Stock"
                    highlighted: true
                    enabled: lowStockModel.count > 0
                    onClicked: {
                        if (excelHandler.autoGeneratePOForLowStock()) {
                            statusLabel.text = "Draft PO generated for low stock items"
                            statusTimer.restart()
                            refreshLowStock()
                            refreshPOList()
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Button { text: "Close"; onClicked: lowStockDialog.close() }
            }
        }

        onOpened: { refreshLowStock() }
    }

    function refreshLowStock() {
        lowStockModel.clear()
        var items = excelHandler.getLowStockItems()
        for (var i = 0; i < items.length; i++) lowStockModel.append(items[i])
    }

    /* ================= ISSUE NOTES LIST DIALOG ================= */

    Dialog {
        id: issueNotesDialog
        title: "Issue Notes History"
        modal: true
        anchors.centerIn: parent
        width: 700; height: 500

        ColumnLayout {
            anchors.fill: parent; spacing: 10

            Label { text: "Material Issue History"; font.bold: true; font.pixelSize: 16; color: "#e67e22" }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                border.color: "#dee2e6"; radius: 5

                ListView {
                    id: issueNotesListView; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                    model: ListModel { id: issueNotesModel }
                    delegate: Rectangle {
                        width: issueNotesListView.width - 10; height: 50
                        color: "#fff"; border.color: "#e67e22"; border.width: 1; radius: 4
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8
                            Label { text: model.issueNo; font.bold: true; color: "#e67e22"; Layout.preferredWidth: 100 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label { text: model.partName + " x" + model.qty; font.bold: true; font.pixelSize: 12 }
                                Label { text: "To: " + model.department + " | By: " + model.issuedBy + " | " + model.date; font.pixelSize: 10; color: "#7f8c8d" }
                            }
                        }
                    }
                }

                Label { anchors.centerIn: parent; text: "No issues recorded"; visible: issueNotesModel.count === 0; color: "#95a5a6" }
            }

            Button { text: "Close"; Layout.alignment: Qt.AlignRight; onClicked: issueNotesDialog.close() }
        }

        onOpened: {
            issueNotesModel.clear()
            var notes = excelHandler.getIssueNotes()
            for (var i = 0; i < notes.length; i++) issueNotesModel.append(notes[i])
        }
    }

    /* ================= DATABASE CONNECTION DIALOG ================= */

    // True while this computer is talking to a shared server rather than its own
    // local file; gates the one-time "copy my data up" step below.
    property bool dbOnServer: false
    // True when this machine is set up to use the shared server but is running
    // on its own local copy instead, so nothing it does is seen by anyone else.
    property bool dbUsingLocalFallback: false
    property string dbFallbackReason: ""
    property string dbConfiguredHost: ""

    function refreshDbConnectionState() {
        var cfg = excelHandler.getDatabaseSettings()
        root.dbOnServer = excelHandler.isDatabaseServerBackend()
        root.dbConfiguredHost = cfg.host || ""
        root.dbUsingLocalFallback = (cfg.driver === "QPSQL") && !root.dbOnServer
        root.dbFallbackReason = excelHandler.databaseLastError()
    }

    function retryDatabaseConnection() {
        var cfg = excelHandler.getDatabaseSettings()
        statusLabel.text = "Reconnecting to " + cfg.host + "..."
        excelHandler.configureDatabase(cfg.driver, cfg.host, cfg.port,
                                       cfg.name, cfg.user, cfg.password)
        refreshDbConnectionState()
        if (root.dbOnServer) {
            rows = excelHandler.model.rowCount()
            columns = excelHandler.model.columnCount()
            root.tableRefreshToken++
            refreshStockOverview()
            statusLabel.text = "Connected to the shared database"
        } else {
            statusLabel.text = "Still cannot reach " + cfg.host
        }
        statusTimer.restart()
    }

    Dialog {
        id: cloudSettingsDialog
        title: "Database Connection"
        modal: true
        width: 560
        height: parent ? Math.min(780, parent.height - 60) : 780
        anchors.centerIn: parent

        onOpened: {
            root.dbOnServer = excelHandler.isDatabaseServerBackend()
            dbCopyResult.text = ""
            var cfg = excelHandler.getDatabaseSettings()
            dbDriverCombo.currentIndex = (cfg.driver === "QPSQL") ? 1 : 0
            dbHostField.text = cfg.host !== undefined ? cfg.host : ""
            dbPortField.text = (cfg.port !== undefined ? cfg.port : 5432).toString()
            dbNameField.text = cfg.name !== undefined ? cfg.name : "stockmanager"
            dbUserField.text = cfg.user !== undefined ? cfg.user : ""
            dbPassField.text = cfg.password !== undefined ? cfg.password : ""
            dbStatusLabel.text = excelHandler.databaseStatus()
            serverInfoBox.visible = false
            root.dbSetupBusy = false
        }

        ScrollView {
            id: dbSettingsScroll
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

        ColumnLayout {
            spacing: 16; width: dbSettingsScroll.availableWidth

            Label {
                text: "All data is stored in one shared database so everyone works on the same\nnumbers. Pick ONE computer to be the server; every other computer connects to it."
                color: "#7f8c8d"; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap
            }

            /* -------- Option 1: make THIS computer the server -------- */
            Rectangle {
                Layout.fillWidth: true; radius: 6
                color: "#f4f9ff"; border.color: "#3498db"; border.width: 1
                implicitHeight: serverSetupCol.implicitHeight + 24
                ColumnLayout {
                    id: serverSetupCol
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Label { text: "① Make this computer the server"; font.bold: true; color: "#2c3e50" }
                    Label {
                        text: "Installs and configures the shared database on THIS computer. Do this on\njust one machine (the one that stays on). You'll be asked for your system password."
                        color: "#7f8c8d"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        spacing: 10; Layout.fillWidth: true
                        Button {
                            text: root.dbSetupBusy ? "Setting up..." : "Set up this computer as the server"
                            enabled: !root.dbSetupBusy
                            onClicked: {
                                root.dbSetupBusy = true
                                serverInfoBox.visible = false
                                dbStatusLabel.text = "Starting server setup..."
                                excelHandler.setupThisComputerAsServer()
                            }
                        }
                        BusyIndicator { running: root.dbSetupBusy; visible: root.dbSetupBusy; implicitWidth: 28; implicitHeight: 28 }
                    }
                    Rectangle {
                        id: serverInfoBox
                        visible: false
                        Layout.fillWidth: true; radius: 4
                        color: "#eafaf1"; border.color: "#27ae60"; border.width: 1
                        implicitHeight: serverInfoCol.implicitHeight + 20
                        ColumnLayout {
                            id: serverInfoCol
                            anchors.fill: parent; anchors.margins: 10; spacing: 3
                            Label { text: "✓ This computer is now the server. On every OTHER computer, open this"; font.pixelSize: 11; font.bold: true; color: "#1e8449"; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            Label { text: "same dialog, choose PostgreSQL, and enter:"; font.pixelSize: 11; font.bold: true; color: "#1e8449"; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            Label { text: "   Host: " + dbHostField.text + "   Port: " + dbPortField.text; font.pixelSize: 11; font.family: "monospace"; color: "#145a32" }
                            Label { text: "   Database: " + dbNameField.text + "   User: " + dbUserField.text; font.pixelSize: 11; font.family: "monospace"; color: "#145a32" }
                            Label { text: "   Password: " + dbPassField.text; font.pixelSize: 11; font.family: "monospace"; color: "#145a32" }
                            Label { text: "Write these down — the password is shown only here."; font.pixelSize: 10; font.italic: true; color: "#7f8c8d"; Layout.topMargin: 4 }
                        }
                    }
                }
            }

            /* -------- Option 2: connect to an existing server -------- */
            Label { text: "② Or connect to a server / choose storage"; font.bold: true; color: "#2c3e50" }
            ComboBox {
                id: dbDriverCombo; Layout.fillWidth: true
                model: ["SQLite (local file — this computer only)", "PostgreSQL (connect to shared server)"]
            }

            GridLayout {
                columns: 2; rowSpacing: 8; columnSpacing: 10; Layout.fillWidth: true
                enabled: dbDriverCombo.currentIndex === 1
                Label { text: "Host:" }     TextField { id: dbHostField; Layout.fillWidth: true; placeholderText: "192.168.1.10 (the server computer)" }
                Label { text: "Port:" }     TextField { id: dbPortField; Layout.fillWidth: true; placeholderText: "5432"; inputMethodHints: Qt.ImhDigitsOnly }
                Label { text: "Database:" } TextField { id: dbNameField; Layout.fillWidth: true; placeholderText: "stockmanager" }
                Label { text: "User:" }     TextField { id: dbUserField; Layout.fillWidth: true }
                Label { text: "Password:" } TextField { id: dbPassField; Layout.fillWidth: true; echoMode: TextInput.Password }
            }

            Label { id: dbStatusLabel; text: ""; color: "#2c3e50"; Layout.fillWidth: true; wrapMode: Text.WordWrap }

            /* -------- Option 3: bring existing work onto the server -------- */
            Rectangle {
                Layout.fillWidth: true; radius: 6
                color: root.dbOnServer ? "#fdf6e3" : "#f6f6f6"
                border.color: root.dbOnServer ? "#e67e22" : "#dcdcdc"; border.width: 1
                implicitHeight: dbCopyCol.implicitHeight + 24
                ColumnLayout {
                    id: dbCopyCol
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Label { text: "\u2462 Bring this computer's existing work onto the server"; font.bold: true; color: "#2c3e50" }
                    Label {
                        text: "Run this ONCE, on the computer that already has your stock, item master and\npurchase orders. It copies them into the shared database so every other computer\nsees them, and carries PO/GRN numbering on from where you are."
                        color: "#7f8c8d"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap
                    }
                    Label {
                        text: "Connect to the shared server above first \u2014 this step needs a server connection."
                        visible: !root.dbOnServer
                        color: "#c0392b"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap
                    }
                    Button {
                        text: "Copy this computer's data to the server"
                        enabled: root.dbOnServer && !root.dbSetupBusy
                        onClicked: {
                            var res = excelHandler.copyLocalDataToServer()
                            dbCopyResult.text = res.message || ""
                            dbCopyResult.isError = !res.success
                            if (res.success) {
                                // The stock grid and PO list are showing the
                                // pre-copy server contents; refresh both.
                                root.rows = excelHandler.model.rowCount()
                                root.columns = excelHandler.model.columnCount()
                                root.tableRefreshToken++
                                refreshPOList()
                                statusLabel.text = res.message
                                statusTimer.restart()
                            }
                        }
                    }
                    Label {
                        id: dbCopyResult
                        property bool isError: false
                        text: ""; visible: text !== ""
                        color: isError ? "#c0392b" : "#1e8449"
                        font.pixelSize: 11; font.bold: true
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Button { text: "Close"; enabled: !root.dbSetupBusy; onClicked: cloudSettingsDialog.close() }
                Button {
                    text: "Connect & Save"; highlighted: true; enabled: !root.dbSetupBusy
                    onClicked: {
                        var wantServer = dbDriverCombo.currentIndex === 1
                        var driver = wantServer ? "QPSQL" : "QSQLITE"
                        excelHandler.configureDatabase(
                            driver, dbHostField.text, parseInt(dbPortField.text) || 5432,
                            dbNameField.text, dbUserField.text, dbPassField.text)

                        // configureDatabase() reports success even when it
                        // silently fell back to a local SQLite file. If the
                        // user asked for the shared server but we did NOT end
                        // up on a server backend, that's a real failure the
                        // user must see — otherwise their edits won't be shared.
                        if (wantServer && !excelHandler.isDatabaseServerBackend()) {
                            dbStatusLabel.text =
                                "Could NOT connect to PostgreSQL — using a LOCAL file, so data will NOT be shared.\n"
                                + "Reason: " + excelHandler.databaseLastError()
                            statusLabel.text = "PostgreSQL connection failed (using local file)"
                        } else {
                            dbStatusLabel.text = excelHandler.databaseStatus()
                            statusLabel.text = wantServer ? "Connected to shared database"
                                                          : "Using local database (this computer only)"
                            refreshDbConnectionState()
                            // Stay open after joining a server so the one-time
                            // data copy below is right where it is needed.
                            if (!wantServer) cloudSettingsDialog.close()
                        }
                    }
                }
            }
        }
        }
    }

    /* ================= TOOLBAR ================= */

    header: ToolBar {
        background: Rectangle { color: "#34495e" }

        RowLayout {
            anchors.fill: parent; spacing: 3

            // FILE OPERATIONS
            // ToolButton {
            //     text: "New Stock"
            //     onClicked: newStockFileDialog.open()
            //     ToolTip.visible: hovered; ToolTip.text: "Create new stock file"
            //     contentItem: Text { text: parent.text; color: "#27ae60"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            // }

            ToolButton {
                text: "Open"
                onClicked: openExcelFile()
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Import Stock"
                enabled: loginDialog.isAuthenticated
                onClicked: importStockFileAction()
                ToolTip.visible: hovered; ToolTip.text: "Import a stock xlsx into the shared database (login required)"
                contentItem: Text { text: parent.text; color: parent.enabled ? "#f39c12" : "#7f8c8d"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Save"
                enabled: excelHandler.currentFile !== "" && loginDialog.isAuthenticated
                onClicked: excelHandler.saveExcel("")
                contentItem: Text { text: parent.text; color: parent.enabled ? "white" : "#7f8c8d"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Save As"
                enabled: loginDialog.isAuthenticated
                onClicked: saveAsExcelFile()
                contentItem: Text { text: parent.text; color: parent.enabled ? "white" : "#7f8c8d"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
            }

            ToolSeparator { contentItem: Rectangle { implicitWidth: 1; implicitHeight: 24; color: "#7f8c8d" } }

            // SUPPLY CHAIN BUTTONS
            ToolButton {
                text: "Vendor Master"
                onClicked: vendorDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Manage Vendors"
                contentItem: Text { text: parent.text; color: "#1abc9c"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Item Master"
                onClicked: itemMasterDialog.open()
                ToolTip.visible:hovered; ToolTip.text: "Manage Item"
                contentItem: Text { text: parent.text; color: "#0ed0d6"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: {
                    var count = excelHandler.pendingRequestCount
                    return "Purchase Requests" + (count > 0 ? " (" + count + ")" : "")
                }
                onClicked: prDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Ask for something to be bought, and see every open request"
                contentItem: Text {
                    text: parent.text
                    color: excelHandler.pendingRequestCount > 0 ? "#e67e22" : "#f1c40f"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.bold: true; font.pixelSize: 11
                }
            }

            ToolButton {
                text: "Purchase Orders"
                enabled: loginDialog.isAuthenticated
                onClicked: poDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Create/manage purchase orders"
                contentItem: Text { text: parent.text; color: parent.enabled ? "#3498db" : "#7f8c8d"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Delivery Challan"
                enabled: loginDialog.isAuthenticated
                onClicked: dcDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Create/print delivery challans"
                contentItem: Text { text: parent.text; color: parent.enabled ? "#1b9dd9" : "#7f8c8d"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Issue Stock"
                enabled: loginDialog.isAuthenticated
                onClicked: issueDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Issue stock to department"
                contentItem: Text { text: parent.text; color: parent.enabled ? "#e67e22" : "#7f8c8d"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Movements"
                onClicked: movementsDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Stock movement audit trail"
                contentItem: Text { text: parent.text; color: "#9b59b6"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Reports"
                onClicked: reportsDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Export reports"
                contentItem: Text { text: parent.text; color: "#16a085"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: {
                    var count = excelHandler.lowStockCount
                    return "Low Stock" + (count > 0 ? " (" + count + ")" : "")
                }
                onClicked: lowStockDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "View low stock alerts"
                contentItem: Text {
                    text: parent.text
                    color: excelHandler.lowStockCount > 0 ? "#e74c3c" : "#27ae60"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.bold: true; font.pixelSize: 11
                }
            }

            ToolSeparator { contentItem: Rectangle { implicitWidth: 1; implicitHeight: 24; color: "#7f8c8d" } }

            // STOCK OPERATIONS
            ToolButton {
                text: "Search"
                onClicked: searchDialog.open()
                contentItem: Text { text: parent.text; color: "#3498db"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Add Item"
                enabled: loginDialog.isAuthenticated
                onClicked: addItemDialog.open()
                contentItem: Text { text: parent.text; color: parent.enabled ? "#3498db" : "#7f8c8d"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            ToolButton {
                text: "+Row"
                enabled: loginDialog.isAuthenticated
                ToolTip.visible: hovered
                ToolTip.text: "Add an empty row, then right-click it to fill it in"
                onClicked: {
                    excelHandler.model.addRow()
                    rows = excelHandler.model.rowCount()
                    statusLabel.text = "Row added - right-click it and choose Edit Row to fill it in"
                    statusTimer.restart()
                }
                contentItem: Text { text: parent.text; color: parent.enabled ? "white" : "#7f8c8d"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Issued History"
                onClicked: issueNotesDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "View issue notes history"
                contentItem: Text { text: parent.text; color: "#e67e22"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            Item { Layout.fillWidth: true }

            // LOGIN
            ToolButton {
                text: loginDialog.isAuthenticated ? "Logout" : "Login"
                onClicked: loginDialog.isAuthenticated ? (loginDialog.isAuthenticated = false) : loginDialog.open()
                contentItem: Text { text: parent.text; color: loginDialog.isAuthenticated ? "#2ecc71" : "#e74c3c"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
            }

            // STATUS
            Label {
                text: loginDialog.isAuthenticated ?
                      (excelHandler.hasUnsavedChanges ? "Unsaved" : "Saved") : "Read-Only"
                color: loginDialog.isAuthenticated ?
                       (excelHandler.hasUnsavedChanges ? "#e74c3c" : "#2ecc71") : "#f39c12"
                font.bold: true; font.pixelSize: 11
            }

            Label { text: excelHandler.currentUser; color: "white"; font.pixelSize: 11 }

            // DATABASE
            ToolButton {
                text: "Refresh"
                onClicked: {
                    excelHandler.refreshFromDatabase()
                    rows = excelHandler.model.rowCount()
                    columns = excelHandler.model.columnCount()
                    root.tableRefreshToken++
                    refreshStockOverview()
                    statusLabel.text = "Refreshed from database"
                }
                ToolTip.visible: hovered; ToolTip.text: "Reload latest data from the shared database"
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Company"
                onClicked: companyProfileDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Company details printed on purchase orders"
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
            }

            ToolButton {
                text: "Database"
                onClicked: cloudSettingsDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Database Connection Settings"
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 }
            }
        }
    }

    /* ================= MAIN TABLE ================= */

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // Working alone when this machine was set up to share. Worth saying
        // loudly and permanently: everything still works, but none of it
        // reaches the people who expect to see it.
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 44
            color: "#fdecea"; border.color: "#e74c3c"; border.width: 1
            visible: root.dbUsingLocalFallback

            RowLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Label {
                        text: "Not connected to the shared server" +
                              (root.dbConfiguredHost !== "" ? " (" + root.dbConfiguredHost + ")" : "") +
                              " - working on this computer's own copy. Your changes will NOT be seen by anyone else."
                        font.pixelSize: 12; color: "#c0392b"; font.bold: true
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Label {
                        text: root.dbFallbackReason
                        visible: text !== ""
                        font.pixelSize: 10; color: "#96504a"
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }

                Button {
                    text: "Retry"
                    ToolTip.visible: hovered
                    ToolTip.text: "Try the shared server again"
                    onClicked: retryDatabaseConnection()
                    contentItem: Text { text: "Retry"; color: "#c0392b"; font.bold: true; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    text: "Settings"
                    onClicked: cloudSettingsDialog.open()
                    contentItem: Text { text: "Settings"; color: "#c0392b"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }

        // Low stock warning
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 35
            color: "#fde8e8"; border.color: "#e74c3c"; border.width: 1
            visible: excelHandler.lowStockCount > 0

            RowLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 10
                Label { text: excelHandler.lowStockCount + " item(s) below reorder level!"; font.pixelSize: 13; color: "#c0392b"; font.bold: true; Layout.fillWidth: true }
                Button {
                    text: "View"; flat: true
                    onClicked: lowStockDialog.open()
                    contentItem: Text { text: "View Details"; color: "#e74c3c"; font.bold: true; font.pixelSize: 12 }
                }
            }
        }

        // ---- Headline totals ----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 78
            color: "#ffffff"; border.color: "#e3e7ea"

            RowLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 28

                Repeater {
                    model: [
                        { label: "Parts tracked", value: (root.stockTotalsData.parts || 0).toString() },
                        { label: "Units in stock", value: groupIndianDigits(root.stockTotalsData.units || 0).replace(".00", "") },
                        { label: "Stock value", value: formatRupees(root.stockTotalsData.value || 0) },
                        { label: "Departments", value: (root.stockTotalsData.departments || 0).toString() }
                    ]
                    ColumnLayout {
                        spacing: 2
                        Label {
                            text: modelData.label.toUpperCase()
                            font.pixelSize: 10; font.letterSpacing: 0.6
                            color: "#8a9199"
                        }
                        Label {
                            text: modelData.value
                            font.pixelSize: 22; font.bold: true
                            color: "#1f2933"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: root.overviewExpanded ? "Hide breakdown" : "Show breakdown"
                    flat: true
                    onClicked: root.overviewExpanded = !root.overviewExpanded
                    contentItem: Text {
                        text: parent.text; color: "#2a78d6"; font.pixelSize: 12; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // ---- Department segregation + distribution ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(340, Math.max(210,
                                    104 + root.deptSummary.length * 32))
            visible: root.overviewExpanded
            color: "#ffffff"; border.color: "#e3e7ea"

            RowLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 20

                // Department list: the selector, and the exact numbers behind
                // the ring beside it.
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "STOCK BY DEPARTMENT"; font.pixelSize: 10; font.letterSpacing: 0.6; color: "#8a9199" }
                        Item { Layout.fillWidth: true }
                        Label {
                            text: root.selectedDepartment === ""
                                  ? "showing all"
                                  : "showing " + root.selectedDepartment
                            font.pixelSize: 10; color: "#8a9199"
                        }
                    }

                    // "All" row, then one row per department.
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 30
                        radius: 4
                        color: root.selectedDepartment === "" ? "#eaf2fd" : (allDeptHover.hovered ? "#f4f6f8" : "transparent")
                        border.color: root.selectedDepartment === "" ? "#2a78d6" : "transparent"

                        HoverHandler { id: allDeptHover }
                        TapHandler { onTapped: root.selectedDepartment = "" }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 10
                            Rectangle { width: 10; height: 10; radius: 2; color: "#5b6770" }
                            Label { text: "All departments"; font.pixelSize: 12; font.bold: true; color: "#1f2933"; Layout.fillWidth: true }
                            Label {
                                text: (root.stockTotalsData.parts || 0) +
                                      ((root.stockTotalsData.parts === 1) ? " part" : " parts")
                                font.pixelSize: 11; color: "#8a9199"
                            }
                            Label {
                                text: groupIndianDigits(root.stockTotalsData.units || 0).replace(".00", "")
                                font.pixelSize: 12; font.bold: true; color: "#1f2933"
                                Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight
                            }
                            Item { Layout.preferredWidth: 106 }
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true

                        ListView {
                            id: deptListView
                            model: root.deptSummary
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                width: deptListView.width
                                height: 30
                                radius: 4
                                property bool isSelected: root.selectedDepartment === modelData.department
                                color: isSelected ? "#eaf2fd" : (deptHover.hovered ? "#f4f6f8" : "transparent")
                                border.color: isSelected ? "#2a78d6" : "transparent"

                                HoverHandler { id: deptHover }
                                TapHandler {
                                    // Clicking the selected department again clears the filter.
                                    onTapped: root.selectedDepartment =
                                              isSelected ? "" : modelData.department
                                }

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 10

                                    Rectangle {
                                        width: 10; height: 10; radius: 2
                                        color: root.departmentColor(modelData.colorIndex)
                                    }
                                    Label {
                                        text: modelData.department
                                        font.pixelSize: 12; color: "#1f2933"
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    Label {
                                        text: modelData.parts + (modelData.parts === 1 ? " part" : " parts")
                                        font.pixelSize: 11; color: "#8a9199"
                                    }
                                    Label {
                                        text: groupIndianDigits(modelData.qty).replace(".00", "")
                                        font.pixelSize: 12; font.bold: true; color: "#1f2933"
                                        Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight
                                    }
                                    // Share of total units, on a single-hue track.
                                    Rectangle {
                                        Layout.preferredWidth: 64; Layout.preferredHeight: 6
                                        radius: 3; color: "#eceff1"
                                        Rectangle {
                                            width: Math.max(2, parent.width * modelData.share)
                                            height: parent.height; radius: 3
                                            color: root.departmentColor(modelData.colorIndex)
                                        }
                                    }
                                    Label {
                                        text: Math.round(modelData.share * 100) + "%"
                                        font.pixelSize: 11; color: "#5b6770"
                                        Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        text: "No stock rows yet"
                        visible: root.deptSummary.length === 0
                        color: "#8a9199"; font.pixelSize: 11
                    }
                }

                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#e3e7ea" }

                // Distribution ring. Click a slice to filter, hover for the number.
                Item {
                    Layout.preferredWidth: 260; Layout.fillHeight: true

                    Label {
                        id: donutTitle
                        anchors.top: parent.top; anchors.left: parent.left
                        text: "SHARE OF UNITS"
                        font.pixelSize: 10; font.letterSpacing: 0.6; color: "#8a9199"
                    }

                    Canvas {
                        id: donutCanvas
                        anchors.top: donutTitle.bottom; anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width, parent.height - 26)
                        height: width

                        property var slices: root.donutSlices()
                        property int hovered: -1
                        onSlicesChanged: requestPaint()
                        onHoveredChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var cx = width / 2, cy = height / 2
                            var outer = Math.min(cx, cy) - 2
                            var inner = outer * 0.62
                            var mid = (outer + inner) / 2

                            var total = 0
                            for (var i = 0; i < slices.length; i++) total += slices[i].qty
                            if (total <= 0) {
                                ctx.strokeStyle = "#eceff1"; ctx.lineWidth = outer - inner
                                ctx.beginPath(); ctx.arc(cx, cy, mid, 0, Math.PI * 2); ctx.stroke()
                                return
                            }

                            // 2px of surface between neighbouring segments, so the
                            // ring reads as separate holdings rather than a blend.
                            var gap = 2 / mid
                            var angle = -Math.PI / 2
                            for (var s = 0; s < slices.length; s++) {
                                var sweep = (slices[s].qty / total) * Math.PI * 2
                                var grow = (hovered === s) ? 3 : 0
                                ctx.beginPath()
                                ctx.strokeStyle = slices[s].color
                                ctx.lineWidth = (outer - inner) + grow
                                var a0 = angle + gap / 2
                                var a1 = angle + sweep - gap / 2
                                if (a1 > a0) {
                                    ctx.arc(cx, cy, mid, a0, a1)
                                    ctx.stroke()
                                }
                                angle += sweep
                            }

                            // Direct-label only the slices with room for it, so
                            // the ring is readable without chasing the legend.
                            ctx.font = "bold 11px sans-serif"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            angle = -Math.PI / 2
                            for (var t = 0; t < slices.length; t++) {
                                var frac = slices[t].qty / total
                                var span = frac * Math.PI * 2
                                if (frac >= 0.10) {
                                    var a = angle + span / 2
                                    ctx.fillStyle = "#ffffff"
                                    ctx.fillText(Math.round(frac * 100) + "%",
                                                 cx + Math.cos(a) * mid,
                                                 cy + Math.sin(a) * mid)
                                }
                                angle += span
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onExited: donutCanvas.hovered = -1
                            onPositionChanged: function(mouse) {
                                var cx = width / 2, cy = height / 2
                                var dx = mouse.x - cx, dy = mouse.y - cy
                                var dist = Math.sqrt(dx * dx + dy * dy)
                                var outer = Math.min(cx, cy) - 2
                                if (dist > outer || dist < outer * 0.62) {
                                    donutCanvas.hovered = -1
                                    return
                                }
                                // Angles run clockwise from twelve o'clock.
                                var a = Math.atan2(dy, dx) + Math.PI / 2
                                if (a < 0) a += Math.PI * 2
                                var total = 0
                                for (var i = 0; i < donutCanvas.slices.length; i++)
                                    total += donutCanvas.slices[i].qty
                                var acc = 0
                                for (var s = 0; s < donutCanvas.slices.length; s++) {
                                    acc += (donutCanvas.slices[s].qty / total) * Math.PI * 2
                                    if (a <= acc) { donutCanvas.hovered = s; return }
                                }
                                donutCanvas.hovered = -1
                            }
                            onClicked: {
                                var h = donutCanvas.hovered
                                if (h < 0) return
                                var slice = donutCanvas.slices[h]
                                if (slice.isOther) return       // a group, not a department
                                root.selectedDepartment =
                                    (root.selectedDepartment === slice.label) ? "" : slice.label
                            }
                        }

                        // Centre reads the total, or the hovered slice.
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0
                            width: donutCanvas.width * 0.5
                            Label {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: {
                                    var h = donutCanvas.hovered
                                    if (h >= 0) return groupIndianDigits(donutCanvas.slices[h].qty).replace(".00", "")
                                    return groupIndianDigits(root.stockTotalsData.units || 0).replace(".00", "")
                                }
                                font.pixelSize: 20; font.bold: true; color: "#1f2933"
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: {
                                    var h = donutCanvas.hovered
                                    if (h >= 0) return donutCanvas.slices[h].label
                                    return "units total"
                                }
                                font.pixelSize: 10; color: "#8a9199"
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }
                    }
                }
            }
        }

        // Column Headers (9 columns)
        Rectangle {
            id: tableHeader
            Layout.fillWidth: true; Layout.preferredHeight: 35; color: "#2c3e50"

            Row {
                anchors.fill: parent; spacing: 0

                Rectangle {
                    width: 40; height: 35; color: "#2c3e50"; border.color: "#1a252f"
                    Text { anchors.centerIn: parent; text: "#"; color: "white"; font.bold: true; font.pixelSize: 11 }
                }

                Repeater {
                    model: 9

                    Rectangle {
                        width: root.columnWidth(index)
                        height: 35; color: "#34495e"; border.color: "#2c3e50"

                        Text {
                            anchors.centerIn: parent
                            text: {
                                var headers = ["Part Name", "Part No",
                                    root.fileType === "purchase" ? "Purchase" : "Stock",
                                    "Department", "Prepared", "Approved", "Vendor",
                                    "Date", "Unit Price"]
                                return headers[index]
                            }
                            color: "white"; font.bold: true; font.pixelSize: 11
                        }
                    }
                }
            }
        }

        // Data Area
        ScrollView {
            id: stockScroll
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true

            Label {
                anchors.centerIn: parent
                visible: root.visibleStockRows.length === 0
                text: root.selectedDepartment === ""
                      ? "No stock rows"
                      : "No stock rows in " + root.selectedDepartment
                color: "#8a9199"
            }

            ListView {
                id: tableListView
                anchors.fill: parent
                clip: true
                // Only the rows of the chosen department; r stays the real model
                // row so editing, selection and delete keep working unchanged.
                model: root.visibleStockRows.length

                delegate: Row {
                    spacing: 0
                    property int r: root.visibleStockRows[index]

                    Rectangle {
                        width: 40; height: 32
                        color: root.selectedRow === r ? "#27ae60" : "#95a5a6"
                        border.color: "#7f8c8d"
                        Text { anchors.centerIn: parent; text: r; color: root.selectedRow === r ? "white" : "#2c3e50"; font.bold: root.selectedRow === r; font.pixelSize: 11 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    if (r <= 0) return
                                    root.selectedRow = r
                                    root.contextRow = r
                                    var p = mapToItem(null, mouse.x, mouse.y)
                                    rowContextMenu.popup(p.x, p.y)
                                    return
                                }
                                root.selectedRow = r
                            }
                        }
                    }

                    Repeater {
                        model: 9

                        Rectangle {
                            width: root.columnWidth(index)
                            height: 32
                            color: {
                                var _refresh = root.tableRefreshToken
                                if (root.selectedRow === r) return "#d5f4e6"
                                return "white"
                            }
                            border.color: "#dfe6e9"

                            property int c: index

                            // Read-only on the face of it. Stock is shared by
                            // every machine, so it is changed through the
                            // dialogs that record who did what - never by
                            // typing over a cell in passing.
                            Text {
                                anchors.fill: parent; anchors.margins: 3
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: {
                                    var _refresh = root.tableRefreshToken
                                    var v = excelHandler.model.getData(r, c)
                                    return v === null || v === undefined ? "" : v.toString()
                                }
                                color: "#2c3e50"
                                font.pixelSize: 12
                            }

                            // Selecting and the row menu work anywhere on the
                            // row, not just on its number.
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    root.selectedRow = r
                                    if (mouse.button === Qt.RightButton && r > 0) {
                                        root.contextRow = r
                                        var p = mapToItem(null, mouse.x, mouse.y)
                                        rowContextMenu.popup(p.x, p.y)
                                    }
                                }
                                onDoubleClicked: openStockRowEditor(r)
                            }
                        }
                    }
                }
            }
        }
    }

    /* ================= FOOTER ================= */

    Menu {
        id: rowContextMenu
        MenuItem {
            text: "Edit Row..."
            enabled: loginDialog.isAuthenticated && root.contextRow > 0
            onTriggered: openStockRowEditor(root.contextRow)
        }
        MenuItem {
            text: "Delete Row"
            enabled: loginDialog.isAuthenticated && root.contextRow > 0
            onTriggered: {
                if (excelHandler.model.removeRowAt(root.contextRow)) {
                    rows = excelHandler.model.rowCount()
                    if (root.selectedRow === root.contextRow) root.selectedRow = -1
                }
            }
        }
    }

    footer: ToolBar {
        background: Rectangle { color: "#ecf0f1"; border.color: "#bdc3c7" }

        RowLayout {
            anchors.fill: parent; anchors.margins: 5; spacing: 15

            Label { id: statusLabel; text: "Ready"; font.pixelSize: 12; color: "#2c3e50" }
            Timer { id: statusTimer; interval: 5000; onTriggered: statusLabel.text = "Ready" }

            Rectangle { width: 1; height: 20; color: "#bdc3c7" }
            Label { text: "Rows: " + rows; font.bold: true; color: "#34495e" }

            Rectangle { width: 1; height: 20; color: "#bdc3c7" }
            Label { text: "Vendors: " + excelHandler.totalVendors; color: "#1abc9c"; font.bold: true }

            Rectangle { width: 1; height: 20; color: "#bdc3c7" }
            Label { text: "Pending POs: " + excelHandler.pendingPOCount; color: excelHandler.pendingPOCount > 0 ? "#e67e22" : "#27ae60"; font.bold: true }

            Item { Layout.fillWidth: true }

            Label {
                text: excelHandler.permanentFile !== "" ? excelHandler.getFileName() : "No permanent file"
                color: excelHandler.permanentFile !== "" ? "#27ae60" : "#e67e22"
                font.bold: excelHandler.permanentFile !== ""
            }
        }
    }

    /* ================= INITIALIZATION ================= */






    Component.onCompleted: {
        console.log("========================================")
        console.log("Enstein Stock Manager + Supply Chain Init")

        // Stock is loaded from the shared database by the backend at startup.
        rows = excelHandler.model.rowCount()
        columns = excelHandler.model.columnCount()
        root.fileType = "stock"
        refreshDbConnectionState()
        statusLabel.text = root.dbUsingLocalFallback
                ? "Working on this computer's local copy - the shared server did not answer"
                : (excelHandler.isDatabaseConnected()
                   ? "Ready - stock loaded from database"
                   : "Warning: database not connected")

        refreshStockOverview()

        statusTimer.restart()
        console.log("System initialized")
        console.log("========================================")
    }
}
