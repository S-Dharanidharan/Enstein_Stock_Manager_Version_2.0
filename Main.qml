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
    property var tableBaseWidths: [350, 190, 130, 200, 180, 200, 260, 190, 140]
    property var tableMinWidths: [140, 90, 70, 90, 90, 90, 110, 90, 80]

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

        onPurchaseOrderCreated: function(poNo) {
            statusLabel.text = "PO Created: " + poNo
            statusTimer.restart()
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
            ComboBox { id: categoryField; Layout.fillWidth: true; editable: true; model: ["Electronics", "Mechanical", "Hardware", "Software", "Other"] }

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
        width: 700; height: 600

        ColumnLayout {
            anchors.fill: parent; spacing: 10

            Label { text: "Vendor Master"; font.bold: true; font.pixelSize: 16; color: "#2c3e50" }  

            // Add Vendor Form
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 250   //180
                color: "#f8f9fa"; border.color: "#dee2e6"; radius: 5

                GridLayout {
                    anchors.fill: parent; anchors.margins: 10
                    columns: 4; rowSpacing: 8; columnSpacing: 10

                    Label { text: "Name:" } TextField { id: vendorNameField; Layout.fillWidth: true; placeholderText: "Vendor name" }
                    Label { text: "Address:" } TextField { id: vendorAddressField; Layout.fillWidth: true; placeholderText: "Address" }
                    Label { text: "Name of Bank & Branch:" } TextField { id: vendorBankBranchField; Layout.fillWidth: true; placeholderText: "Bank and branch name" }
                    Label { text: "IFSC Code:" } TextField { id: vendorIfscField; Layout.fillWidth: true; placeholderText: "IFSC code" }
                    Label { text: "Bank Account Number:" } TextField { id: vendorAccountField; Layout.fillWidth: true; placeholderText: "Account number" }
                    Label { text: "CIN Number" } TextField { id: vendorCinField; Layout.fillWidth: true; placeholderText: "CIN number" }
                    Label { text: "GSTIN Number:" } TextField { id: vendorGstinField; Layout.fillWidth: true; placeholderText: "GSTIN number" }
                    Label { text: "PAN Number:" } TextField { id: vendorPANField; Layout.fillWidth: true; placeholderText: "PAN number" }
                    Label { text: "Name in PAN Card:" } TextField { id: vendorPanNameField; Layout.fillWidth: true; placeholderText: "Name as per PAN card" }
                    Label { text: "Contact Person:" } TextField { id: vendorContactPersonField; Layout.fillWidth: true; placeholderText: "Contact person name" }
                    Label { text: "Email:" } TextField { id: vendorEmailField; Layout.fillWidth: true; placeholderText: "Email" }
                    Label { text: "Phone No:" } TextField { id: vendorPhoneNumberField; Layout.fillWidth: true; placeholderText: "Phone number" }
                    Label { text: "Item Category:" } TextField { id: vendorItemCategoryField; Layout.fillWidth: true; placeholderText: "Categories supplied" }

                    Item {} // spacer
                    
                    Button {
                        text: "Add Vendor"; highlighted: true
                        
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
                                    Label { text: model.name; font.bold: true; font.pixelSize: 13 }
                                    Label { text: model.phone + "  |  " + model.email + "  |  " + model.bankBranch; font.pixelSize: 11; color: "#7f8c8d" }
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
        width: 700

        ColumnLayout {
            spacing: 10; width: parent.width
            Label { text: "Edit Vendor Details"; font.bold: true; font.pixelSize: 14 }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

            GridLayout {
                Layout.fillWidth: true
                Layout.margins: 10
                columns: 4; rowSpacing: 8; columnSpacing: 10

                Label { text: "Name:" } TextField { id: editVendorNameField; Layout.fillWidth: true; placeholderText: "Vendor name" }
                Label { text: "Address:" } TextField { id: editVendorAddressField; Layout.fillWidth: true; placeholderText: "Address" }
                Label { text: "Name of Bank & Branch:" } TextField { id: editVendorBankBranchField; Layout.fillWidth: true; placeholderText: "Bank and branch name" }
                Label { text: "IFSC Code:" } TextField { id: editVendorIfscField; Layout.fillWidth: true; placeholderText: "IFSC code" }
                Label { text: "Bank Account Number:" } TextField { id: editVendorAccountField; Layout.fillWidth: true; placeholderText: "Account number" }
                Label { text: "CIN Number" } TextField { id: editVendorCinField; Layout.fillWidth: true; placeholderText: "CIN number" }
                Label { text: "GSTIN Number:" } TextField { id: editVendorGstinField; Layout.fillWidth: true; placeholderText: "GSTIN number" }
                Label { text: "PAN Number:" } TextField { id: editVendorPANField; Layout.fillWidth: true; placeholderText: "PAN number" }
                Label { text: "Name in PAN Card:" } TextField { id: editVendorPanNameField; Layout.fillWidth: true; placeholderText: "Name as per PAN card" }
                Label { text: "Contact Person:" } TextField { id: editVendorContactPersonField; Layout.fillWidth: true; placeholderText: "Contact person name" }
                Label { text: "Email:" } TextField { id: editVendorEmailField; Layout.fillWidth: true; placeholderText: "Email" }
                Label { text: "Phone No:" } TextField { id: editVendorPhoneNumberField; Layout.fillWidth: true; placeholderText: "Phone number" }
                Label { text: "Item Category:" } TextField { id: editVendorItemCategoryField; Layout.fillWidth: true; placeholderText: "Categories supplied" }
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
            var name = (v.name || "").toString()
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

    function openPoVendorPicker() {
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

    function choosePoVendor(name) {
        var idx = poVendorField.find(name)
        if (idx >= 0) poVendorField.currentIndex = idx
        else poVendorField.editText = name
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
        itemDetailsDialog.open()
    }

    /* =================  ITEM MASTER DIALOG =================== */             

    Dialog {
        id: itemMasterDialog
        title: "Item Master Management"
        modal: true
        anchors.centerIn: parent
        width: 750; height: 650

        ColumnLayout{
            anchors.fill: parent; spacing: 10

            Label { text: "Item Master"; font.bold: true; font.pixelSize: 16; color: "#2c3e50"}

            Rectangle {  
                Layout.fillWidth: true; Layout.preferredHeight: 200
                color: "#f0f8ff"; border.color: "#3498db"; radius: 5 

                GridLayout {
                    anchors.fill: parent; anchors.margins: 10
                    columns: 4; rowSpacing: 8; columnSpacing: 10

                    Label { text: "Part Name:" } TextField { id: itemPartNameField; Layout.fillWidth: true; placeholderText: "Part name" }
                    Label { text: "Part No:" } TextField { id: itemPartNoField; Layout.fillWidth: true; placeholderText: "Part number" }
                    Label { text: "Department:" } TextField { id: itemDepartmentField; Layout.fillWidth: true; placeholderText: "Department" }
                    Label { text: "Unit Price:" }
                    TextField {
                        id: itemUnitPriceField
                        Layout.fillWidth: true
                        placeholderText: "0.00"
                        text: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        selectByMouse: true
                    }
                    Label { text: "Required Quantity:" } SpinBox { id: itemRequiredQtyField; from: 0; to: 100000; value: 0; editable: true }
                    Label { text: "Vendor Preferred:" } ComboBox{ id: itemVendorField; Layout.fillWidth: true; editable: true; model: excelHandler.getVendorNames() }

                    Item {}   
                    Button {
                        text: "Add/Update Item"; highlighted: true  
                        onClicked: {
                            var itemMasterDetails = {
                                partName: itemPartNameField.text,
                                partNo: itemPartNoField.text,
                                department: itemDepartmentField.text,
                                category: itemDepartmentField.text,
                                unitPrice: parseAmount(itemUnitPriceField.text),
                                requiredQty: itemRequiredQtyField.value,
                                stockQty: itemRequiredQtyField.value,
                                vendor: itemVendorField.currentText
                            }
                            if (excelHandler.addItemMasterDetails(itemMasterDetails)) {
                                refreshItemMasterList()
                                itemPartNameField.text = ""; itemPartNoField.text = ""; itemDepartmentField.text = "";
                                itemUnitPriceField.text = "0.00"; itemRequiredQtyField.value = 0; itemVendorField.currentIndex = -1;
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
                    placeholderText: "Search by part name, part no, department, vendor..."
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
                                    Label { text: model.partName + " (" + model.partNo + ")"; font.bold: true; font.pixelSize: 13; color: "#2c3e50" }
                                    Label { text: "Department: " + model.department + " | Vendor: " + model.vendor; font.pixelSize: 11; color: "#7f8c8d" }
                                    Label { text: "Unit Price: " + formatRupees(model.unitPrice) + " | Required Qty: " + model.requiredQty; font.pixelSize: 10; color: "#95a5a6" }
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
                                            vendor: model.vendor
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
        width: 700

        ColumnLayout {
            spacing: 10; width: parent.width
            Label { text: "Edit Item Details"; font.bold: true; font.pixelSize: 14 }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#ccc" }

            GridLayout {
                Layout.fillWidth: true
                columns: 4; rowSpacing: 8; columnSpacing: 10

                Label { text: "Part Name:" } TextField { id: editItemPartNameField; Layout.fillWidth: true; placeholderText: "Part name" }
                Label { text: "Part No:" } TextField { id: editItemPartNoField; Layout.fillWidth: true; placeholderText: "Part number" }
                Label { text: "Department:" } TextField { id: editItemDepartmentField; Layout.fillWidth: true; placeholderText: "Department" }
                Label { text: "Unit Price:" }
                TextField {
                    id: editItemUnitPriceField
                    Layout.fillWidth: true
                    placeholderText: "0.00"
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    selectByMouse: true
                }
                Label { text: "Required Quantity:" } SpinBox { id: editItemRequiredQtyField; from: 0; to: 100000; value: 0; editable: true }
                Label { text: "Vendor Preferred:" } ComboBox { id: editItemVendorField; Layout.fillWidth: true; editable: true; model: excelHandler.getVendorNames() }
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
                vendor: editItemVendorField.currentText
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
                var haystack = [
                    item.partName, item.partNo, department, item.vendor
                ].join(" ").toLowerCase()
                if (query !== "" && haystack.indexOf(query) === -1) continue
                itemMasterListModel.append({
                    partName: item.partName || "",
                    partNo: item.partNo || "",
                    department: department,
                    unitPrice: item.unitPrice || 0,
                    requiredQty: requiredQty,
                    vendor: item.vendor || "",
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
                vendor: item.vendor || ""
            }
        }

        poPartLookup = lookup
        poPartDetailsLookup = detailsLookup
        poPartNameField.model = partNames
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

    function formatRupees(value) {
        var n = parseFloat(value)
        if (isNaN(n)) n = 0
        return "\u20B9 " + n.toFixed(2)
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
        width: 780; height: 760

        ColumnLayout {
            anchors.fill: parent; spacing: 10

            Label { text: "Purchase Orders"; font.bold: true; font.pixelSize: 16; color: "#2c3e50" }

            // Create PO Form - add one or more items to the cart, then create
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 170
                color: "#f0f8ff"; border.color: "#3498db"; radius: 5

                GridLayout {
                    anchors.fill: parent; anchors.margins: 10
                    columns: 4; rowSpacing: 8; columnSpacing: 10

                    Label { text: "Next PO:"; font.bold: true } Label { text: excelHandler.getNextPONumber(); color: "#3498db"; font.bold: true }
                    Label { text: "Date:" } Label { text: Qt.formatDate(new Date(), "yyyy-MM-dd") }

                    Label { text: "Part Name*:" }
                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox {
                            id: poPartNameField
                            Layout.fillWidth: true
                            editable: true
                            model: []
                            onCurrentTextChanged: applyPoPartDetails(currentText)
                            onActivated: function(index) {
                                if (index >= 0) showPoPartDetails(currentText)
                            }
                        }
                        Button {
                            text: "\u{1F50D}"
                            ToolTip.visible: hovered
                            ToolTip.text: "Search the Item Master"
                            onClicked: openPoPartPicker()
                        }
                        Button {
                            text: "i"
                            font.bold: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Show selected part details"
                            onClicked: showPoPartDetails(poPartNameField.currentText)
                        }
                    }
                    Label { text: "Vendor*:" }
                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox {
                            id: poVendorField; Layout.fillWidth: true; editable: true
                            model: excelHandler.getVendorNames()
                        }
                        Button {
                            text: "\u{1F50D}"
                            ToolTip.visible: hovered
                            ToolTip.text: "Search vendors"
                            onClicked: openPoVendorPicker()
                        }
                    }

                    Label { text: "Part No:" } TextField { id: poPartNoField; Layout.fillWidth: true; placeholderText: "Part number" }
                    Label { text: "Department:" }
                    TextField {
                        id: poDepartmentField
                        Layout.fillWidth: true
                        selectByMouse: true
                        placeholderText: "Auto-filled from Item Master, or type one"
                        // textEdited fires only on user input, so the autofill
                        // above does not count as the user claiming the field.
                        onTextEdited: poDepartmentAutoFilled = false
                    }

                    Label { text: "Qty*:" } SpinBox { id: poQtyField; from: 1; to: 100000; value: 1; editable: true }
                    Label { text: "Unit Price:" }
                    TextField {
                        id: poUnitPriceField
                        Layout.fillWidth: true
                        placeholderText: "0.00"
                        text: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        selectByMouse: true
                    }

                    Label { text: "Line Total:"; font.bold: true }
                    Label {
                        text: formatRupees(poQtyField.value * parseAmount(poUnitPriceField.text))
                        color: "#27ae60"
                        font.bold: true
                    }
                    Item {}
                    Button {
                        text: "+ Add Item"
                        highlighted: true
                        onClicked: addPoItemToCart()
                    }
                }
            }

            // Cart: items that will go into this PO
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 120
                border.color: "#3498db"; radius: 5; color: "#fbfdff"

                ListView {
                    id: poCartView
                    anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 2
                    model: poCartModel
                    delegate: Rectangle {
                        width: poCartView.width - 10; height: 26
                        color: "#fff"; border.color: "#e0e0e0"; radius: 3
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 4
                            Label { text: (index + 1) + ". " + model.partName; font.bold: true; font.pixelSize: 11; Layout.preferredWidth: 200; elide: Text.ElideRight }
                            Label { text: "Vendor: " + model.vendor; font.pixelSize: 11; color: "#7f8c8d"; Layout.preferredWidth: 160; elide: Text.ElideRight }
                            Label { text: model.qty + " x " + formatRupees(model.unitPrice) + " = " + formatRupees(model.lineTotal); font.pixelSize: 11; color: "#27ae60"; Layout.fillWidth: true }
                            Button {
                                text: "X"
                                Layout.preferredWidth: 26; Layout.preferredHeight: 20
                                onClicked: { poCartModel.remove(index); recalcPoCartTotal() }
                                contentItem: Text { text: "X"; color: "#e74c3c"; font.pixelSize: 10; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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

            // PO-level fields + create
            RowLayout {
                Layout.fillWidth: true; spacing: 8

                Label { text: "Expected:" }
                TextField {
                    id: poExpectedField
                    Layout.preferredWidth: 110
                    placeholderText: "YYYY-MM-DD"
                    readOnly: true
                    selectByMouse: true
                }
                Button { text: "Pick"; onClicked: expectedDateDialog.open() }

                Label { text: "Prepared By*:" }
                TextField {
                    id: poPreparedByField
                    Layout.fillWidth: true
                    placeholderText: "Enter preparer name"
                    text: excelHandler.currentUser
                    selectByMouse: true
                }

                Label { text: "Total: " + formatRupees(poCartTotal); font.bold: true; color: "#27ae60" }

                Button {
                    text: "Create PO (" + poCartModel.count + (poCartModel.count === 1 ? " item)" : " items)")
                    highlighted: true
                    enabled: poCartModel.count > 0
                    onClicked: {
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
                            items, poExpectedField.text, poPreparedByField.text)
                        if (poNo !== "") {
                            poCartModel.clear()
                            recalcPoCartTotal()
                            poExpectedField.text = ""
                            refreshPOList()
                            openPoPdfPreview(poNo)
                        }
                    }
                }
            }

            // Filter
            RowLayout {
                Label { text: "Filter:"; font.bold: true } 
                ComboBox {
                    id: poFilterCombo
                    model: ["All", "Draft", "Sent", "Partially Received", "Received", "Closed"]
                    onCurrentTextChanged: refreshPOList()
                }
                Item { Layout.fillWidth: true }
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
                        width: poListView.width - 10; height: 70
                        color: {
                            if (model.status === "Received") return "#e8f8e8"
                            if (model.status === "Draft") return "#fff8e8"
                            return "#fff"
                        }
                        border.color: "#e0e0e0"; radius: 4

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                RowLayout {
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
                                Label { text: model.partName + " | Qty: " + model.qty + " | Vendor: " + model.vendor; font.pixelSize: 11; color: "#7f8c8d" }
                                Label {
                                    text: "Price: " + formatRupees(model.unitPrice) +
                                          " | Total: " + formatRupees(model.totalAmount) +
                                          " | Date: " + model.date +
                                          " | Received: " + model.receivedQty + "/" + model.qty +
                                          " | Rec Date: " + (model.receivedDate || "-")
                                    font.pixelSize: 10
                                    color: "#95a5a6"
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

                Label { anchors.centerIn: parent; text: "No purchase orders"; visible: poListModel.count === 0; color: "#95a5a6" }
            }

            Button { text: "Close"; Layout.alignment: Qt.AlignRight; onClicked: poDialog.close() }
        }

        onOpened: {
            refreshPOList()
            refreshVendorDropdowns()
            refreshPartNameDropdown()
        }
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
                    placeholderText: "0.00"
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    selectByMouse: true
                }

                Label { text: "Expected Date:" }
                TextField { id: editPoExpectedField; Layout.fillWidth: true; placeholderText: "YYYY-MM-DD"; selectByMouse: true }

                Label { text: "Prepared By:" }
                TextField { id: editPoPreparedByField; Layout.fillWidth: true; selectByMouse: true }
            }

            Label {
                text: "Total: " + formatRupees(editPoQtyField.value * parseAmount(editPoUnitPriceField.text))
                font.bold: true
                color: "#27ae60"
            }
        }

        onAccepted: {
                var payload = {
                    vendor: editPoVendorField.text,
                    partName: editPoPartNameField.text,
                    partNo: editPoPartNoField.text,
                    department: editPoDepartmentField.text,
                    qty: editPoQtyField.value,
                    unitPrice: parseAmount(editPoUnitPriceField.text),
                    expectedDate: editPoExpectedField.text,
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
        width: 500

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
                }
            }

            Label { text: "Department: " + (selectedPODetails.department || "-"); visible: selectedPOItems.length <= 1 }
            Label { text: "Vendor(s): " + (selectedPODetails.vendor || "-") }
            Label { text: "Total Qty: " + (selectedPODetails.qty || 0) }
            Label { text: "Total Price: " + formatRupees(selectedPODetails.totalAmount || 0); font.bold: true; color: "#27ae60" }
            Label { text: "Expected Date: " + (selectedPODetails.expectedDate || "-") }
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
                        choosePoVendor(poVendorPickerModel.get(0).name)
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
                            onClicked: choosePoVendor(model.name)
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

    Dialog {
        id: expectedDateDialog
        title: "Select Expected Date"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 420
        height: 420
        property int displayMonth: (new Date()).getMonth() + 1
        property int displayYear: (new Date()).getFullYear()
        property date selectedDate: new Date()

        onOpened: {
            var parsed = new Date(poExpectedField.text)
            if (!isNaN(parsed.getTime())) {
                selectedDate = parsed
            } else {
                selectedDate = new Date()
            }
            displayMonth = selectedDate.getMonth() + 1
            displayYear = selectedDate.getFullYear()
        }

        onAccepted: {
            poExpectedField.text = Qt.formatDate(selectedDate, "yyyy-MM-dd")
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

    function refreshPOList() {
        poListModel.clear()
        var filter = poFilterCombo.currentText === "All" ? "" : poFilterCombo.currentText
        var pos = excelHandler.getPOList(filter)
        for (var i = 0; i < pos.length; i++) poListModel.append(pos[i])
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

    Dialog {
        id: cloudSettingsDialog
        title: "Database Connection"
        modal: true
        width: 540
        anchors.centerIn: parent

        onOpened: {
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

        ColumnLayout {
            spacing: 16; width: parent.width

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
                            cloudSettingsDialog.close()
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
                text: "Purchase Orders"
                enabled: loginDialog.isAuthenticated
                onClicked: poDialog.open()
                ToolTip.visible: hovered; ToolTip.text: "Create/manage purchase orders"
                contentItem: Text { text: parent.text; color: parent.enabled ? "#3498db" : "#7f8c8d"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
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
                onClicked: { excelHandler.model.addRow(); rows = excelHandler.model.rowCount(); statusLabel.text = "Added new row" }
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
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true

            ListView {
                id: tableListView
                anchors.fill: parent
                clip: true
                model: root.dataRows

                delegate: Row {
                    spacing: 0
                    property int r: index + 1

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

                            TextInput {
                                anchors.fill: parent; anchors.margins: 3
                                verticalAlignment: Text.AlignVCenter
                                selectByMouse: true
                                enabled: loginDialog.isAuthenticated
                                text: {
                                    var _refresh = root.tableRefreshToken
                                    var v = excelHandler.model.getData(r, c)
                                    return v === null || v === undefined ? "" : v.toString()
                                }
                                color: enabled ? "black" : "#95a5a6"
                                font.pixelSize: 12
                                onEditingFinished: {
                                    if (enabled) excelHandler.model.setDataAt(r, c, text)
                                }
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
        statusLabel.text = excelHandler.isDatabaseConnected()
                ? "Ready - stock loaded from database"
                : "Warning: database not connected"

        statusTimer.restart()
        console.log("System initialized")
        console.log("========================================")
    }
}
