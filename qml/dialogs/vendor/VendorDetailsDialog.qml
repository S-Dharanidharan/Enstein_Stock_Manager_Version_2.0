import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ExcelHandler 1.0
import Enstein

// ===========================================================================
//  VendorDetailsDialog - edit one vendor
// ===========================================================================
//  A vendor is identified by name everywhere in the application, so the name it
//  had when the dialog opened is kept in originalName: that is what the backend
//  matches on, which is what makes renaming a vendor possible at all.
// ===========================================================================
Dialog {
    // Raised for Main.qml to act on: this dialog cannot see its
    // siblings, so anything involving another screen goes out as a signal.
    signal vendorChanged()
    signal dropdownsStale()

    title: "Vendor Details"
    modal: true
    anchors.centerIn: parent
    standardButtons: Dialog.Ok | Dialog.Cancel
    // Wide enough for three field pairs per row, and never taller than
    // the window: the fields scroll inside rather than pushing the OK
    // and Cancel buttons off the bottom edge.
    width: Math.min(App.windowWidth - 120, 1100)
    height: Math.min(App.windowHeight - 120, 540)

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
            originalName: originalName,
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

        if (Backend.updateVendorDetails(vendorDetails)) {
            vendorChanged()
            dropdownsStale()
        }
    }

    function showVendor(vendor) {
        originalName = vendor.name || ""
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
    property string originalName: ""
}
