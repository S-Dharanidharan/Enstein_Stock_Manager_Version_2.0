/****************************************************************************
** Meta object code from reading C++ file 'excelhandler.h'
**
** Created by: The Qt Meta Object Compiler version 68 (Qt 6.4.2)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include <memory>
#include "../../../excelhandler.h"
#include <QtCore/qmetatype.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'excelhandler.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 68
#error "This file was generated using the moc from 6.4.2. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_BEGIN_MOC_NAMESPACE
QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
namespace {
struct qt_meta_stringdata_ExcelTableModel_t {
    uint offsetsAndSizes[22];
    char stringdata0[16];
    char stringdata1[8];
    char stringdata2[1];
    char stringdata3[4];
    char stringdata4[7];
    char stringdata5[10];
    char stringdata6[6];
    char stringdata7[7];
    char stringdata8[12];
    char stringdata9[10];
    char stringdata10[6];
};
#define QT_MOC_LITERAL(ofs, len) \
    uint(sizeof(qt_meta_stringdata_ExcelTableModel_t::offsetsAndSizes) + ofs), len 
Q_CONSTINIT static const qt_meta_stringdata_ExcelTableModel_t qt_meta_stringdata_ExcelTableModel = {
    {
        QT_MOC_LITERAL(0, 15),  // "ExcelTableModel"
        QT_MOC_LITERAL(16, 7),  // "getData"
        QT_MOC_LITERAL(24, 0),  // ""
        QT_MOC_LITERAL(25, 3),  // "row"
        QT_MOC_LITERAL(29, 6),  // "column"
        QT_MOC_LITERAL(36, 9),  // "setDataAt"
        QT_MOC_LITERAL(46, 5),  // "value"
        QT_MOC_LITERAL(52, 6),  // "addRow"
        QT_MOC_LITERAL(59, 11),  // "removeRowAt"
        QT_MOC_LITERAL(71, 9),  // "addColumn"
        QT_MOC_LITERAL(81, 5)   // "clear"
    },
    "ExcelTableModel",
    "getData",
    "",
    "row",
    "column",
    "setDataAt",
    "value",
    "addRow",
    "removeRowAt",
    "addColumn",
    "clear"
};
#undef QT_MOC_LITERAL
} // unnamed namespace

Q_CONSTINIT static const uint qt_meta_data_ExcelTableModel[] = {

 // content:
      10,       // revision
       0,       // classname
       0,    0, // classinfo
       6,   14, // methods
       0,    0, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
       0,       // signalCount

 // methods: name, argc, parameters, tag, flags, initial metatype offsets
       1,    2,   50,    2, 0x102,    1 /* Public | MethodIsConst  */,
       5,    3,   55,    2, 0x02,    4 /* Public */,
       7,    0,   62,    2, 0x02,    8 /* Public */,
       8,    1,   63,    2, 0x02,    9 /* Public */,
       9,    0,   66,    2, 0x02,   11 /* Public */,
      10,    0,   67,    2, 0x02,   12 /* Public */,

 // methods: parameters
    QMetaType::QVariant, QMetaType::Int, QMetaType::Int,    3,    4,
    QMetaType::Bool, QMetaType::Int, QMetaType::Int, QMetaType::QVariant,    3,    4,    6,
    QMetaType::Void,
    QMetaType::Bool, QMetaType::Int,    3,
    QMetaType::Void,
    QMetaType::Void,

       0        // eod
};

Q_CONSTINIT const QMetaObject ExcelTableModel::staticMetaObject = { {
    QMetaObject::SuperData::link<QAbstractTableModel::staticMetaObject>(),
    qt_meta_stringdata_ExcelTableModel.offsetsAndSizes,
    qt_meta_data_ExcelTableModel,
    qt_static_metacall,
    nullptr,
    qt_incomplete_metaTypeArray<qt_meta_stringdata_ExcelTableModel_t,
        // Q_OBJECT / Q_GADGET
        QtPrivate::TypeAndForceComplete<ExcelTableModel, std::true_type>,
        // method 'getData'
        QtPrivate::TypeAndForceComplete<QVariant, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'setDataAt'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QVariant &, std::false_type>,
        // method 'addRow'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'removeRowAt'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'addColumn'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'clear'
        QtPrivate::TypeAndForceComplete<void, std::false_type>
    >,
    nullptr
} };

