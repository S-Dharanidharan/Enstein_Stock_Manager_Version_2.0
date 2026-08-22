import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ExcelHandler 1.0
import Enstein

// ===========================================================================
//  VendorMasterDialog - who we buy from
// ===========================================================================
//  Add a vendor, search the list, open one to edit it. The list is filtered as
//  you type rather than on a button press, because with a few hundred vendors
//  that is faster than deciding what to search for.
//
//  The entry form sizes itself from its fields, so adding a field later cannot
//  push the Add button off the bottom edge - which is exactly what had
//  happened when the form was pinned to a fixed height.
// ===========================================================================
Dialog {
    // Raised for Main.qml to act on: this dialog cannot see its siblings,
    // so anything that involves another screen leaves as a signal.
    signal dropdownsStale()
    signal vendorActivated(var vendor)

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

        Label { text: "Vendor Master"; font.bold: true; font.pixelSize: 16; color: Theme.textPrimary }  

        // Add Vendor Form
        Rectangle {
            Layout.fillWidth: true
            // Height follows the form rather than a fixed 250, which the
            // thirteen fields had already outgrown - the last row and the
            // Add button were being cut off at the bottom edge.
            Layout.preferredHeight: vendorEntryGrid.implicitHeight + 20
            color: Theme.surfaceAlt; border.color: Theme.border; radius: 5

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

                        if (Backend.addVendorDetails(vendorDetails)) {
                            refresh()
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
                onTextChanged: refresh(text)
            }
            Button {
                id: vendorSearchButton
                text: "Search"
                onClicked: refresh(vendorSearchField.text)
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            border.color: Theme.border; radius: 5

            ListView {
                id: vendorListView; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 4
                model: ListModel { id: vendorListModel }
                delegate: Rectangle {
                    width: vendorListView.width - 10; height: 50
                    color: "#fff"; border.color: Theme.borderSubtle; radius: 4
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
                                    font.pixelSize: 11; color: Theme.textSecondary
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    vendorActivated({
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
                            contentItem: Text { text: "Delete"; color: Theme.danger; font.pixelSize: 11 }
                            onClicked: {
                                Backend.deleteVendor(model.name)
                                refresh()
                                refreshVendorDropdowns()
                            }
                        }
                    }

                    // Mouse handling moved to vendorInfoArea to avoid blocking the Delete button.
                }
            }

            Label { anchors.centerIn: parent; text: "No vendors added"; visible: vendorListModel.count === 0; color: Theme.textMuted }
        }

        Button { text: "Close"; Layout.alignment: Qt.AlignRight; onClicked: vendorDialog.close() }
    }

    onOpened: {
        refresh()
        refreshVendorDropdowns()
    }

    // Called with no argument to re-apply whatever filter is currently
    // typed, which is what the backend's change signals want: refresh the
    // list without throwing away what the user was searching for.
    function refresh(filterText) {
        if (filterText === undefined) filterText = vendorSearchField.text
        vendorListModel.clear()
        var query = (filterText || "").toString().trim().toLowerCase()
        var vendors = Backend.getVendorList()
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
}
