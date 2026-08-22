import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ExcelHandler 1.0
import Enstein

// ===========================================================================
//  CompanyProfileDialog - our own details
// ===========================================================================
//  Name, address, GSTIN and contact details, printed as the letterhead on every
//  purchase order and delivery challan.
// ===========================================================================
Dialog {
    title: "Company Profile"
    modal: true
    anchors.centerIn: parent
    standardButtons: Dialog.Save | Dialog.Cancel
    width: 560

    // These details head every printed purchase order, so they are worth
    // filling in once before sending anything to a vendor.
    onOpened: {
        var c = Backend.getCompanyProfile()
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
        Backend.saveCompanyProfile({
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