void ExcelTableModel::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    if (_c == QMetaObject::InvokeMetaMethod) {
        auto *_t = static_cast<ExcelTableModel *>(_o);
        (void)_t;
        switch (_id) {
        case 0: { QVariant _r = _t->getData((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[2])));
            if (_a[0]) *reinterpret_cast< QVariant*>(_a[0]) = std::move(_r); }  break;
        case 1: { bool _r = _t->setDataAt((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<QVariant>>(_a[3])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 2: _t->addRow(); break;
        case 3: { bool _r = _t->removeRowAt((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 4: _t->addColumn(); break;
        case 5: _t->clear(); break;
        default: ;
        }
    }
}

const QMetaObject *ExcelTableModel::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *ExcelTableModel::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_meta_stringdata_ExcelTableModel.stringdata0))
        return static_cast<void*>(this);
    return QAbstractTableModel::qt_metacast(_clname);
}

int ExcelTableModel::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QAbstractTableModel::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 6)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    } else if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 6)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 6;
    }
    return _id;
}
namespace {
struct qt_meta_stringdata_ExcelHandler_t {
    uint offsetsAndSizes[308];
    char stringdata0[13];
    char stringdata1[19];
    char stringdata2[1];
    char stringdata3[22];
    char stringdata4[21];
    char stringdata5[14];
    char stringdata6[6];
    char stringdata7[11];
    char stringdata8[9];
    char stringdata9[10];
    char stringdata10[11];
    char stringdata11[10];
    char stringdata12[12];
    char stringdata13[18];
    char stringdata14[4];
    char stringdata15[19];
    char stringdata16[19];
    char stringdata17[20];
    char stringdata18[18];
    char stringdata19[19];
    char stringdata20[16];
    char stringdata21[14];
    char stringdata22[8];
    char stringdata23[17];
    char stringdata24[8];
    char stringdata25[21];
    char stringdata26[22];
    char stringdata27[18];
    char stringdata28[22];
    char stringdata29[21];
    char stringdata30[5];
    char stringdata31[14];
    char stringdata32[6];
    char stringdata33[12];
    char stringdata34[8];
    char stringdata35[9];
    char stringdata36[4];
    char stringdata37[15];
    char stringdata38[5];
    char stringdata39[19];
    char stringdata40[18];
    char stringdata41[18];
    char stringdata42[10];
    char stringdata43[5];
    char stringdata44[5];
    char stringdata45[16];
    char stringdata46[19];
    char stringdata47[12];
    char stringdata48[12];
    char stringdata49[10];
    char stringdata50[9];
    char stringdata51[10];
    char stringdata52[17];
    char stringdata53[18];
    char stringdata54[16];
    char stringdata55[22];
    char stringdata56[22];
    char stringdata57[15];
    char stringdata58[16];
    char stringdata59[22];
    char stringdata60[15];
    char stringdata61[6];
    char stringdata62[7];
    char stringdata63[15];
    char stringdata64[13];
    char stringdata65[13];
    char stringdata66[9];
    char stringdata67[7];
    char stringdata68[15];
    char stringdata69[17];
    char stringdata70[11];
    char stringdata71[18];
    char stringdata72[20];
    char stringdata73[17];
    char stringdata74[16];
    char stringdata75[11];
    char stringdata76[9];
    char stringdata77[9];
    char stringdata78[10];
    char stringdata79[20];
    char stringdata80[12];
    char stringdata81[14];
    char stringdata82[16];
    char stringdata83[17];
    char stringdata84[8];
    char stringdata85[15];
    char stringdata86[7];
    char stringdata87[15];
    char stringdata88[9];
    char stringdata89[12];
    char stringdata90[5];
    char stringdata91[15];
    char stringdata92[8];
    char stringdata93[17];
    char stringdata94[7];
    char stringdata95[20];
    char stringdata96[13];
    char stringdata97[5];
    char stringdata98[14];
    char stringdata99[15];
    char stringdata100[16];
    char stringdata101[21];
    char stringdata102[12];
    char stringdata103[24];
    char stringdata104[18];
    char stringdata105[11];
    char stringdata106[20];
    char stringdata107[7];
    char stringdata108[13];
    char stringdata109[11];
    char stringdata110[11];
    char stringdata111[18];
    char stringdata112[11];
    char stringdata113[10];
    char stringdata114[13];
    char stringdata115[15];
    char stringdata116[10];
    char stringdata117[20];
    char stringdata118[10];
    char stringdata119[14];
    char stringdata120[16];
    char stringdata121[13];
    char stringdata122[12];
    char stringdata123[12];
    char stringdata124[12];
    char stringdata125[8];
    char stringdata126[11];
    char stringdata127[11];
    char stringdata128[17];
    char stringdata129[13];
    char stringdata130[10];
    char stringdata131[7];
    char stringdata132[18];
    char stringdata133[15];
    char stringdata134[16];
    char stringdata135[11];
    char stringdata136[9];
    char stringdata137[14];
    char stringdata138[17];
    char stringdata139[14];
    char stringdata140[26];
    char stringdata141[6];
    char stringdata142[17];
    char stringdata143[12];
    char stringdata144[18];
    char stringdata145[14];
    char stringdata146[12];
    char stringdata147[12];
    char stringdata148[13];
    char stringdata149[11];
    char stringdata150[12];
    char stringdata151[9];
    char stringdata152[15];
    char stringdata153[13];
};
#define QT_MOC_LITERAL(ofs, len) \
    uint(sizeof(qt_meta_stringdata_ExcelHandler_t::offsetsAndSizes) + ofs), len 
Q_CONSTINIT static const qt_meta_stringdata_ExcelHandler_t qt_meta_stringdata_ExcelHandler = {
    {
        QT_MOC_LITERAL(0, 12),  // "ExcelHandler"
        QT_MOC_LITERAL(13, 18),  // "currentFileChanged"
        QT_MOC_LITERAL(32, 0),  // ""
        QT_MOC_LITERAL(33, 21),  // "unsavedChangesChanged"
        QT_MOC_LITERAL(55, 20),  // "permanentFileChanged"
        QT_MOC_LITERAL(76, 13),  // "errorOccurred"
        QT_MOC_LITERAL(90, 5),  // "error"
        QT_MOC_LITERAL(96, 10),  // "fileLoaded"
        QT_MOC_LITERAL(107, 8),  // "fileName"
        QT_MOC_LITERAL(116, 9),  // "fileSaved"
        QT_MOC_LITERAL(126, 10),  // "fileMerged"
        QT_MOC_LITERAL(137, 9),  // "rowsAdded"
        QT_MOC_LITERAL(147, 11),  // "rowsUpdated"
        QT_MOC_LITERAL(159, 17),  // "searchResultFound"
        QT_MOC_LITERAL(177, 3),  // "row"
        QT_MOC_LITERAL(181, 18),  // "cloudFolderChanged"
        QT_MOC_LITERAL(200, 18),  // "syncEnabledChanged"
        QT_MOC_LITERAL(219, 19),  // "lastSyncTimeChanged"
        QT_MOC_LITERAL(239, 17),  // "syncStatusChanged"
        QT_MOC_LITERAL(257, 18),  // "currentUserChanged"
        QT_MOC_LITERAL(276, 15),  // "userRoleChanged"
        QT_MOC_LITERAL(292, 13),  // "syncCompleted"
        QT_MOC_LITERAL(306, 7),  // "success"
        QT_MOC_LITERAL(314, 16),  // "conflictDetected"
        QT_MOC_LITERAL(331, 7),  // "message"
        QT_MOC_LITERAL(339, 20),  // "lowStockCountChanged"
        QT_MOC_LITERAL(360, 21),  // "pendingPOCountChanged"
        QT_MOC_LITERAL(382, 17),  // "vendorListChanged"
        QT_MOC_LITERAL(400, 21),  // "itemMasterListChanged"
        QT_MOC_LITERAL(422, 20),  // "purchaseOrderCreated"
        QT_MOC_LITERAL(443, 4),  // "poNo"
        QT_MOC_LITERAL(448, 13),  // "goodsReceived"
        QT_MOC_LITERAL(462, 5),  // "grnNo"
        QT_MOC_LITERAL(468, 11),  // "stockIssued"
        QT_MOC_LITERAL(480, 7),  // "issueNo"
        QT_MOC_LITERAL(488, 8),  // "partName"
        QT_MOC_LITERAL(497, 3),  // "qty"
        QT_MOC_LITERAL(501, 14),  // "movementLogged"
        QT_MOC_LITERAL(516, 4),  // "type"
        QT_MOC_LITERAL(521, 18),  // "onModelDataChanged"
        QT_MOC_LITERAL(540, 17),  // "autoSavePermanent"
        QT_MOC_LITERAL(558, 17),  // "autoSyncFromCloud"
        QT_MOC_LITERAL(576, 9),  // "createNew"
        QT_MOC_LITERAL(586, 4),  // "rows"
        QT_MOC_LITERAL(591, 4),  // "cols"
        QT_MOC_LITERAL(596, 15),  // "createStockFile"
        QT_MOC_LITERAL(612, 18),  // "createPurchaseFile"
        QT_MOC_LITERAL(631, 11),  // "getFileName"
        QT_MOC_LITERAL(643, 11),  // "getFileType"
        QT_MOC_LITERAL(655, 9),  // "loadExcel"
        QT_MOC_LITERAL(665, 8),  // "filePath"
        QT_MOC_LITERAL(674, 9),  // "saveExcel"
        QT_MOC_LITERAL(684, 16),  // "setPermanentFile"
        QT_MOC_LITERAL(701, 17),  // "loadPermanentFile"
        QT_MOC_LITERAL(719, 15),  // "saveToPermanent"
        QT_MOC_LITERAL(735, 21),  // "getSavedPermanentPath"
        QT_MOC_LITERAL(757, 21),  // "hasSavedPermanentFile"
        QT_MOC_LITERAL(779, 14),  // "appendFromFile"
        QT_MOC_LITERAL(794, 15),  // "appendStockFile"
        QT_MOC_LITERAL(810, 21),  // "validateFileStructure"
        QT_MOC_LITERAL(832, 14),  // "browseOpenFile"
        QT_MOC_LITERAL(847, 5),  // "title"
        QT_MOC_LITERAL(853, 6),  // "filter"
        QT_MOC_LITERAL(860, 14),  // "browseSaveFile"
        QT_MOC_LITERAL(875, 12),  // "browseFolder"
        QT_MOC_LITERAL(888, 12),  // "exportReport"
        QT_MOC_LITERAL(901, 8),  // "fromDate"
        QT_MOC_LITERAL(910, 6),  // "toDate"
        QT_MOC_LITERAL(917, 14),  // "searchPartName"
        QT_MOC_LITERAL(932, 16),  // "searchAllMatches"
        QT_MOC_LITERAL(949, 10),  // "searchText"
        QT_MOC_LITERAL(960, 17),  // "uploadFileForPart"
        QT_MOC_LITERAL(978, 19),  // "getUploadedFilePath"
        QT_MOC_LITERAL(998, 16),  // "openUploadedFile"
        QT_MOC_LITERAL(1015, 15),  // "hasUploadedFile"
        QT_MOC_LITERAL(1031, 10),  // "addNewItem"
        QT_MOC_LITERAL(1042, 8),  // "category"
        QT_MOC_LITERAL(1051, 8),  // "quantity"
        QT_MOC_LITERAL(1060, 9),  // "unitPrice"
        QT_MOC_LITERAL(1070, 19),  // "getNextSerialNumber"
        QT_MOC_LITERAL(1090, 11),  // "syncToCloud"
        QT_MOC_LITERAL(1102, 13),  // "syncFromCloud"
        QT_MOC_LITERAL(1116, 15),  // "checkForUpdates"
        QT_MOC_LITERAL(1132, 16),  // "getCloudFilePath"
        QT_MOC_LITERAL(1149, 7),  // "canEdit"
        QT_MOC_LITERAL(1157, 14),  // "setCloudFolder"
        QT_MOC_LITERAL(1172, 6),  // "folder"
        QT_MOC_LITERAL(1179, 14),  // "setCurrentUser"
        QT_MOC_LITERAL(1194, 8),  // "username"
        QT_MOC_LITERAL(1203, 11),  // "setUserRole"
        QT_MOC_LITERAL(1215, 4),  // "role"
        QT_MOC_LITERAL(1220, 14),  // "setSyncEnabled"
        QT_MOC_LITERAL(1235, 7),  // "enabled"
        QT_MOC_LITERAL(1243, 16),  // "addVendorDetails"
        QT_MOC_LITERAL(1260, 6),  // "vendor"
        QT_MOC_LITERAL(1267, 19),  // "updateVendorDetails"
        QT_MOC_LITERAL(1287, 12),  // "deleteVendor"
        QT_MOC_LITERAL(1300, 4),  // "name"
        QT_MOC_LITERAL(1305, 13),  // "getVendorList"
        QT_MOC_LITERAL(1319, 14),  // "getVendorNames"
        QT_MOC_LITERAL(1334, 15),  // "getVendorByName"
        QT_MOC_LITERAL(1350, 20),  // "addItemMasterDetails"
        QT_MOC_LITERAL(1371, 11),  // "itemDetails"
        QT_MOC_LITERAL(1383, 23),  // "updateItemMasterDetails"
        QT_MOC_LITERAL(1407, 17),  // "getItemMasterList"
        QT_MOC_LITERAL(1425, 10),  // "deleteItem"
        QT_MOC_LITERAL(1436, 19),  // "createPurchaseOrder"
        QT_MOC_LITERAL(1456, 6),  // "partNo"
        QT_MOC_LITERAL(1463, 12),  // "expectedDate"
        QT_MOC_LITERAL(1476, 10),  // "department"
        QT_MOC_LITERAL(1487, 10),  // "preparedBy"
        QT_MOC_LITERAL(1498, 17),  // "sendPOForApproval"
        QT_MOC_LITERAL(1516, 10),  // "approvedBy"
        QT_MOC_LITERAL(1527, 9),  // "getPOList"
        QT_MOC_LITERAL(1537, 12),  // "statusFilter"
        QT_MOC_LITERAL(1550, 14),  // "updatePOStatus"
        QT_MOC_LITERAL(1565, 9),  // "newStatus"
        QT_MOC_LITERAL(1575, 19),  // "updatePurchaseOrder"
        QT_MOC_LITERAL(1595, 9),  // "poDetails"
        QT_MOC_LITERAL(1605, 13),  // "getPOByNumber"
        QT_MOC_LITERAL(1619, 15),  // "getNextPONumber"
        QT_MOC_LITERAL(1635, 12),  // "receiveGoods"
        QT_MOC_LITERAL(1648, 11),  // "receivedQty"
        QT_MOC_LITERAL(1660, 11),  // "acceptedQty"
        QT_MOC_LITERAL(1672, 11),  // "rejectedQty"
        QT_MOC_LITERAL(1684, 7),  // "remarks"
        QT_MOC_LITERAL(1692, 10),  // "receivedBy"
        QT_MOC_LITERAL(1703, 10),  // "getGRNList"
        QT_MOC_LITERAL(1714, 16),  // "logStockMovement"
        QT_MOC_LITERAL(1731, 12),  // "movementType"
        QT_MOC_LITERAL(1744, 9),  // "reference"
        QT_MOC_LITERAL(1754, 6),  // "doneBy"
        QT_MOC_LITERAL(1761, 17),  // "getStockMovements"
        QT_MOC_LITERAL(1779, 14),  // "partNameFilter"
        QT_MOC_LITERAL(1794, 15),  // "getAllMovements"
        QT_MOC_LITERAL(1810, 10),  // "issueStock"
        QT_MOC_LITERAL(1821, 8),  // "issuedBy"
        QT_MOC_LITERAL(1830, 13),  // "getIssueNotes"
        QT_MOC_LITERAL(1844, 16),  // "getLowStockItems"
        QT_MOC_LITERAL(1861, 13),  // "lowStockCount"
        QT_MOC_LITERAL(1875, 25),  // "autoGeneratePOForLowStock"
        QT_MOC_LITERAL(1901, 5),  // "model"
        QT_MOC_LITERAL(1907, 16),  // "ExcelTableModel*"
        QT_MOC_LITERAL(1924, 11),  // "currentFile"
        QT_MOC_LITERAL(1936, 17),  // "hasUnsavedChanges"
        QT_MOC_LITERAL(1954, 13),  // "permanentFile"
        QT_MOC_LITERAL(1968, 11),  // "cloudFolder"
        QT_MOC_LITERAL(1980, 11),  // "syncEnabled"
        QT_MOC_LITERAL(1992, 12),  // "lastSyncTime"
        QT_MOC_LITERAL(2005, 10),  // "syncStatus"
        QT_MOC_LITERAL(2016, 11),  // "currentUser"
        QT_MOC_LITERAL(2028, 8),  // "userRole"
        QT_MOC_LITERAL(2037, 14),  // "pendingPOCount"
        QT_MOC_LITERAL(2052, 12)   // "totalVendors"
    },
    "ExcelHandler",
    "currentFileChanged",
    "",
    "unsavedChangesChanged",
    "permanentFileChanged",
    "errorOccurred",
    "error",
    "fileLoaded",
    "fileName",
    "fileSaved",
    "fileMerged",
    "rowsAdded",
    "rowsUpdated",
    "searchResultFound",
    "row",
    "cloudFolderChanged",
    "syncEnabledChanged",
    "lastSyncTimeChanged",
    "syncStatusChanged",
    "currentUserChanged",
    "userRoleChanged",
    "syncCompleted",
    "success",
    "conflictDetected",
    "message",
    "lowStockCountChanged",
    "pendingPOCountChanged",
    "vendorListChanged",
    "itemMasterListChanged",
    "purchaseOrderCreated",
    "poNo",
    "goodsReceived",
    "grnNo",
    "stockIssued",
    "issueNo",
    "partName",
    "qty",
    "movementLogged",
    "type",
    "onModelDataChanged",
    "autoSavePermanent",
    "autoSyncFromCloud",
    "createNew",
    "rows",
    "cols",
    "createStockFile",
    "createPurchaseFile",
    "getFileName",
    "getFileType",
    "loadExcel",
    "filePath",
    "saveExcel",
    "setPermanentFile",
    "loadPermanentFile",
    "saveToPermanent",
    "getSavedPermanentPath",
    "hasSavedPermanentFile",
    "appendFromFile",
    "appendStockFile",
    "validateFileStructure",
    "browseOpenFile",
    "title",
    "filter",
    "browseSaveFile",
    "browseFolder",
    "exportReport",
    "fromDate",
    "toDate",
    "searchPartName",
    "searchAllMatches",
    "searchText",
    "uploadFileForPart",
    "getUploadedFilePath",
    "openUploadedFile",
    "hasUploadedFile",
    "addNewItem",
    "category",
    "quantity",
    "unitPrice",
    "getNextSerialNumber",
    "syncToCloud",
    "syncFromCloud",
    "checkForUpdates",
    "getCloudFilePath",
    "canEdit",
    "setCloudFolder",
    "folder",
    "setCurrentUser",
    "username",
    "setUserRole",
    "role",
    "setSyncEnabled",
    "enabled",
    "addVendorDetails",
    "vendor",
    "updateVendorDetails",
    "deleteVendor",
    "name",
    "getVendorList",
    "getVendorNames",
    "getVendorByName",
    "addItemMasterDetails",
    "itemDetails",
    "updateItemMasterDetails",
    "getItemMasterList",
    "deleteItem",
    "createPurchaseOrder",
    "partNo",
    "expectedDate",
    "department",
    "preparedBy",
    "sendPOForApproval",
    "approvedBy",
    "getPOList",
    "statusFilter",
    "updatePOStatus",
    "newStatus",
    "updatePurchaseOrder",
    "poDetails",
    "getPOByNumber",
    "getNextPONumber",
    "receiveGoods",
    "receivedQty",
    "acceptedQty",
    "rejectedQty",
    "remarks",
    "receivedBy",
    "getGRNList",
    "logStockMovement",
    "movementType",
    "reference",
    "doneBy",
    "getStockMovements",
    "partNameFilter",
    "getAllMovements",
    "issueStock",
    "issuedBy",
    "getIssueNotes",
    "getLowStockItems",
    "lowStockCount",
    "autoGeneratePOForLowStock",
    "model",
    "ExcelTableModel*",
    "currentFile",
    "hasUnsavedChanges",
    "permanentFile",
    "cloudFolder",
    "syncEnabled",
    "lastSyncTime",
    "syncStatus",
    "currentUser",
    "userRole",
    "pendingPOCount",
    "totalVendors"
};
#undef QT_MOC_LITERAL
} // unnamed namespace

Q_CONSTINIT static const uint qt_meta_data_ExcelHandler[] = {

 // content:
      10,       // revision
       0,       // classname
       0,    0, // classinfo
     100,   14, // methods
      13,  934, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
      24,       // signalCount

 // signals: name, argc, parameters, tag, flags, initial metatype offsets
       1,    0,  614,    2, 0x06,   14 /* Public */,
       3,    0,  615,    2, 0x06,   15 /* Public */,
       4,    0,  616,    2, 0x06,   16 /* Public */,
       5,    1,  617,    2, 0x06,   17 /* Public */,
       7,    1,  620,    2, 0x06,   19 /* Public */,
       9,    1,  623,    2, 0x06,   21 /* Public */,
      10,    3,  626,    2, 0x06,   23 /* Public */,
      13,    1,  633,    2, 0x06,   27 /* Public */,
      15,    0,  636,    2, 0x06,   29 /* Public */,
      16,    0,  637,    2, 0x06,   30 /* Public */,
      17,    0,  638,    2, 0x06,   31 /* Public */,
      18,    0,  639,    2, 0x06,   32 /* Public */,
      19,    0,  640,    2, 0x06,   33 /* Public */,
      20,    0,  641,    2, 0x06,   34 /* Public */,
      21,    1,  642,    2, 0x06,   35 /* Public */,
      23,    1,  645,    2, 0x06,   37 /* Public */,
      25,    0,  648,    2, 0x06,   39 /* Public */,
      26,    0,  649,    2, 0x06,   40 /* Public */,
      27,    0,  650,    2, 0x06,   41 /* Public */,
      28,    0,  651,    2, 0x06,   42 /* Public */,
      29,    1,  652,    2, 0x06,   43 /* Public */,
      31,    2,  655,    2, 0x06,   45 /* Public */,
      33,    3,  660,    2, 0x06,   48 /* Public */,
      37,    3,  667,    2, 0x06,   52 /* Public */,

 // slots: name, argc, parameters, tag, flags, initial metatype offsets
      39,    0,  674,    2, 0x08,   56 /* Private */,
      40,    0,  675,    2, 0x08,   57 /* Private */,
      41,    0,  676,    2, 0x08,   58 /* Private */,

 // methods: name, argc, parameters, tag, flags, initial metatype offsets
      42,    2,  677,    2, 0x02,   59 /* Public */,
      42,    1,  682,    2, 0x22,   62 /* Public | MethodCloned */,
      42,    0,  685,    2, 0x22,   64 /* Public | MethodCloned */,
      45,    1,  686,    2, 0x02,   65 /* Public */,
      45,    0,  689,    2, 0x22,   67 /* Public | MethodCloned */,
      46,    1,  690,    2, 0x02,   68 /* Public */,
      46,    0,  693,    2, 0x22,   70 /* Public | MethodCloned */,
      47,    0,  694,    2, 0x102,   71 /* Public | MethodIsConst  */,
      48,    0,  695,    2, 0x102,   72 /* Public | MethodIsConst  */,
      49,    1,  696,    2, 0x02,   73 /* Public */,
      51,    1,  699,    2, 0x02,   75 /* Public */,
      51,    0,  702,    2, 0x22,   77 /* Public | MethodCloned */,
      52,    1,  703,    2, 0x02,   78 /* Public */,
      53,    0,  706,    2, 0x02,   80 /* Public */,
      54,    0,  707,    2, 0x02,   81 /* Public */,
      55,    0,  708,    2, 0x02,   82 /* Public */,
      56,    0,  709,    2, 0x02,   83 /* Public */,
      57,    1,  710,    2, 0x02,   84 /* Public */,
      58,    1,  713,    2, 0x02,   86 /* Public */,
      59,    1,  716,    2, 0x02,   88 /* Public */,
      60,    2,  719,    2, 0x02,   90 /* Public */,
      63,    2,  724,    2, 0x02,   93 /* Public */,
      64,    1,  729,    2, 0x02,   96 /* Public */,
      65,    3,  732,    2, 0x02,   98 /* Public */,
      68,    1,  739,    2, 0x02,  102 /* Public */,
      69,    1,  742,    2, 0x02,  104 /* Public */,
      71,    2,  745,    2, 0x02,  106 /* Public */,
      72,    1,  750,    2, 0x02,  109 /* Public */,
      73,    1,  753,    2, 0x02,  111 /* Public */,
      74,    1,  756,    2, 0x02,  113 /* Public */,
      75,    4,  759,    2, 0x02,  115 /* Public */,
      79,    0,  768,    2, 0x102,  120 /* Public | MethodIsConst  */,
      80,    0,  769,    2, 0x02,  121 /* Public */,
      81,    0,  770,    2, 0x02,  122 /* Public */,
      82,    0,  771,    2, 0x02,  123 /* Public */,
      83,    0,  772,    2, 0x102,  124 /* Public | MethodIsConst  */,
      84,    0,  773,    2, 0x102,  125 /* Public | MethodIsConst  */,
      85,    1,  774,    2, 0x02,  126 /* Public */,
      87,    1,  777,    2, 0x02,  128 /* Public */,
      89,    1,  780,    2, 0x02,  130 /* Public */,
      91,    1,  783,    2, 0x02,  132 /* Public */,
      93,    1,  786,    2, 0x02,  134 /* Public */,
      95,    1,  789,    2, 0x02,  136 /* Public */,
      96,    1,  792,    2, 0x02,  138 /* Public */,
      98,    0,  795,    2, 0x02,  140 /* Public */,
      99,    0,  796,    2, 0x02,  141 /* Public */,
     100,    1,  797,    2, 0x02,  142 /* Public */,
     101,    1,  800,    2, 0x02,  144 /* Public */,
     103,    1,  803,    2, 0x02,  146 /* Public */,
     104,    0,  806,    2, 0x02,  148 /* Public */,
     105,    1,  807,    2, 0x02,  149 /* Public */,
     106,    8,  810,    2, 0x02,  151 /* Public */,
     106,    7,  827,    2, 0x22,  160 /* Public | MethodCloned */,
     106,    6,  842,    2, 0x22,  168 /* Public | MethodCloned */,
     111,    2,  855,    2, 0x02,  175 /* Public */,
     113,    1,  860,    2, 0x02,  178 /* Public */,
     113,    0,  863,    2, 0x22,  180 /* Public | MethodCloned */,
     115,    2,  864,    2, 0x02,  181 /* Public */,
     117,    2,  869,    2, 0x02,  184 /* Public */,
     119,    1,  874,    2, 0x02,  187 /* Public */,
     120,    0,  877,    2, 0x02,  189 /* Public */,
     121,    6,  878,    2, 0x02,  190 /* Public */,
     121,    5,  891,    2, 0x22,  197 /* Public | MethodCloned */,
     127,    0,  902,    2, 0x02,  203 /* Public */,
     128,    6,  903,    2, 0x02,  204 /* Public */,
     132,    1,  916,    2, 0x02,  211 /* Public */,
     132,    0,  919,    2, 0x22,  213 /* Public | MethodCloned */,
     134,    0,  920,    2, 0x02,  214 /* Public */,
     135,    4,  921,    2, 0x02,  215 /* Public */,
     137,    0,  930,    2, 0x02,  220 /* Public */,
     138,    0,  931,    2, 0x02,  221 /* Public */,
     139,    0,  932,    2, 0x02,  222 /* Public */,
     140,    0,  933,    2, 0x02,  223 /* Public */,

 // signals: parameters
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void, QMetaType::QString,    6,
    QMetaType::Void, QMetaType::QString,    8,
    QMetaType::Void, QMetaType::QString,    8,
    QMetaType::Void, QMetaType::QString, QMetaType::Int, QMetaType::Int,    8,   11,   12,
    QMetaType::Void, QMetaType::Int,   14,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void, QMetaType::Bool,   22,
    QMetaType::Void, QMetaType::QString,   24,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void, QMetaType::QString,   30,
    QMetaType::Void, QMetaType::QString, QMetaType::QString,   32,   30,
    QMetaType::Void, QMetaType::QString, QMetaType::QString, QMetaType::Int,   34,   35,   36,
    QMetaType::Void, QMetaType::QString, QMetaType::QString, QMetaType::Int,   35,   38,   36,

 // slots: parameters
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,

 // methods: parameters
    QMetaType::Void, QMetaType::Int, QMetaType::Int,   43,   44,
    QMetaType::Void, QMetaType::Int,   43,
    QMetaType::Void,
    QMetaType::Void, QMetaType::Int,   43,
    QMetaType::Void,
    QMetaType::Void, QMetaType::Int,   43,
    QMetaType::Void,
    QMetaType::QString,
    QMetaType::QString,
    QMetaType::Bool, QMetaType::QString,   50,
    QMetaType::Bool, QMetaType::QString,   50,
    QMetaType::Bool,
    QMetaType::Bool, QMetaType::QString,   50,
    QMetaType::Bool,
    QMetaType::Bool,
    QMetaType::QString,
    QMetaType::Bool,
    QMetaType::Bool, QMetaType::QString,   50,
    QMetaType::Bool, QMetaType::QString,   50,
    QMetaType::Bool, QMetaType::QString,   50,
    QMetaType::QString, QMetaType::QString, QMetaType::QString,   61,   62,
    QMetaType::QString, QMetaType::QString, QMetaType::QString,   61,   62,
    QMetaType::QString, QMetaType::QString,   61,
    QMetaType::Bool, QMetaType::QString, QMetaType::QString, QMetaType::QString,   66,   67,   50,
    QMetaType::Int, QMetaType::QString,   35,
    QMetaType::QVariantList, QMetaType::QString,   70,
    QMetaType::Bool, QMetaType::Int, QMetaType::QString,   14,   50,
    QMetaType::QString, QMetaType::Int,   14,
    QMetaType::Bool, QMetaType::Int,   14,
    QMetaType::Bool, QMetaType::Int,   14,
    QMetaType::Void, QMetaType::QString, QMetaType::QString, QMetaType::Int, QMetaType::Double,   35,   76,   77,   78,
    QMetaType::Int,
    QMetaType::Bool,
    QMetaType::Bool,
    QMetaType::Bool,
    QMetaType::QString,
    QMetaType::Bool,
    QMetaType::Void, QMetaType::QString,   86,
    QMetaType::Void, QMetaType::QString,   88,
    QMetaType::Void, QMetaType::QString,   90,
    QMetaType::Void, QMetaType::Bool,   92,
    QMetaType::Bool, QMetaType::QVariantMap,   94,
    QMetaType::Bool, QMetaType::QVariantMap,   94,
    QMetaType::Bool, QMetaType::QString,   97,
    QMetaType::QVariantList,
    QMetaType::QStringList,
    QMetaType::QVariantMap, QMetaType::QString,   97,
    QMetaType::Bool, QMetaType::QVariantMap,  102,
    QMetaType::Bool, QMetaType::QVariantMap,  102,
    QMetaType::QVariantList,
    QMetaType::Bool, QMetaType::QString,   35,
    QMetaType::QString, QMetaType::QString, QMetaType::QString, QMetaType::QString, QMetaType::Int, QMetaType::Double, QMetaType::QString, QMetaType::QString, QMetaType::QString,   94,   35,  107,   36,   78,  108,  109,  110,
    QMetaType::QString, QMetaType::QString, QMetaType::QString, QMetaType::QString, QMetaType::Int, QMetaType::Double, QMetaType::QString, QMetaType::QString,   94,   35,  107,   36,   78,  108,  109,
    QMetaType::QString, QMetaType::QString, QMetaType::QString, QMetaType::QString, QMetaType::Int, QMetaType::Double, QMetaType::QString,   94,   35,  107,   36,   78,  108,
    QMetaType::Bool, QMetaType::QString, QMetaType::QString,   30,  112,
    QMetaType::QVariantList, QMetaType::QString,  114,
    QMetaType::QVariantList,
    QMetaType::Bool, QMetaType::QString, QMetaType::QString,   30,  116,
    QMetaType::Bool, QMetaType::QString, QMetaType::QVariantMap,   30,  118,
    QMetaType::QVariantMap, QMetaType::QString,   30,
    QMetaType::QString,
    QMetaType::QString, QMetaType::QString, QMetaType::Int, QMetaType::Int, QMetaType::Int, QMetaType::QString, QMetaType::QString,   30,  122,  123,  124,  125,  126,
    QMetaType::QString, QMetaType::QString, QMetaType::Int, QMetaType::Int, QMetaType::Int, QMetaType::QString,   30,  122,  123,  124,  125,
    QMetaType::QVariantList,
    QMetaType::Bool, QMetaType::QString, QMetaType::QString, QMetaType::QString, QMetaType::Int, QMetaType::QString, QMetaType::QString,   35,  107,  129,   36,  130,  131,
    QMetaType::QVariantList, QMetaType::QString,  133,
    QMetaType::QVariantList,
    QMetaType::QVariantList,
    QMetaType::QString, QMetaType::QString, QMetaType::Int, QMetaType::QString, QMetaType::QString,   35,   36,  109,  136,
    QMetaType::QVariantList,
    QMetaType::QVariantList,
    QMetaType::Int,
    QMetaType::Bool,

 // properties: name, type, flags
     141, 0x80000000 | 142, 0x00015409, uint(-1), 0,
     143, QMetaType::QString, 0x00015001, uint(0), 0,
     144, QMetaType::Bool, 0x00015001, uint(1), 0,
     145, QMetaType::QString, 0x00015001, uint(2), 0,
     146, QMetaType::QString, 0x00015103, uint(8), 0,
     147, QMetaType::Bool, 0x00015103, uint(9), 0,
     148, QMetaType::QString, 0x00015001, uint(10), 0,
     149, QMetaType::QString, 0x00015001, uint(11), 0,
     150, QMetaType::QString, 0x00015103, uint(12), 0,
     151, QMetaType::QString, 0x00015103, uint(13), 0,
     139, QMetaType::Int, 0x00015001, uint(16), 0,
     152, QMetaType::Int, 0x00015001, uint(17), 0,
     153, QMetaType::Int, 0x00015001, uint(18), 0,

       0        // eod
};

Q_CONSTINIT const QMetaObject ExcelHandler::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_meta_stringdata_ExcelHandler.offsetsAndSizes,
    qt_meta_data_ExcelHandler,
    qt_static_metacall,
    nullptr,
    qt_incomplete_metaTypeArray<qt_meta_stringdata_ExcelHandler_t,
        // property 'model'
        QtPrivate::TypeAndForceComplete<ExcelTableModel*, std::true_type>,
        // property 'currentFile'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'hasUnsavedChanges'
        QtPrivate::TypeAndForceComplete<bool, std::true_type>,
        // property 'permanentFile'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'cloudFolder'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'syncEnabled'
        QtPrivate::TypeAndForceComplete<bool, std::true_type>,
        // property 'lastSyncTime'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'syncStatus'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'currentUser'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'userRole'
        QtPrivate::TypeAndForceComplete<QString, std::true_type>,
        // property 'lowStockCount'
        QtPrivate::TypeAndForceComplete<int, std::true_type>,
        // property 'pendingPOCount'
        QtPrivate::TypeAndForceComplete<int, std::true_type>,
        // property 'totalVendors'
        QtPrivate::TypeAndForceComplete<int, std::true_type>,
        // Q_OBJECT / Q_GADGET
        QtPrivate::TypeAndForceComplete<ExcelHandler, std::true_type>,
        // method 'currentFileChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'unsavedChangesChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'permanentFileChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'errorOccurred'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'fileLoaded'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'fileSaved'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'fileMerged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'searchResultFound'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'cloudFolderChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'syncEnabledChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'lastSyncTimeChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'syncStatusChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'currentUserChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'userRoleChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'syncCompleted'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'conflictDetected'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'lowStockCountChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'pendingPOCountChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'vendorListChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'itemMasterListChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'purchaseOrderCreated'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'goodsReceived'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'stockIssued'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'movementLogged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'onModelDataChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'autoSavePermanent'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'autoSyncFromCloud'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'createNew'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'createNew'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'createNew'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'createStockFile'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'createStockFile'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'createPurchaseFile'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'createPurchaseFile'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'getFileName'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        // method 'getFileType'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        // method 'loadExcel'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'saveExcel'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'saveExcel'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'setPermanentFile'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'loadPermanentFile'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'saveToPermanent'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'getSavedPermanentPath'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        // method 'hasSavedPermanentFile'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'appendFromFile'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'appendStockFile'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'validateFileStructure'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'browseOpenFile'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'browseSaveFile'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'browseFolder'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'exportReport'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'searchPartName'
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'searchAllMatches'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'uploadFileForPart'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'getUploadedFilePath'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'openUploadedFile'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'hasUploadedFile'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'addNewItem'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<double, std::false_type>,
        // method 'getNextSerialNumber'
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'syncToCloud'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'syncFromCloud'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'checkForUpdates'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'getCloudFilePath'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        // method 'canEdit'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'setCloudFolder'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'setCurrentUser'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'setUserRole'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'setSyncEnabled'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        // method 'addVendorDetails'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<QVariantMap, std::false_type>,
        // method 'updateVendorDetails'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<QVariantMap, std::false_type>,
        // method 'deleteVendor'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'getVendorList'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        // method 'getVendorNames'
        QtPrivate::TypeAndForceComplete<QStringList, std::false_type>,
        // method 'getVendorByName'
        QtPrivate::TypeAndForceComplete<QVariantMap, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'addItemMasterDetails'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<QVariantMap, std::false_type>,
        // method 'updateItemMasterDetails'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<QVariantMap, std::false_type>,
        // method 'getItemMasterList'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        // method 'deleteItem'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'createPurchaseOrder'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<double, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'createPurchaseOrder'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<double, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'createPurchaseOrder'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<double, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'sendPOForApproval'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'getPOList'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'getPOList'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        // method 'updatePOStatus'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'updatePurchaseOrder'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QVariantMap &, std::false_type>,
        // method 'getPOByNumber'
        QtPrivate::TypeAndForceComplete<QVariantMap, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'getNextPONumber'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        // method 'receiveGoods'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'receiveGoods'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'getGRNList'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        // method 'logStockMovement'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'getStockMovements'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'getStockMovements'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        // method 'getAllMovements'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        // method 'issueStock'
        QtPrivate::TypeAndForceComplete<QString, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        QtPrivate::TypeAndForceComplete<const QString &, std::false_type>,
        // method 'getIssueNotes'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        // method 'getLowStockItems'
        QtPrivate::TypeAndForceComplete<QVariantList, std::false_type>,
        // method 'lowStockCount'
        QtPrivate::TypeAndForceComplete<int, std::false_type>,
        // method 'autoGeneratePOForLowStock'
        QtPrivate::TypeAndForceComplete<bool, std::false_type>
    >,
    nullptr
} };

void ExcelHandler::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    if (_c == QMetaObject::InvokeMetaMethod) {
        auto *_t = static_cast<ExcelHandler *>(_o);
        (void)_t;
        switch (_id) {
        case 0: _t->currentFileChanged(); break;
        case 1: _t->unsavedChangesChanged(); break;
        case 2: _t->permanentFileChanged(); break;
        case 3: _t->errorOccurred((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 4: _t->fileLoaded((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 5: _t->fileSaved((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 6: _t->fileMerged((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[3]))); break;
        case 7: _t->searchResultFound((*reinterpret_cast< std::add_pointer_t<int>>(_a[1]))); break;
        case 8: _t->cloudFolderChanged(); break;
        case 9: _t->syncEnabledChanged(); break;
        case 10: _t->lastSyncTimeChanged(); break;
        case 11: _t->syncStatusChanged(); break;
        case 12: _t->currentUserChanged(); break;
        case 13: _t->userRoleChanged(); break;
        case 14: _t->syncCompleted((*reinterpret_cast< std::add_pointer_t<bool>>(_a[1]))); break;
        case 15: _t->conflictDetected((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 16: _t->lowStockCountChanged(); break;
        case 17: _t->pendingPOCountChanged(); break;
        case 18: _t->vendorListChanged(); break;
        case 19: _t->itemMasterListChanged(); break;
        case 20: _t->purchaseOrderCreated((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 21: _t->goodsReceived((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2]))); break;
        case 22: _t->stockIssued((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[3]))); break;
        case 23: _t->movementLogged((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[3]))); break;
        case 24: _t->onModelDataChanged(); break;
        case 25: _t->autoSavePermanent(); break;
        case 26: _t->autoSyncFromCloud(); break;
        case 27: _t->createNew((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[2]))); break;
        case 28: _t->createNew((*reinterpret_cast< std::add_pointer_t<int>>(_a[1]))); break;
        case 29: _t->createNew(); break;
        case 30: _t->createStockFile((*reinterpret_cast< std::add_pointer_t<int>>(_a[1]))); break;
        case 31: _t->createStockFile(); break;
        case 32: _t->createPurchaseFile((*reinterpret_cast< std::add_pointer_t<int>>(_a[1]))); break;
        case 33: _t->createPurchaseFile(); break;
        case 34: { QString _r = _t->getFileName();
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 35: { QString _r = _t->getFileType();
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 36: { bool _r = _t->loadExcel((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 37: { bool _r = _t->saveExcel((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 38: { bool _r = _t->saveExcel();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 39: { bool _r = _t->setPermanentFile((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 40: { bool _r = _t->loadPermanentFile();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 41: { bool _r = _t->saveToPermanent();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 42: { QString _r = _t->getSavedPermanentPath();
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 43: { bool _r = _t->hasSavedPermanentFile();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 44: { bool _r = _t->appendFromFile((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 45: { bool _r = _t->appendStockFile((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 46: { bool _r = _t->validateFileStructure((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 47: { QString _r = _t->browseOpenFile((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 48: { QString _r = _t->browseSaveFile((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 49: { QString _r = _t->browseFolder((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 50: { bool _r = _t->exportReport((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 51: { int _r = _t->searchPartName((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< int*>(_a[0]) = std::move(_r); }  break;
        case 52: { QVariantList _r = _t->searchAllMatches((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 53: { bool _r = _t->uploadFileForPart((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 54: { QString _r = _t->getUploadedFilePath((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 55: { bool _r = _t->openUploadedFile((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 56: { bool _r = _t->hasUploadedFile((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 57: _t->addNewItem((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[3])),(*reinterpret_cast< std::add_pointer_t<double>>(_a[4]))); break;
        case 58: { int _r = _t->getNextSerialNumber();
            if (_a[0]) *reinterpret_cast< int*>(_a[0]) = std::move(_r); }  break;
        case 59: { bool _r = _t->syncToCloud();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 60: { bool _r = _t->syncFromCloud();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 61: { bool _r = _t->checkForUpdates();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 62: { QString _r = _t->getCloudFilePath();
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 63: { bool _r = _t->canEdit();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 64: _t->setCloudFolder((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 65: _t->setCurrentUser((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 66: _t->setUserRole((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 67: _t->setSyncEnabled((*reinterpret_cast< std::add_pointer_t<bool>>(_a[1]))); break;
        case 68: { bool _r = _t->addVendorDetails((*reinterpret_cast< std::add_pointer_t<QVariantMap>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 69: { bool _r = _t->updateVendorDetails((*reinterpret_cast< std::add_pointer_t<QVariantMap>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 70: { bool _r = _t->deleteVendor((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 71: { QVariantList _r = _t->getVendorList();
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 72: { QStringList _r = _t->getVendorNames();
            if (_a[0]) *reinterpret_cast< QStringList*>(_a[0]) = std::move(_r); }  break;
        case 73: { QVariantMap _r = _t->getVendorByName((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QVariantMap*>(_a[0]) = std::move(_r); }  break;
        case 74: { bool _r = _t->addItemMasterDetails((*reinterpret_cast< std::add_pointer_t<QVariantMap>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 75: { bool _r = _t->updateItemMasterDetails((*reinterpret_cast< std::add_pointer_t<QVariantMap>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 76: { QVariantList _r = _t->getItemMasterList();
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 77: { bool _r = _t->deleteItem((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 78: { QString _r = _t->createPurchaseOrder((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast< std::add_pointer_t<double>>(_a[5])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[6])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[7])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[8])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 79: { QString _r = _t->createPurchaseOrder((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast< std::add_pointer_t<double>>(_a[5])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[6])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[7])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 80: { QString _r = _t->createPurchaseOrder((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast< std::add_pointer_t<double>>(_a[5])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[6])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 81: { bool _r = _t->sendPOForApproval((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 82: { QVariantList _r = _t->getPOList((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 83: { QVariantList _r = _t->getPOList();
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 84: { bool _r = _t->updatePOStatus((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 85: { bool _r = _t->updatePurchaseOrder((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QVariantMap>>(_a[2])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 86: { QVariantMap _r = _t->getPOByNumber((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QVariantMap*>(_a[0]) = std::move(_r); }  break;
        case 87: { QString _r = _t->getNextPONumber();
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 88: { QString _r = _t->receiveGoods((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[3])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[5])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[6])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 89: { QString _r = _t->receiveGoods((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[3])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[5])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 90: { QVariantList _r = _t->getGRNList();
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 91: { bool _r = _t->logStockMovement((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[5])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[6])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 92: { QVariantList _r = _t->getStockMovements((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 93: { QVariantList _r = _t->getStockMovements();
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 94: { QVariantList _r = _t->getAllMovements();
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 95: { QString _r = _t->issueStock((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[4])));
            if (_a[0]) *reinterpret_cast< QString*>(_a[0]) = std::move(_r); }  break;
        case 96: { QVariantList _r = _t->getIssueNotes();
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 97: { QVariantList _r = _t->getLowStockItems();
            if (_a[0]) *reinterpret_cast< QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 98: { int _r = _t->lowStockCount();
            if (_a[0]) *reinterpret_cast< int*>(_a[0]) = std::move(_r); }  break;
        case 99: { bool _r = _t->autoGeneratePOForLowStock();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    } else if (_c == QMetaObject::IndexOfMethod) {
        int *result = reinterpret_cast<int *>(_a[0]);
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::currentFileChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 0;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::unsavedChangesChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 1;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::permanentFileChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 2;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(const QString & );
            if (_t _q_method = &ExcelHandler::errorOccurred; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 3;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(const QString & );
            if (_t _q_method = &ExcelHandler::fileLoaded; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 4;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(const QString & );
            if (_t _q_method = &ExcelHandler::fileSaved; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 5;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(const QString & , int , int );
            if (_t _q_method = &ExcelHandler::fileMerged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 6;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(int );
            if (_t _q_method = &ExcelHandler::searchResultFound; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 7;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::cloudFolderChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 8;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::syncEnabledChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 9;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::lastSyncTimeChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 10;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::syncStatusChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 11;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::currentUserChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 12;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::userRoleChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 13;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(bool );
            if (_t _q_method = &ExcelHandler::syncCompleted; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 14;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(const QString & );
            if (_t _q_method = &ExcelHandler::conflictDetected; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 15;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::lowStockCountChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 16;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::pendingPOCountChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 17;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::vendorListChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 18;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)();
            if (_t _q_method = &ExcelHandler::itemMasterListChanged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 19;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(const QString & );
            if (_t _q_method = &ExcelHandler::purchaseOrderCreated; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 20;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(const QString & , const QString & );
            if (_t _q_method = &ExcelHandler::goodsReceived; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 21;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(const QString & , const QString & , int );
            if (_t _q_method = &ExcelHandler::stockIssued; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 22;
                return;
            }
        }
        {
            using _t = void (ExcelHandler::*)(const QString & , const QString & , int );
            if (_t _q_method = &ExcelHandler::movementLogged; *reinterpret_cast<_t *>(_a[1]) == _q_method) {
                *result = 23;
                return;
            }
        }
    } else if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 0:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< ExcelTableModel* >(); break;
        }
    }
else if (_c == QMetaObject::ReadProperty) {
        auto *_t = static_cast<ExcelHandler *>(_o);
        (void)_t;
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast< ExcelTableModel**>(_v) = _t->model(); break;
        case 1: *reinterpret_cast< QString*>(_v) = _t->currentFile(); break;
        case 2: *reinterpret_cast< bool*>(_v) = _t->hasUnsavedChanges(); break;
        case 3: *reinterpret_cast< QString*>(_v) = _t->permanentFile(); break;
        case 4: *reinterpret_cast< QString*>(_v) = _t->cloudFolder(); break;
        case 5: *reinterpret_cast< bool*>(_v) = _t->syncEnabled(); break;
        case 6: *reinterpret_cast< QString*>(_v) = _t->lastSyncTime(); break;
        case 7: *reinterpret_cast< QString*>(_v) = _t->syncStatus(); break;
        case 8: *reinterpret_cast< QString*>(_v) = _t->currentUser(); break;
        case 9: *reinterpret_cast< QString*>(_v) = _t->userRole(); break;
        case 10: *reinterpret_cast< int*>(_v) = _t->lowStockCount(); break;
        case 11: *reinterpret_cast< int*>(_v) = _t->pendingPOCount(); break;
        case 12: *reinterpret_cast< int*>(_v) = _t->totalVendors(); break;
        default: break;
        }
    } else if (_c == QMetaObject::WriteProperty) {
        auto *_t = static_cast<ExcelHandler *>(_o);
        (void)_t;
        void *_v = _a[0];
        switch (_id) {
        case 4: _t->setCloudFolder(*reinterpret_cast< QString*>(_v)); break;
        case 5: _t->setSyncEnabled(*reinterpret_cast< bool*>(_v)); break;
        case 8: _t->setCurrentUser(*reinterpret_cast< QString*>(_v)); break;
        case 9: _t->setUserRole(*reinterpret_cast< QString*>(_v)); break;
        default: break;
        }
    } else if (_c == QMetaObject::ResetProperty) {
    } else if (_c == QMetaObject::BindableProperty) {
    }
}

const QMetaObject *ExcelHandler::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *ExcelHandler::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_meta_stringdata_ExcelHandler.stringdata0))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int ExcelHandler::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 100)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 100;
    } else if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 100)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 100;
    }else if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 13;
    }
    return _id;
}

// SIGNAL 0
void ExcelHandler::currentFileChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void ExcelHandler::unsavedChangesChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void ExcelHandler::permanentFileChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void ExcelHandler::errorOccurred(const QString & _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))) };
    QMetaObject::activate(this, &staticMetaObject, 3, _a);
}

// SIGNAL 4
void ExcelHandler::fileLoaded(const QString & _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))) };
    QMetaObject::activate(this, &staticMetaObject, 4, _a);
}

// SIGNAL 5
void ExcelHandler::fileSaved(const QString & _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))) };
    QMetaObject::activate(this, &staticMetaObject, 5, _a);
}

// SIGNAL 6
void ExcelHandler::fileMerged(const QString & _t1, int _t2, int _t3)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))), const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t2))), const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t3))) };
    QMetaObject::activate(this, &staticMetaObject, 6, _a);
}

// SIGNAL 7
void ExcelHandler::searchResultFound(int _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))) };
    QMetaObject::activate(this, &staticMetaObject, 7, _a);
}

// SIGNAL 8
void ExcelHandler::cloudFolderChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}

// SIGNAL 9
void ExcelHandler::syncEnabledChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}

// SIGNAL 10
void ExcelHandler::lastSyncTimeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 10, nullptr);
}

// SIGNAL 11
void ExcelHandler::syncStatusChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 11, nullptr);
}

// SIGNAL 12
void ExcelHandler::currentUserChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 12, nullptr);
}

// SIGNAL 13
void ExcelHandler::userRoleChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 13, nullptr);
}

// SIGNAL 14
void ExcelHandler::syncCompleted(bool _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))) };
    QMetaObject::activate(this, &staticMetaObject, 14, _a);
}

// SIGNAL 15
void ExcelHandler::conflictDetected(const QString & _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))) };
    QMetaObject::activate(this, &staticMetaObject, 15, _a);
}

// SIGNAL 16
void ExcelHandler::lowStockCountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 16, nullptr);
}

// SIGNAL 17
void ExcelHandler::pendingPOCountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 17, nullptr);
}

// SIGNAL 18
void ExcelHandler::vendorListChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 18, nullptr);
}

// SIGNAL 19
void ExcelHandler::itemMasterListChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 19, nullptr);
}

// SIGNAL 20
void ExcelHandler::purchaseOrderCreated(const QString & _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))) };
    QMetaObject::activate(this, &staticMetaObject, 20, _a);
}

// SIGNAL 21
void ExcelHandler::goodsReceived(const QString & _t1, const QString & _t2)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))), const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t2))) };
    QMetaObject::activate(this, &staticMetaObject, 21, _a);
}

// SIGNAL 22
void ExcelHandler::stockIssued(const QString & _t1, const QString & _t2, int _t3)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))), const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t2))), const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t3))) };
    QMetaObject::activate(this, &staticMetaObject, 22, _a);
}

// SIGNAL 23
void ExcelHandler::movementLogged(const QString & _t1, const QString & _t2, int _t3)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))), const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t2))), const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t3))) };
    QMetaObject::activate(this, &staticMetaObject, 23, _a);
}
QT_WARNING_POP
QT_END_MOC_NAMESPACE
