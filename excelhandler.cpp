#include "excelhandler.h"
#include "podocument.h"
#include "dbmanager.h"
#include "serversetup.h"
#include <QFileDialog>
#include <QtMath>

static int toStockInt(const QVariant &value)
{
    bool ok = false;
    double number = value.toDouble(&ok);
    if (!ok) {
        number = value.toString().trimmed().toDouble(&ok);
        if (!ok) return 0;
    }
    return qRound(number);
}

// ==================== DB field mapping ====================
// Maps the application/QML QVariantMap keys to their SQL columns so the
// existing in-memory caches (m_vendors, m_purchaseOrders, ...) can be
// persisted to and loaded from the database without changing the keys the
// QML layer relies on.
namespace {
struct DbField {
    const char *column;   // SQL column name
    const char *key;      // QVariantMap key used by the app / QML
    char type;            // 's' string, 'i' int, 'd' double
};

const QVector<DbField> kVendorFields = {
    {"vendor_name",    "vendorName",    's'},
    {"vendor_address", "vendorAddress", 's'},
    {"bank_branch",    "bankBranch",    's'},
    {"ifsc",           "ifsc",          's'},
    {"account_number", "accountNumber", 's'},
    {"cin",            "cin",           's'},
    {"gstin",          "gstin",         's'},
    {"pan_number",     "panNumber",     's'},
    {"pan_name",       "panName",       's'},
    {"contact_person", "contactPerson", 's'},
    {"email",          "email",         's'},
    {"phone",          "phone",         's'},
    {"item_category",  "itemCategory",  's'},
};

const QVector<DbField> kItemFields = {
    {"part_no",      "partNo",      's'},
    {"part_name",    "partName",    's'},
    {"category",     "category",    's'},
    {"department",   "department",  's'},
    {"vendor",       "vendor",      's'},
    {"required_qty", "requiredQty", 'i'},
    {"unit_price",   "unitPrice",   'd'},
    {"stock_qty",    "stockQty",    'i'},
};

const QVector<DbField> kPoFields = {
    {"po_no",         "poNo",         's'},
    {"po_date",       "date",         's'},
    {"vendor",        "vendor",       's'},
    {"part_name",     "partName",     's'},
    {"part_no",       "partNo",       's'},
    {"department",    "department",   's'},
    {"qty",           "qty",          'i'},
    {"unit_price",    "unitPrice",    'd'},
    {"total_amount",  "totalAmount",  'd'},
    {"expected_date", "expectedDate", 's'},
    {"status",        "status",       's'},
    {"received_qty",  "receivedQty",  'i'},
    {"prepared_by",   "preparedBy",   's'},
    {"approved_by",   "approvedBy",   's'},
    {"received_by",   "receivedBy",   's'},
    {"received_date", "receivedDate", 's'},
};

const QVector<DbField> kPoItemFields = {
    {"id",           "id",           'i'},
    {"po_no",        "poNo",         's'},
    {"part_name",    "partName",     's'},
    {"part_no",      "partNo",       's'},
    {"vendor",       "vendor",       's'},
    {"department",   "department",   's'},
    {"qty",          "qty",          'i'},
    {"unit_price",   "unitPrice",    'd'},
    {"total_amount", "totalAmount",  'd'},
    {"received_qty", "receivedQty",  'i'},
};

const QVector<DbField> kGrnFields = {
    {"grn_no",       "grnNo",       's'},
    {"po_no",        "poNo",        's'},
    {"grn_date",     "date",        's'},
    {"part_name",    "partName",    's'},
    {"received_qty", "receivedQty", 'i'},
    {"accepted_qty", "acceptedQty", 'i'},
    {"rejected_qty", "rejectedQty", 'i'},
    {"remarks",      "remarks",     's'},
    {"received_by",  "receivedBy",  's'},
};

const QVector<DbField> kMovementFields = {
    {"mov_date",  "date",     's'},
    {"part_name", "partName", 's'},
    {"part_no",   "partNo",   's'},
    {"type",      "type",     's'},
    {"qty",       "qty",      'i'},
    {"reference", "reference",'s'},
    {"done_by",   "doneBy",   's'},
};

const QVector<DbField> kIssueFields = {
    {"issue_no",   "issueNo",    's'},
    {"issue_date", "date",       's'},
    {"part_name",  "partName",   's'},
    {"qty",        "qty",        'i'},
    {"department", "department", 's'},
    {"issued_by",  "issuedBy",   's'},
};

QVariant coerce(const QVariant &v, char type) {
    switch (type) {
    case 'i': return v.toInt();
    case 'd': return v.toDouble();
    default:  return v.toString();
    }
}

QVariantMap dbRowToApp(const QVector<DbField> &fields, const QVariantMap &dbRow) {
    QVariantMap out;
    for (const DbField &f : fields)
        out[f.key] = coerce(dbRow.value(f.column), f.type);
    return out;
}

QVariantMap appRowToDb(const QVector<DbField> &fields, const QVariantMap &appRow) {  
    QVariantMap out;
    for (const DbField &f : fields)
        out[f.column] = coerce(appRow.value(f.key), f.type);
    return out;
}

QVector<QVariantMap> dbRowsToApp(const QVector<DbField> &fields, const QVector<QVariantMap> &dbRows) {
    QVector<QVariantMap> out;
    out.reserve(dbRows.size());
    for (const QVariantMap &r : dbRows) out.append(dbRowToApp(fields, r));
    return out;
}

QVector<QVariantMap> appRowsToDb(const QVector<DbField> &fields, const QVector<QVariantMap> &appRows) {
    QVector<QVariantMap> out;
    out.reserve(appRows.size());
    for (const QVariantMap &r : appRows) out.append(appRowToDb(fields, r));
    return out;
}
} // namespace

// ==================== ExcelTableModel Implementation ====================

ExcelTableModel::ExcelTableModel(QObject *parent)
    : QAbstractTableModel(parent)
{
}

int ExcelTableModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_data.size();
}

int ExcelTableModel::columnCount(const QModelIndex &parent) const
{
    if (parent.isValid() || m_data.isEmpty()) return 0;
    return m_data.first().size();
}

QVariant ExcelTableModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || role != Qt::DisplayRole) return QVariant();
    if (index.row() >= m_data.size() || index.column() >= m_data[index.row()].size())
        return QVariant();
    return m_data[index.row()][index.column()];
}

bool ExcelTableModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid() || role != Qt::EditRole) return false;
    if (index.row() >= m_data.size() || index.column() >= m_data[index.row()].size())
        return false;
    m_data[index.row()][index.column()] = value;
    emit dataChanged(index, index, {role});
    return true;
}

Qt::ItemFlags ExcelTableModel::flags(const QModelIndex &index) const
{
    if (!index.isValid()) return Qt::NoItemFlags;
    return Qt::ItemIsEditable | Qt::ItemIsEnabled | Qt::ItemIsSelectable;
}

QHash<int, QByteArray> ExcelTableModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[Qt::DisplayRole] = "display";
    return roles;
}

void ExcelTableModel::setExcelData(const QVector<QVector<QVariant>> &data)
{
    beginResetModel();
    m_data = data;
    endResetModel();
}

QVector<QVector<QVariant>> ExcelTableModel::getExcelData() const
{
    return m_data;
}

QVariant ExcelTableModel::getData(int row, int column) const
{
    if (row < 0 || row >= m_data.size()) return QVariant();
    if (column < 0 || column >= m_data[row].size()) return QVariant();
    return m_data[row][column];
}

bool ExcelTableModel::setDataAt(int row, int column, const QVariant &value)
{
    if (row < 0 || row >= m_data.size()) return false;
    if (column < 0 || column >= m_data[row].size()) return false;
    m_data[row][column] = value;
    QModelIndex idx = index(row, column);
    emit dataChanged(idx, idx, {Qt::DisplayRole});
    return true;
}

void ExcelTableModel::addRow()
{
    int cols = m_data.isEmpty() ? 9 : m_data.first().size();
    beginInsertRows(QModelIndex(), m_data.size(), m_data.size());
    QVector<QVariant> newRow(cols);
    m_data.append(newRow);
    endInsertRows();
}

bool ExcelTableModel::removeRowAt(int row)
{
    if (row <= 0 || row >= m_data.size()) return false;
    beginRemoveRows(QModelIndex(), row, row);
    m_data.removeAt(row);
    endRemoveRows();
    return true;
}

void ExcelTableModel::addColumn()
{
    if (m_data.isEmpty()) return;
    int cols = m_data.first().size();
    beginInsertColumns(QModelIndex(), cols, cols);
    for (auto &row : m_data) {
        row.append(QVariant());
    }
    endInsertColumns();
}

void ExcelTableModel::clear()
{
    beginResetModel();
    m_data.clear();
    endResetModel();
}

// ==================== ExcelHandler Implementation ====================

ExcelHandler::ExcelHandler(QObject *parent)
    : QObject(parent),
    m_db(new DatabaseManager(this)),
    m_serverSetup(new ServerSetup(this)),
    m_model(new ExcelTableModel(this)),
    m_hasUnsavedChanges(false),
    m_syncEnabled(false),
    m_syncStatus("offline"),
    m_currentUser("User"),
    m_userRole("editor"),
    m_nextPONumber(1),
    m_nextGRNNumber(1),
    m_nextIssueNumber(1)
{
    connect(m_model, &QAbstractItemModel::dataChanged,
            this, &ExcelHandler::onModelDataChanged);
    connect(m_model, &QAbstractItemModel::rowsInserted,
            this, &ExcelHandler::onModelDataChanged);
    connect(m_model, &QAbstractItemModel::rowsRemoved,
            this, &ExcelHandler::onModelDataChanged);

    m_autoSaveTimer.setSingleShot(true);
    connect(&m_autoSaveTimer, &QTimer::timeout,
            this, &ExcelHandler::autoSavePermanent);

    m_cloudPollTimer.setInterval(10000);
    m_cloudPollTimer.setSingleShot(false);
    connect(&m_cloudPollTimer, &QTimer::timeout,
            this, &ExcelHandler::autoSyncFromCloud);

    initializeUploadsDirectory();
    initializeDataDirectory();
    loadPermanentFileSettings();
    loadCloudSettings();

    // Storage now lives in a shared SQL database instead of a Dropbox folder,
    // so the old folder-based cloud sync stays disabled.
    m_syncEnabled = false;

    // Connect to the shared database (Postgres in production, local SQLite
    // fallback otherwise) and build the schema before loading any data.
    if (!m_db->connectDatabase()) {
        emit errorOccurred("Could not open the database: " + m_db->lastError());
    }
    connect(m_db, &DatabaseManager::databaseError,
            this, [this](const QString &msg) { emit errorOccurred(msg); });

    connect(m_serverSetup, &ServerSetup::progress,
            this, &ExcelHandler::serverProvisionProgress);
    connect(m_serverSetup, &ServerSetup::finished, this,
            [this](bool success, const QVariantMap &result) {
                if (success) {
                    // Reconnect this machine itself to the shared database
                    // it just provisioned, using the exact same client path
                    // every other workstation will use.
                    configureDatabase("QPSQL", "localhost", result.value("port").toInt(),
                                       result.value("name").toString(),
                                       result.value("user").toString(),
                                       result.value("password").toString());
                }
                emit serverProvisionFinished(success, result);
            });

    // Load supply chain data from the database
    loadVendors();
    loadItemMaster();
    loadPurchaseOrders();
    loadStockMovements();
    loadIssueNotes();
    loadGRNRecords();

    // The stock grid also lives in the shared database. Fall back to an
    // empty default grid on a fresh database (no permanent file needed).
    if (!loadStockFromDb())
        createStockFile(15);

    qDebug() << "ExcelHandler created with Supply Chain support (DB backend:"
             << m_db->backendName() << ")";
    qDebug() << "Vendors:" << m_vendors.size()
             << "| POs:" << m_purchaseOrders.size()
             << "| Movements:" << m_stockMovements.size();
}

// ==================== Data Directory ====================

void ExcelHandler::initializeDataDirectory()
{
    QString appData = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    m_dataDir = appData + "/supplychain";

    QDir dir;
    if (!dir.exists(m_dataDir)) {
        dir.mkpath(m_dataDir);
        qDebug() << "Created supply chain data dir:" << m_dataDir;
    }
}

void ExcelHandler::initializeUploadsDirectory()
{
    QString appData = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    m_uploadsDir = appData + "/uploads";
    QDir dir;
    if (!dir.exists(m_uploadsDir)) {
        dir.mkpath(m_uploadsDir);
    }
}

// ==================== Supply Chain Counters ====================

void ExcelHandler::loadSupplyChainCounters()
{
    QSettings settings("EinsteinRobotics", "StockManager");
    m_nextPONumber = settings.value("nextPONumber", 1).toInt();
    m_nextGRNNumber = settings.value("nextGRNNumber", 1).toInt();
    m_nextIssueNumber = settings.value("nextIssueNumber", 1).toInt();
}

void ExcelHandler::saveSupplyChainCounters()
{
    QSettings settings("EinsteinRobotics", "StockManager");
    settings.setValue("nextPONumber", m_nextPONumber);
    settings.setValue("nextGRNNumber", m_nextGRNNumber);
    settings.setValue("nextIssueNumber", m_nextIssueNumber);
}

// ==================== VENDOR MANAGEMENT ====================

void ExcelHandler::loadVendors()
{
    m_vendors.clear();
    if (!m_db) return;
    m_vendors = dbRowsToApp(kVendorFields, m_db->selectAll("vendors", "vendor_name"));
    qDebug() << "Loaded" << m_vendors.size() << "vendors";
}

bool ExcelHandler::saveVendors()
{
    if (!m_db) return false;
    if (!m_db->replaceAll("vendors", appRowsToDb(kVendorFields, m_vendors))) {
        emit errorOccurred("Failed to save vendor data");
        return false;
    }
    qDebug() << "Saved" << m_vendors.size() << "vendors";
    return true;
}

bool ExcelHandler::addVendorDetails(QVariantMap vendor)
{
    QString vendorName = vendor["vendorName"].toString();
    qDebug() << "vendor Name:" << vendorName;
    if (vendorName.trimmed().isEmpty()) {
        emit errorOccurred("Vendor name is required");
        return false;
    }

    // Check duplicate
    for (const auto &v : m_vendors) {
        if (v["vendorName"].toString().toLower() == vendorName.trimmed().toLower()) {
            emit errorOccurred("Vendor '" + vendorName + "' already exists");
            return false;
        }
    }

    qDebug()<<"Adding vendor:" << vendor;
    m_vendors.append(vendor);
    qDebug() << "Vendor added to list:" << vendor;
    qDebug() << "Current vendor count:" << m_vendors.size();    
    if (!saveVendors()) {
        m_vendors.removeLast();
        return false;
    }
    qDebug() << "Vendor saved to file:" << vendor;
    emit vendorListChanged();

    qDebug() << "Added vendor:" << vendorName;
    return true;
}

bool ExcelHandler::updateVendorDetails(QVariantMap vendor)
{
    QString originalName = vendor.value("originalName").toString().trimmed();
    QString newName = vendor.value("vendorName").toString().trimmed();
    if (newName.isEmpty()) {
        emit errorOccurred("Vendor name is required");
        return false;
    }

    int index = -1;
    auto matchesName = [](const QVariantMap &item, const QString &name) {
        return item.value("vendorName").toString().trimmed().toLower() == name.trimmed().toLower();
    };

    if (!originalName.isEmpty()) {
        for (int i = 0; i < m_vendors.size(); ++i) {
            if (matchesName(m_vendors[i], originalName)) {
                index = i;
                break;
            }
        }
    }

    if (index == -1) {
        for (int i = 0; i < m_vendors.size(); ++i) {
            if (matchesName(m_vendors[i], newName)) {
                index = i;
                break;
            }
        }
    }

    if (index == -1) {
        emit errorOccurred("Vendor not found: " + (originalName.isEmpty() ? newName : originalName));
        return false;
    }

    QString newNameLower = newName.toLower();
    for (int i = 0; i < m_vendors.size(); ++i) {
        if (i == index) continue;
        if (m_vendors[i]["vendorName"].toString().trimmed().toLower() == newNameLower) {
            emit errorOccurred("Vendor '" + newName + "' already exists");
            return false;
        }
    }

    QVariantMap updated = m_vendors[index];
    updated["vendorName"] = newName;
    updated["vendorAddress"] = vendor.value("vendorAddress", updated.value("vendorAddress")).toString();
    updated["bankBranch"] = vendor.value("bankBranch", updated.value("bankBranch")).toString();
    updated["ifsc"] = vendor.value("ifsc", updated.value("ifsc")).toString();
    updated["accountNumber"] = vendor.value("accountNumber", updated.value("accountNumber")).toString();
    updated["cin"] = vendor.value("cin", updated.value("cin")).toString();
    updated["gstin"] = vendor.value("gstin", updated.value("gstin")).toString();
    updated["panNumber"] = vendor.value("panNumber", updated.value("panNumber")).toString();
    updated["panName"] = vendor.value("panName", updated.value("panName")).toString();
    updated["contactPerson"] = vendor.value("contactPerson", updated.value("contactPerson")).toString();
    updated["email"] = vendor.value("email", updated.value("email")).toString();
    updated["phone"] = vendor.value("phone", updated.value("phone")).toString();
    updated["itemCategory"] = vendor.value("itemCategory", updated.value("itemCategory")).toString();

    QVariantMap previous = m_vendors[index];
    m_vendors[index] = updated;

    if (!saveVendors()) {
        m_vendors[index] = previous;
        return false;
    }

    emit vendorListChanged();
    return true;
}

bool ExcelHandler::deleteVendor(const QString &name)
{
    for (int i = 0; i < m_vendors.size(); ++i) {
        if (m_vendors[i]["vendorName"].toString().toLower() == name.trimmed().toLower()) {
            QVariantMap removedVendor = m_vendors[i];
            m_vendors.removeAt(i);
            if (!saveVendors()) {
                m_vendors.insert(i, removedVendor);
                return false;
            }
            emit vendorListChanged();
            return true;
        }
    }
    emit errorOccurred("Vendor not found: " + name);
    return false;
}

QVariantList ExcelHandler::getVendorList()
{
    QVariantList list;
    for (const auto &v : m_vendors) {
        list.append(v);
    }
    return list;
}

QStringList ExcelHandler::getVendorNames()
{
    QStringList names;
    for (const auto &v : m_vendors) {
        names.append(v["vendorName"].toString());
    }
    return names;
}

QVariantMap ExcelHandler::getVendorByName(const QString &name)
{
    for (const auto &v : m_vendors) {
        if (v["vendorName"].toString().toLower() == name.trimmed().toLower()) {
            return v;
        }
    }
    return QVariantMap();
}

// ===================== ITEM MASTER MANAGEMENT ======================

void ExcelHandler::loadItemMaster()
{
    m_itemMaster.clear();
    if (!m_db) return;
    m_itemMaster = dbRowsToApp(kItemFields, m_db->selectAll("item_master", "part_no"));
    qDebug() << "Loaded" << m_itemMaster.size() << "items in Item Master";
}

void ExcelHandler::saveItemMaster()
{
    if (!m_db) return;
    m_db->replaceAll("item_master", appRowsToDb(kItemFields, m_itemMaster));
}

bool ExcelHandler::addItemMasterDetails(QVariantMap itemDetails) 
{
    QString partNo = itemDetails["partNo"].toString();
    if (partNo.trimmed().isEmpty()) {
        emit errorOccurred("Part number is required");
        return false;
    }

    // Check duplicate
    for (const auto &item : m_itemMaster) {
        if (item["partNo"].toString().toLower() == partNo.trimmed().toLower()) {
            //emit errorOccurred("Part '" + partNo + "' already exists in Item Master");
        }
    }

    m_itemMaster.append(itemDetails);
    saveItemMaster();
    emit itemMasterListChanged();
    emit lowStockCountChanged();
    return true;
}

bool ExcelHandler::updateItemMasterDetails(QVariantMap itemDetails)
{
    QString originalPartNo = itemDetails.value("originalPartNo").toString().trimmed();
    QString newPartNo = itemDetails.value("partNo").toString().trimmed();
    if (newPartNo.isEmpty()) {
        emit errorOccurred("Part number is required");           
        return false;
    }

    int index = -1;
    auto matchesPartNo = [](const QVariantMap &item, const QString &partNo) {
        return item.value("partNo").toString().trimmed().toLower() == partNo.trimmed().toLower();
    };

    if (!originalPartNo.isEmpty()) {
        for (int i = 0; i < m_itemMaster.size(); ++i) {
            if (matchesPartNo(m_itemMaster[i], originalPartNo)) {
                index = i;
                break;
            }
        }
    }

    if (index == -1) {
        for (int i = 0; i < m_itemMaster.size(); ++i) {
            if (matchesPartNo(m_itemMaster[i], newPartNo)) {
                index = i;
                break;
            }
        }
    }

    if (index == -1) {
        emit errorOccurred("Item not found: " + (originalPartNo.isEmpty() ? newPartNo : originalPartNo));
        return false;
    }

    QString newPartNoLower = newPartNo.toLower();
    for (int i = 0; i < m_itemMaster.size(); ++i) {
        if (i == index) continue;
        if (m_itemMaster[i]["partNo"].toString().trimmed().toLower() == newPartNoLower) {
            emit errorOccurred("Part No '" + newPartNo + "' already exists");
            return false;
        }
    }

    QVariantMap updated = m_itemMaster[index];
    QString partName = itemDetails.value("partName", updated.value("partName")).toString();
    QString department = itemDetails.value("department", updated.value("department")).toString();
    int requiredQty = itemDetails.value("requiredQty", updated.value("requiredQty")).toInt();
    double unitPrice = itemDetails.value("unitPrice", updated.value("unitPrice")).toDouble();
    QString vendor = itemDetails.value("vendor", updated.value("vendor")).toString();

    updated["partNo"] = newPartNo;
    updated["partName"] = partName;
    updated["department"] = department;
    updated["requiredQty"] = requiredQty;
    updated["unitPrice"] = unitPrice;
    updated["vendor"] = vendor;

    // Keep legacy columns in sync for persistence.
    updated["category"] = itemDetails.value("category", department.isEmpty() ? updated.value("category") : department);
    updated["stockQty"] = itemDetails.contains("stockQty") ? itemDetails.value("stockQty").toInt() : requiredQty;

    QVariantMap previous = m_itemMaster[index];
    m_itemMaster[index] = updated;

    saveItemMaster();
    emit itemMasterListChanged();
    emit lowStockCountChanged();
    return true;
}

QVariantList ExcelHandler::getItemMasterList()
{
    QVariantList list;
    for (const auto &item : m_itemMaster) {
        list.append(item);
    }
    return list;
}

bool ExcelHandler::deleteItem(const QString &partName)
{
    for (int i = 0; i < m_itemMaster.size(); ++i) {
        if (m_itemMaster[i]["partName"].toString().toLower() == partName.trimmed().toLower()) {
            m_itemMaster.removeAt(i);
            saveItemMaster();
            emit itemMasterListChanged();
            emit lowStockCountChanged();
            return true;
        }
    }
    emit errorOccurred("Item not found: " + partName);
    return false;
}

// ==================== PURCHASE ORDER MANAGEMENT ====================

void ExcelHandler::loadPurchaseOrders()
{
    m_purchaseOrders.clear();
    if (!m_db) return;
    m_purchaseOrders = dbRowsToApp(kPoFields, m_db->selectAll("purchase_orders", "po_no"));

    // Apply the same defaults the old loader used.
    for (QVariantMap &po : m_purchaseOrders) {
        if (po["status"].toString().trimmed().isEmpty())
            po["status"] = "Draft";
        if (po["totalAmount"].toDouble() <= 0.0 && po["qty"].toInt() > 0 && po["unitPrice"].toDouble() > 0.0)
            po["totalAmount"] = po["qty"].toInt() * po["unitPrice"].toDouble();
    }

    loadPOItems();

    qDebug() << "Loaded" << m_purchaseOrders.size() << "purchase orders ("
             << m_poItems.size() << "line items )";
}

void ExcelHandler::savePurchaseOrders()
{
    if (!m_db) return;
    m_db->replaceAll("purchase_orders", appRowsToDb(kPoFields, m_purchaseOrders));
}

// ==================== STOCK GRID <-> DATABASE ====================
// The dashboard grid columns, in model order 0..8.
static const char *kStockDbColumns[] = {
    "part_name", "part_no", "stock", "department", "prepared",
    "approved", "vendor", "row_date", "unit_price"
};

bool ExcelHandler::loadStockFromDb()
{
    if (!m_db) return false;
    const QVector<QVariantMap> rows = m_db->selectAll("stock_rows", "id");
    if (rows.isEmpty()) return false;

    QVector<QVector<QVariant>> data;
    data.reserve(rows.size() + 1);
    data.append({"Part Name", "Part No", "Stock",
                 "Department", "Prepared", "Approved", "Vendor Name",
                 "Date", "Unit Price"});

    for (const QVariantMap &r : rows) {
        QVector<QVariant> row(9);
        for (int c = 0; c < 9; ++c) {
            QVariant v = r.value(QLatin1String(kStockDbColumns[c]));
            // Keep empty cells empty instead of showing 0s.
            if (!v.isNull() && v.toString() != "")
                row[c] = v;
        }
        data.append(row);
    }

    m_model->setExcelData(data);
    setUnsavedChanges(false);
    qDebug() << "Loaded" << rows.size() << "stock rows from database";
    return true;
}

void ExcelHandler::saveStockToDb()
{
    if (!m_db || !m_db->isConnected()) return;

    QVector<QVariantMap> rows;
    const int rowCount = m_model->rowCount();
    for (int r = 1; r < rowCount; ++r) {           // skip header row
        QVariantMap row;
        bool empty = true;
        for (int c = 0; c < 9; ++c) {
            QVariant v = m_model->getData(r, c);
            if (!v.toString().trimmed().isEmpty()) empty = false;
            row[QLatin1String(kStockDbColumns[c])] = v.toString().isEmpty() ? QVariant(QString()) : v;
        }
        if (!empty) rows.append(row);
    }

    m_db->replaceAll("stock_rows", rows);
}

bool ExcelHandler::importStockFile(const QString &filePath)
{
    // Loads the user's stock xlsx (with the usual normalisation and legacy
    // column migration) and stores it as the shared stock in the database.
    if (!loadExcel(filePath))
        return false;

    saveStockToDb();
    setUnsavedChanges(false);
    emit lowStockCountChanged();
    qDebug() << "Imported stock file into database:" << filePath;
    return true;
}

void ExcelHandler::loadPOItems()
{
    m_poItems.clear();
    if (!m_db) return;
    m_poItems = dbRowsToApp(kPoItemFields, m_db->selectAll("po_items", "id"));

    // Keep header aggregates (qty/total/received/item count) in sync with
    // the lines so the PO list always reflects the shared database.
    for (QVariantMap &po : m_purchaseOrders)
        recalcPOHeader(po);
}

void ExcelHandler::recalcPOHeader(QVariantMap &po)
{
    const QString poNo = po["poNo"].toString();
    int count = 0, totalQty = 0, totalReceived = 0;
    double totalAmount = 0.0;
    QString firstPart, firstPartNo, firstDept;
    QStringList vendors;

    for (const QVariantMap &line : m_poItems) {
        if (line["poNo"].toString() != poNo) continue;
        if (count == 0) {
            firstPart = line["partName"].toString();
            firstPartNo = line["partNo"].toString();
            firstDept = line["department"].toString();
        }
        ++count;
        totalQty += line["qty"].toInt();
        totalReceived += line["receivedQty"].toInt();
        totalAmount += line["totalAmount"].toDouble();
        const QString vendor = line["vendor"].toString().trimmed();
        if (!vendor.isEmpty() && !vendors.contains(vendor))
            vendors << vendor;
    }

    if (count == 0) return;   // header-only PO (should not happen post-migration)

    po["itemCount"] = count;
    po["qty"] = totalQty;
    po["receivedQty"] = totalReceived;
    po["totalAmount"] = totalAmount;
    po["partName"] = (count == 1) ? firstPart
                                  : firstPart + " +" + QString::number(count - 1) + " more";
    po["partNo"] = (count == 1) ? firstPartNo : QString();
    po["department"] = (count == 1) ? firstDept : QString();
    po["vendor"] = vendors.join(", ");
    if (count > 1)
        po["unitPrice"] = 0.0;   // meaningless across mixed lines
}

bool ExcelHandler::resolvePOLine(QVariantMap &line)
{
    const QString partName = line["partName"].toString().trimmed();
    if (partName.isEmpty()) {
        emit errorOccurred("Part Name is required for every PO item");
        return false;
    }
    if (line["qty"].toInt() <= 0) {
        emit errorOccurred("Quantity must be greater than 0 for: " + partName);
        return false;
    }

    // Fill blanks from the item master (matching the old single-item logic).
    for (const auto &item : m_itemMaster) {
        if (item["partName"].toString().trimmed().compare(partName, Qt::CaseInsensitive) == 0) {
            if (line["partNo"].toString().trimmed().isEmpty())
                line["partNo"] = item["partNo"].toString().trimmed();
            if (line["department"].toString().trimmed().isEmpty())
                line["department"] = item["department"].toString().trimmed();
            if (line["vendor"].toString().trimmed().isEmpty())
                line["vendor"] = item["vendor"].toString().trimmed();
            if (line["unitPrice"].toDouble() <= 0.0)
                line["unitPrice"] = item["unitPrice"].toDouble();
            break;
        }
    }

    if (line["vendor"].toString().trimmed().isEmpty()) {
        emit errorOccurred("Vendor is required for: " + partName);
        return false;
    }

    line["partName"] = partName;
    line["totalAmount"] = line["qty"].toInt() * line["unitPrice"].toDouble();
    line["receivedQty"] = 0;
    return true;
}

// ===================== PRINTABLE PURCHASE ORDER ======================

QVariantMap ExcelHandler::getCompanyProfile() const
{
    QSettings settings("EinsteinRobotics", "StockManager");
    settings.beginGroup("company");
    QVariantMap p;
    p["name"]         = settings.value("name", "Enstein Robots and Automations Pvt Limited");
    p["addressLine1"] = settings.value("addressLine1", "");
    p["addressLine2"] = settings.value("addressLine2", "");
    p["city"]         = settings.value("city", "");
    p["phone"]        = settings.value("phone", "");
    p["email"]        = settings.value("email", "");
    p["website"]      = settings.value("website", "");
    p["gstin"]        = settings.value("gstin", "");
    settings.endGroup();
    return p;
}

bool ExcelHandler::saveCompanyProfile(const QVariantMap &profile)
{
    QSettings settings("EinsteinRobotics", "StockManager");
    settings.beginGroup("company");
    for (const QString &key : {"name", "addressLine1", "addressLine2", "city",
                               "phone", "email", "website", "gstin"}) {
        settings.setValue(key, profile.value(key).toString().trimmed());
    }
    settings.endGroup();
    settings.sync();
    return settings.status() == QSettings::NoError;
}

QString ExcelHandler::buildPOHtml(const QString &poNo, const QString &comments) const
{
    QVariantMap po;
    for (const auto &row : m_purchaseOrders) {
        if (row["poNo"].toString() == poNo) { po = row; break; }
    }
    if (po.isEmpty())
        return QString();

    QVariantList items;
    QSet<QString> vendorNames;
    for (const auto &line : m_poItems) {
        if (line["poNo"].toString() != poNo) continue;
        items.append(line);
        const QString v = line["vendor"].toString().trimmed();
        if (!v.isEmpty()) vendorNames.insert(v);
    }

    // A PO raised against a single vendor gets that vendor's full address
    // block; a mixed-vendor order can only sensibly list the names.
    QVariantMap vendor;
    if (vendorNames.size() == 1) {
        const QString only = *vendorNames.constBegin();
        for (const auto &v : m_vendors) {
            if (v["vendorName"].toString().compare(only, Qt::CaseInsensitive) == 0) {
                vendor = v;
                break;
            }
        }
        if (vendor.isEmpty()) vendor["vendorName"] = only;
    } else if (!vendorNames.isEmpty()) {
        QStringList names(vendorNames.constBegin(), vendorNames.constEnd());
        names.sort();
        vendor["vendorName"] = names.join(", ");
    }

    return PoDocument::buildHtml(getCompanyProfile(), vendor, po, items, comments);
}

QString ExcelHandler::defaultPOPdfPath(const QString &poNo) const
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    return base + "/Enstein Stock Manager/Purchase Orders/" + poNo + ".pdf";
}

QVariantMap ExcelHandler::generatePOPreview(const QString &poNo, const QString &comments)
{
    const QString html = buildPOHtml(poNo, comments);
    if (html.isEmpty()) {
        emit errorOccurred("Purchase order not found: " + poNo);
        return QVariantMap();
    }

    // A per-PO scratch folder, wiped first so a re-preview never shows pages
    // left over from an earlier render.
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                        + "/EnsteinStockManager/po-preview/" + poNo;
    QDir(dir).removeRecursively();
    QDir().mkpath(dir);

    const QString pdfPath = dir + "/" + poNo + ".pdf";
    if (!PoDocument::writePdf(html, pdfPath)) {
        emit errorOccurred("Could not render the purchase order PDF");
        return QVariantMap();
    }

    QStringList pageUrls;
    for (const QString &f : PoDocument::renderPages(html, dir))
        pageUrls << QUrl::fromLocalFile(f).toString();

    QVariantMap result;
    result["poNo"]    = poNo;
    result["pdfPath"] = pdfPath;
    result["pages"]   = pageUrls;
    return result;
}

QString ExcelHandler::savePOPdf(const QString &poNo, const QString &destPath,
                                const QString &comments)
{
    const QString html = buildPOHtml(poNo, comments);
    if (html.isEmpty()) {
        emit errorOccurred("Purchase order not found: " + poNo);
        return QString();
    }

    QString target = destPath.trimmed();
    if (target.startsWith("file://"))
        target = QUrl(target).toLocalFile();
    if (target.isEmpty())
        target = defaultPOPdfPath(poNo);
    if (!target.endsWith(".pdf", Qt::CaseInsensitive))
        target += ".pdf";

    if (!PoDocument::writePdf(html, target)) {
        emit errorOccurred("Could not save the purchase order to " + target);
        return QString();
    }
    return target;
}

bool ExcelHandler::openInSystemViewer(const QString &path)
{
    QString local = path.trimmed();
    if (local.startsWith("file://"))
        local = QUrl(local).toLocalFile();
    if (!QFile::exists(local))
        return false;
    return QDesktopServices::openUrl(QUrl::fromLocalFile(local));
}

QString ExcelHandler::getNextPONumber()
{
    int next = m_db ? m_db->peekCounter("po") : m_nextPONumber;
    return "PO-" + QString::number(next).rightJustified(4, '0');
}

QString ExcelHandler::createPurchaseOrderItems(const QVariantList &items,
                                               const QString &expectedDate,
                                               const QString &preparedBy)
{
    if (items.isEmpty()) {
        emit errorOccurred("Add at least one item to the purchase order");
        return "";
    }

    // Validate and resolve every line BEFORE anything is written.
    QVector<QVariantMap> lines;
    for (const QVariant &v : items) {
        QVariantMap line = v.toMap();
        if (!resolvePOLine(line))
            return "";
        lines.append(line);
    }

    const QString resolvedPreparedBy =
        preparedBy.trimmed().isEmpty() ? m_currentUser : preparedBy.trimmed();

    // Atomic, shared PO number so concurrent users never collide.
    int poSeq = m_db ? m_db->nextCounter("po") : m_nextPONumber++;
    QString poNo = "PO-" + QString::number(poSeq).rightJustified(4, '0');

    // Header (aggregates recomputed from lines by recalcPOHeader).
    QVariantMap po;
    po["poNo"]         = poNo;
    po["date"]         = QDateTime::currentDateTime().toString("yyyy-MM-dd");
    po["vendor"]       = "";
    po["partName"]     = "";
    po["partNo"]       = "";
    po["department"]   = "";
    po["qty"]          = 0;
    po["unitPrice"]    = 0.0;
    po["totalAmount"]  = 0.0;
    po["expectedDate"] = expectedDate;
    po["status"]       = "Draft";
    po["receivedQty"]  = 0;
    po["preparedBy"]   = resolvedPreparedBy;
    po["approvedBy"]   = "";
    po["receivedBy"]   = "";
    po["receivedDate"] = "";

    // Persist lines first (insert without id so the serial is assigned),
    // then reload to pick up the generated ids.
    for (QVariantMap &line : lines) {
        line["poNo"] = poNo;
        QVariantMap dbRow = appRowToDb(kPoItemFields, line);
        dbRow.remove("id");
        if (m_db) m_db->insert("po_items", dbRow);
    }
    if (m_db) m_poItems = dbRowsToApp(kPoItemFields, m_db->selectAll("po_items", "id"));

    recalcPOHeader(po);
    m_purchaseOrders.append(po);
    savePurchaseOrders();
    emit pendingPOCountChanged();
    emit lowStockCountChanged();   // new open orders reduce the shortage list
    emit purchaseOrderCreated(poNo);

    for (const QVariantMap &line : lines) {
        logStockMovement(line["partName"].toString(), line["partNo"].toString(),
                         "PO_CREATED", line["qty"].toInt(), poNo, m_currentUser);
    }

    qDebug() << "Created PO:" << poNo << "with" << lines.size() << "items";
    return poNo;
}

QVariantList ExcelHandler::getPOItems(const QString &poNo)
{
    QVariantList list;
    for (const auto &line : m_poItems) {
        if (line["poNo"].toString() == poNo)
            list.append(line);
    }
    return list;
}

QString ExcelHandler::createPurchaseOrder(const QString &vendor,
                                          const QString &partName,
                                          const QString &partNo,
                                          int qty, double unitPrice,
                                          const QString &expectedDate,
                                          const QString &department,
                                          const QString &preparedBy)
{
    QVariantMap line;
    line["partName"]   = partName;
    line["partNo"]     = partNo;
    line["vendor"]     = vendor;
    line["department"] = department;
    line["qty"]        = qty;
    line["unitPrice"]  = unitPrice;
    return createPurchaseOrderItems({line}, expectedDate, preparedBy);
}

bool ExcelHandler::sendPOForApproval(const QString &poNo, const QString &approvedBy)
{
    QString approver = approvedBy.trimmed();
    if (approver.isEmpty()) {
        emit errorOccurred("Approved By name is required");
        return false;
    }

    for (auto &po : m_purchaseOrders) {
        if (po["poNo"].toString() == poNo) {
            QString status = po["status"].toString().toLower();
            if (status != "draft") {
                emit errorOccurred("Only Draft PO can be sent");
                return false;
            }

            po["status"] = "Sent";
            po["approvedBy"] = approver;
            savePurchaseOrders();
            emit pendingPOCountChanged();
            return true;
        }
    }

    emit errorOccurred("PO not found: " + poNo);
    return false;
}

QVariantList ExcelHandler::getPOList(const QString &statusFilter)
{
    QVariantList list;
    for (const auto &po : m_purchaseOrders) {
        if (statusFilter.isEmpty() ||
            po["status"].toString().toLower() == statusFilter.toLower()) {
            list.append(po);
        }
    }
    return list;
}

bool ExcelHandler::updatePOStatus(const QString &poNo, const QString &newStatus)
{
    for (auto &po : m_purchaseOrders) {
        if (po["poNo"].toString() == poNo) {
            po["status"] = newStatus;
            savePurchaseOrders();
            emit pendingPOCountChanged();
            qDebug() << "PO" << poNo << "status ->" << newStatus;
            return true;
        }
    }
    emit errorOccurred("PO not found: " + poNo);
    return false;
}

bool ExcelHandler::updatePurchaseOrder(const QString &poNo, const QVariantMap &poDetails)
{
    for (auto &po : m_purchaseOrders) {
        if (po["poNo"].toString() != poNo) continue;

        QString status = po["status"].toString().toLower();
        if (status == "received" || status == "closed" || status == "cancelled") {
            emit errorOccurred("Cannot edit PO in status: " + po["status"].toString());
            return false;
        }

        QString vendor = poDetails.value("vendor", po["vendor"]).toString().trimmed();
        QString partName = poDetails.value("partName", po["partName"]).toString().trimmed();
        QString partNo = poDetails.value("partNo", po["partNo"]).toString().trimmed();
        QString department = poDetails.value("department", po["department"]).toString().trimmed();
        QString expectedDate = poDetails.value("expectedDate", po["expectedDate"]).toString().trimmed();
        QString preparedBy = poDetails.value("preparedBy", po["preparedBy"]).toString().trimmed();
        int qty = poDetails.value("qty", po["qty"]).toInt();
        double unitPrice = poDetails.value("unitPrice", po["unitPrice"]).toDouble();

        if (vendor.isEmpty() || partName.isEmpty()) {
            emit errorOccurred("Vendor and Part Name are required");
            return false;
        }
        if (qty <= 0) {
            emit errorOccurred("Quantity must be greater than 0");
            return false;
        }

        po["expectedDate"] = expectedDate;
        po["preparedBy"] = preparedBy;

        // Sync the line item when this PO has exactly one (the edit dialog
        // is only offered for single-item POs).
        QVector<QVariantMap *> poLines;
        for (auto &line : m_poItems)
            if (line["poNo"].toString() == poNo) poLines.append(&line);

        if (poLines.size() == 1) {
            QVariantMap &line = *poLines.first();
            line["vendor"] = vendor;
            line["partName"] = partName;
            line["partNo"] = partNo;
            line["department"] = department;
            line["qty"] = qty;
            line["unitPrice"] = unitPrice;
            line["totalAmount"] = qty * unitPrice;
            if (m_db) {
                QVariantMap dbRow = appRowToDb(kPoItemFields, line);
                m_db->upsert("po_items", {"id"}, dbRow);
            }
        }
        recalcPOHeader(po);

        savePurchaseOrders();
        emit pendingPOCountChanged();
        return true;
    }

    emit errorOccurred("PO not found: " + poNo);
    return false;
}

QVariantMap ExcelHandler::getPOByNumber(const QString &poNo)
{
    for (const auto &po : m_purchaseOrders) {
        if (po["poNo"].toString() == poNo) return po;
    }
    return QVariantMap();
}

int ExcelHandler::pendingPOCount() const
{
    int count = 0;
    for (const auto &po : m_purchaseOrders) {
        QString status = po["status"].toString().toLower();
        if (status == "draft" || status == "sent" || status == "partially received") {
            count++;
        }
    }
    return count;
}

// ==================== GOODS RECEIPT NOTE (GRN) ====================

void ExcelHandler::loadGRNRecords()
{
    m_grnRecords.clear();
    if (!m_db) return;
    m_grnRecords = dbRowsToApp(kGrnFields, m_db->selectAll("grn_records", "grn_no"));
    qDebug() << "Loaded" << m_grnRecords.size() << "GRN records";
}

void ExcelHandler::saveGRNRecords()
{
    if (!m_db) return;
    m_db->replaceAll("grn_records", appRowsToDb(kGrnFields, m_grnRecords));
}

QString ExcelHandler::receiveGoodsForItem(int itemId,
                                          int receivedQty, int acceptedQty,
                                          int rejectedQty, const QString &remarks,
                                          const QString &receivedBy)
{
    // Find the PO line item.
    QVariantMap *line = nullptr;
    for (auto &item : m_poItems) {
        if (item["id"].toInt() == itemId) {
            line = &item;
            break;
        }
    }
    if (!line) {
        emit errorOccurred("PO item not found (id " + QString::number(itemId) + ")");
        return "";
    }

    const QString poNo = line->value("poNo").toString();

    // Find the PO header.
    QVariantMap *targetPO = nullptr;
    for (auto &po : m_purchaseOrders) {
        if (po["poNo"].toString() == poNo) {
            targetPO = &po;
            break;
        }
    }
    if (!targetPO) {
        emit errorOccurred("Purchase Order not found: " + poNo);
        return "";
    }

    QString status = targetPO->value("status").toString().toLower();
    if (status == "closed" || status == "cancelled") {
        emit errorOccurred("Cannot receive against a " + status + " PO");
        return "";
    }

    if (receivedQty <= 0) {
        emit errorOccurred("Received quantity must be greater than 0");
        return "";
    }

    QString receiverName = receivedBy.trimmed().isEmpty() ? m_currentUser : receivedBy.trimmed();

    // Generate GRN number (atomic, shared)
    int grnSeq = m_db ? m_db->nextCounter("grn") : m_nextGRNNumber++;
    QString grnNo = "GRN-" + QString::number(grnSeq).rightJustified(4, '0');

    const QString partName = line->value("partName").toString();
    const QString partNo = line->value("partNo").toString();

    // Create GRN record for this line.
    QVariantMap grn;
    grn["grnNo"]       = grnNo;
    grn["poNo"]        = poNo;
    grn["date"]        = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm");
    grn["partName"]    = partName;
    grn["receivedQty"] = receivedQty;
    grn["acceptedQty"] = acceptedQty;
    grn["rejectedQty"] = rejectedQty;
    grn["remarks"]     = remarks;
    grn["receivedBy"]  = receiverName;

    m_grnRecords.append(grn);
    saveGRNRecords();

    // Update the line's received quantity (in memory and in the database).
    (*line)["receivedQty"] = line->value("receivedQty").toInt() + receivedQty;
    if (m_db) {
        QVariantMap upd;
        upd["id"] = itemId;
        upd["received_qty"] = line->value("receivedQty").toInt();
        m_db->upsert("po_items", {"id"}, upd);
    }

    // Recompute the header from all lines: Received only when every line is
    // fully received, otherwise Partially Received.
    recalcPOHeader(*targetPO);
    bool allReceived = true;
    for (const auto &item : m_poItems) {
        if (item["poNo"].toString() != poNo) continue;
        if (item["receivedQty"].toInt() < item["qty"].toInt()) {
            allReceived = false;
            break;
        }
    }
    (*targetPO)["status"] = allReceived ? "Received" : "Partially Received";
    (*targetPO)["receivedBy"] = receiverName;
    (*targetPO)["receivedDate"] = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm");

    savePurchaseOrders();
    emit pendingPOCountChanged();

    // Update stock in main table (add accepted quantity). Stock column = 2.
    int partRow = findPartRowByName(partName);
    QString lineDepartment = line->value("department").toString().trimmed();
    QString poPreparedBy = targetPO->value("preparedBy").toString().trimmed();
    QString poApprovedBy = targetPO->value("approvedBy").toString().trimmed();
    QString lineVendor = line->value("vendor").toString().trimmed();
    double lineUnitPrice = line->value("unitPrice").toDouble();
    QString receivedDate = (*targetPO)["receivedDate"].toString();

    if (partRow != -1) {
        int currentStock = toStockInt(m_model->getData(partRow, 2));
        m_model->setDataAt(partRow, 2, currentStock + acceptedQty);

        // 3=Department, 4=Prepared, 5=Approved, 6=Vendor, 7=Date, 8=Unit Price
        if (!lineDepartment.isEmpty()) m_model->setDataAt(partRow, 3, lineDepartment);
        if (!poPreparedBy.isEmpty()) m_model->setDataAt(partRow, 4, poPreparedBy);
        if (!poApprovedBy.isEmpty()) m_model->setDataAt(partRow, 5, poApprovedBy);
        if (!lineVendor.isEmpty()) m_model->setDataAt(partRow, 6, lineVendor);
        if (!receivedDate.isEmpty()) m_model->setDataAt(partRow, 7, receivedDate);
        if (lineUnitPrice > 0.0) m_model->setDataAt(partRow, 8, lineUnitPrice);

        qDebug() << "Stock updated:" << partName << currentStock << "->" << (currentStock + acceptedQty);
    } else {
        // Part not found in stock table - add new row
        m_model->addRow();
        int newRow = m_model->rowCount() - 1;
        m_model->setDataAt(newRow, 0, partName);
        m_model->setDataAt(newRow, 1, partNo);
        m_model->setDataAt(newRow, 2, acceptedQty);
        m_model->setDataAt(newRow, 3, lineDepartment);
        m_model->setDataAt(newRow, 4, poPreparedBy);
        m_model->setDataAt(newRow, 5, poApprovedBy);
        m_model->setDataAt(newRow, 6, lineVendor);
        m_model->setDataAt(newRow, 7, receivedDate);
        if (lineUnitPrice > 0.0) m_model->setDataAt(newRow, 8, lineUnitPrice);

        qDebug() << "New part added to stock:" << partName << "qty:" << acceptedQty;
    }

    // Log stock movement
    logStockMovement(partName, partNo, "IN", acceptedQty, grnNo + " (from " + poNo + ")", receiverName);

    if (rejectedQty > 0) {
        logStockMovement(partName, partNo, "REJECTED", rejectedQty, grnNo, receiverName);
    }

    // Persist the updated stock (database is the permanent store).
    saveStockToDb();
    if (!m_permanentFile.isEmpty()) {
        saveToPermanent();
    }

    emit goodsReceived(grnNo, poNo);
    emit lowStockCountChanged();

    qDebug() << "GRN" << grnNo << "for PO" << poNo << "item" << partName
             << "| Accepted:" << acceptedQty << "Rejected:" << rejectedQty;

    return grnNo;
}

QString ExcelHandler::receiveGoods(const QString &poNo,
                                   int receivedQty, int acceptedQty,
                                   int rejectedQty, const QString &remarks,
                                   const QString &receivedBy)
{
    // Legacy entry point: receive against the first line that is still open.
    int itemId = -1;
    for (const auto &line : m_poItems) {
        if (line["poNo"].toString() != poNo) continue;
        if (itemId == -1) itemId = line["id"].toInt();
        if (line["receivedQty"].toInt() < line["qty"].toInt()) {
            itemId = line["id"].toInt();
            break;
        }
    }
    if (itemId == -1) {
        emit errorOccurred("No items found for PO: " + poNo);
        return "";
    }
    return receiveGoodsForItem(itemId, receivedQty, acceptedQty, rejectedQty, remarks, receivedBy);
}

QVariantList ExcelHandler::getGRNList()
{
    QVariantList list;
    for (const auto &grn : m_grnRecords) {
        list.append(grn);
    }
    return list;
}

// ==================== STOCK MOVEMENT LOG ====================

void ExcelHandler::loadStockMovements()
{
    m_stockMovements.clear();
    if (!m_db) return;
    m_stockMovements = dbRowsToApp(kMovementFields, m_db->selectAll("stock_movements", "id"));
    qDebug() << "Loaded" << m_stockMovements.size() << "stock movements";
}

void ExcelHandler::saveStockMovements()
{
    // The movement log is append-only; individual entries are inserted by
    // logStockMovement(). A full rewrite is only used as a fallback.
    if (!m_db) return;
    m_db->replaceAll("stock_movements", appRowsToDb(kMovementFields, m_stockMovements));
}

bool ExcelHandler::logStockMovement(const QString &partName, const QString &partNo,
                                    const QString &movementType, int qty,
                                    const QString &reference, const QString &doneBy)
{
    QVariantMap mov;
    mov["date"]      = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss");
    mov["partName"]  = partName;
    mov["partNo"]    = partNo;
    mov["type"]      = movementType;
    mov["qty"]       = qty;
    mov["reference"] = reference;
    mov["doneBy"]    = doneBy;

    m_stockMovements.append(mov);
    if (m_db) m_db->insert("stock_movements", appRowToDb(kMovementFields, mov));
    emit movementLogged(partName, movementType, qty);

    return true;
}

QVariantList ExcelHandler::getStockMovements(const QString &partNameFilter)
{
    QVariantList list;
    for (const auto &mov : m_stockMovements) {
        if (partNameFilter.isEmpty() ||
            mov["partName"].toString().toLower().contains(partNameFilter.toLower())) {
            list.append(mov);
        }
    }
    return list;
}

QVariantList ExcelHandler::getAllMovements()
{
    QVariantList list;
    // Return in reverse order (newest first)
    for (int i = m_stockMovements.size() - 1; i >= 0; --i) {
        list.append(m_stockMovements[i]);
    }
    return list;
}

// ==================== MATERIAL ISSUE ====================

void ExcelHandler::loadIssueNotes()
{
    m_issueNotes.clear();
    if (!m_db) return;
    m_issueNotes = dbRowsToApp(kIssueFields, m_db->selectAll("issue_notes", "issue_no"));
    qDebug() << "Loaded" << m_issueNotes.size() << "issue notes";
}

void ExcelHandler::saveIssueNotes()
{
    if (!m_db) return;
    m_db->replaceAll("issue_notes", appRowsToDb(kIssueFields, m_issueNotes));
}

QString ExcelHandler::issueMultipleStock(const QVariantList &items,
                                         const QString &department,
                                         const QString &issuedBy)
{
    if (items.isEmpty()) {
        emit errorOccurred("Add at least one part to issue");
        return "";
    }
    if (department.trimmed().isEmpty()) {
        emit errorOccurred("Department is required");
        return "";
    }

    // Validate ALL lines before touching any stock (all-or-nothing).
    struct IssueLine { int row; QString partName; int qty; };
    QVector<IssueLine> lines;
    for (const QVariant &v : items) {
        const QVariantMap item = v.toMap();
        const QString partName = item["partName"].toString().trimmed();
        const int qty = item["qty"].toInt();

        if (partName.isEmpty()) {
            emit errorOccurred("Part name is required for every issue line");
            return "";
        }
        if (qty <= 0) {
            emit errorOccurred("Quantity must be greater than 0 for: " + partName);
            return "";
        }
        int partRow = findPartRowByName(partName);
        if (partRow == -1) {
            emit errorOccurred("Part not found in stock: " + partName);
            return "";
        }
        int currentStock = toStockInt(m_model->getData(partRow, 2));
        // Account for earlier lines of this same request drawing on one part.
        for (const IssueLine &prev : lines)
            if (prev.row == partRow) currentStock -= prev.qty;
        if (currentStock < qty) {
            emit errorOccurred("Insufficient stock for " + partName +
                               "! Available: " + QString::number(currentStock) +
                               ", Requested: " + QString::number(qty));
            return "";
        }
        lines.append({partRow, partName, qty});
    }

    // Generate one issue number (atomic, shared) for the whole note.
    int issSeq = m_db ? m_db->nextCounter("iss") : m_nextIssueNumber++;
    QString issueNo = "ISS-" + QString::number(issSeq).rightJustified(4, '0');
    const QString stamp = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm");

    for (const IssueLine &line : lines) {
        // Deduct stock
        int currentStock = toStockInt(m_model->getData(line.row, 2));
        m_model->setDataAt(line.row, 2, currentStock - line.qty);

        // Record the issue line (append-only insert; one issue number can
        // hold several lines in the v2 schema).
        QVariantMap note;
        note["issueNo"]    = issueNo;
        note["date"]       = stamp;
        note["partName"]   = line.partName;
        note["qty"]        = line.qty;
        note["department"] = department;
        note["issuedBy"]   = issuedBy;
        m_issueNotes.append(note);
        if (m_db) m_db->insert("issue_notes", appRowToDb(kIssueFields, note));

        // Log movement
        QString partNo = m_model->getData(line.row, 1).toString();
        logStockMovement(line.partName, partNo, "OUT", line.qty,
                         issueNo + " -> " + department, issuedBy);

        emit stockIssued(issueNo, line.partName, line.qty);
        qDebug() << "Issued:" << line.partName << "x" << line.qty
                 << "to" << department << "(" << issueNo << ")";
    }

    // Persist the updated stock (database is the permanent store).
    saveStockToDb();
    if (!m_permanentFile.isEmpty()) {
        saveToPermanent();     
    }
    emit lowStockCountChanged();

    return issueNo;
}

QString ExcelHandler::issueStock(const QString &partName, int qty,
                                 const QString &department, const QString &issuedBy)
{
    QVariantMap item;
    item["partName"] = partName;
    item["qty"] = qty;
    return issueMultipleStock({item}, department, issuedBy);
}

QVariantList ExcelHandler::getIssueNotes()
{
    QVariantList list;
    for (int i = m_issueNotes.size() - 1; i >= 0; --i) {
        list.append(m_issueNotes[i]);
    }
    return list;
}

// ==================== LOW STOCK ALERTS ====================

QVariantList ExcelHandler::getLowStockItems()
{
    QVariantList list;

    // Quantity already on order per part (open POs only) so the same
    // shortage is not ordered twice.
    QSet<QString> openPOs;
    for (const auto &po : m_purchaseOrders) {
        const QString st = po["status"].toString().toLower();
        if (st == "draft" || st == "sent" || st == "partially received")
            openPOs.insert(po["poNo"].toString());
    }
    QHash<QString, int> onOrder;
    for (const auto &line : m_poItems) {
        if (!openPOs.contains(line["poNo"].toString())) continue;
        int remaining = line["qty"].toInt() - line["receivedQty"].toInt();
        if (remaining > 0)
            onOrder[line["partName"].toString().trimmed().toLower()] += remaining;
    }

    // An item is low when current stock plus open orders cannot cover the
    // required quantity defined in the Item Master.
    for (const auto &item : m_itemMaster) {
        const int required = item["requiredQty"].toInt();
        if (required <= 0) continue;
        const QString partName = item["partName"].toString().trimmed();
        if (partName.isEmpty()) continue;

        int stock = 0;
        int row = findPartRowByName(partName);
        if (row != -1) stock = toStockInt(m_model->getData(row, 2));

        const int ordered = onOrder.value(partName.toLower(), 0);
        if (stock + ordered >= required) continue;

        QVariantMap e;
        e["partName"]    = partName;
        e["partNo"]      = item["partNo"];
        e["stock"]       = stock;
        e["requiredQty"] = required;
        e["onOrder"]     = ordered;
        e["shortage"]    = required - stock - ordered;
        e["vendor"]      = item["vendor"];
        e["unitPrice"]   = item["unitPrice"].toDouble();
        list.append(e);
    }
    return list;
}

int ExcelHandler::lowStockCount()
{
    return getLowStockItems().size();
}

bool ExcelHandler::autoGeneratePOForLowStock()
{
    const QVariantList low = getLowStockItems();
    if (low.isEmpty()) {
        emit errorOccurred("No low stock items to order");
        return false;
    }

    // One multi-item PO covering every shortage; each line uses the part's
    // preferred vendor from the Item Master.
    QVariantList items;
    QStringList skipped;
    for (const QVariant &v : low) {
        const QVariantMap e = v.toMap();
        if (e["vendor"].toString().trimmed().isEmpty()) {
            skipped << e["partName"].toString();
            continue;
        }
        QVariantMap line;
        line["partName"]  = e["partName"];
        line["partNo"]    = e["partNo"];
        line["vendor"]    = e["vendor"];
        line["qty"]       = e["shortage"];
        line["unitPrice"] = e["unitPrice"];
        items.append(line);
    }

    if (items.isEmpty()) {
        emit errorOccurred("Low stock items have no preferred vendor in Item Master: " +
                           skipped.join(", "));
        return false;
    }

    const QString expected = QDateTime::currentDateTime().addDays(7).toString("yyyy-MM-dd");
    const QString poNo = createPurchaseOrderItems(items, expected, m_currentUser);
    if (poNo.isEmpty()) return false;

    if (!skipped.isEmpty())
        emit errorOccurred("PO " + poNo + " created. Skipped (no vendor in Item Master): " +
                           skipped.join(", "));

    qDebug() << "Auto-generated" << poNo << "for" << items.size() << "low stock items";
    return true;
}

// ==================== Helper: Find Part Row ====================

int ExcelHandler::findPartRowByName(const QString &partName)
{
    int rows = m_model->rowCount();
    QString search = partName.trimmed().toLower();

    for (int row = 1; row < rows; ++row) {
        QString existing = m_model->getData(row, 0).toString().trimmed().toLower();
        if (existing == search) {
            return row;
        }
    }
    return -1;
}

// ==================== EXISTING METHODS (kept intact with column adjustments) ====================

void ExcelHandler::savePermanentFileSettings()
{
    QSettings settings("EinsteinRobotics", "StockManager");
    settings.setValue("permanentFile", m_permanentFile);
}

void ExcelHandler::loadPermanentFileSettings()
{
    QSettings settings("EinsteinRobotics", "StockManager");
    QString savedPath = settings.value("permanentFile", "").toString();

    if (!savedPath.isEmpty() && QFileInfo::exists(savedPath)) {
        QFileInfo fileInfo(savedPath);
        QString suffix = fileInfo.suffix().toLower();
        if (suffix == "xlsx" || suffix == "xls") {
            m_permanentFile = savedPath;
            emit permanentFileChanged();
        } else {
            m_permanentFile = "";
            savePermanentFileSettings();
        }
    }
}

QString ExcelHandler::getSavedPermanentPath()
{
    return m_permanentFile;
}

bool ExcelHandler::hasSavedPermanentFile()
{
    return !m_permanentFile.isEmpty() && QFileInfo::exists(m_permanentFile);
}

bool ExcelHandler::setPermanentFile(const QString &filePath)
{
    QString cleanPath = cleanFilePath(filePath);
    QFileInfo fileInfo(cleanPath);

    if (!fileInfo.exists()) {
        emit errorOccurred("File does not exist: " + cleanPath);
        return false;
    }

    QString suffix = fileInfo.suffix().toLower();
    if (suffix != "xlsx" && suffix != "xls") {
        emit errorOccurred("Permanent file must be Excel format (.xlsx or .xls)");
        return false;
    }

    m_permanentFile = cleanPath;
    m_currentFile = cleanPath;
    savePermanentFileSettings();
    emit permanentFileChanged();
    emit currentFileChanged();
    updateAutoSyncState();

    return true;
}

bool ExcelHandler::loadPermanentFile()
{
    if (m_permanentFile.isEmpty()) {
        emit errorOccurred("No permanent file set");
        return false;
    }

    QFileInfo fileInfo(m_permanentFile);
    if (!fileInfo.exists()) {
        m_permanentFile = "";
        savePermanentFileSettings();
        emit permanentFileChanged();
        emit errorOccurred("Permanent file not found");
        return false;
    }

    return loadExcel(m_permanentFile);
}

bool ExcelHandler::saveToPermanent()
{
    if (m_permanentFile.isEmpty()) {
        emit errorOccurred("No permanent file set");
        return false;
    }
    return saveExcel(m_permanentFile);
}

int ExcelHandler::findPartByName(const QString &partName)
{
    return findPartRowByName(partName);
}

bool ExcelHandler::updateExistingPart(int row, const QVector<QVariant> &mergeData)
{
    int currentStock = toStockInt(m_model->getData(row, 2));
    int purchaseQty = mergeData.size() > 2 ? toStockInt(mergeData[2]) : 0;
    int newStock = currentStock + purchaseQty;

    m_model->setDataAt(row, 2, newStock);

    if (mergeData.size() > 1 && !mergeData[1].toString().trimmed().isEmpty())
        m_model->setDataAt(row, 1, mergeData[1]);
    if (mergeData.size() > 3 && !mergeData[3].toString().trimmed().isEmpty())
        m_model->setDataAt(row, 3, mergeData[3]);
    if (mergeData.size() > 4 && !mergeData[4].toString().trimmed().isEmpty())
        m_model->setDataAt(row, 4, mergeData[4]);
    if (mergeData.size() > 5 && !mergeData[5].toString().trimmed().isEmpty())
        m_model->setDataAt(row, 5, mergeData[5]);
    if (mergeData.size() > 6 && !mergeData[6].toString().trimmed().isEmpty())
        m_model->setDataAt(row, 6, mergeData[6]);

    return true;
}

bool ExcelHandler::appendFromFile(const QString &filePath)
{
    QString cleanPath = cleanFilePath(filePath);

    if (!validateFileStructure(cleanPath)) {
        emit errorOccurred("Only PURCHASE files can be merged into Stock files.");
        return false;
    }

    QXlsx::Document xlsx(cleanPath);
    if (!xlsx.load()) {
        emit errorOccurred("Failed to load file");
        return false;
    }

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) {
        emit errorOccurred("No worksheet found");
        return false;
    }

    QXlsx::CellRange range = sheet->dimension();
    int rowsAdded = 0, rowsUpdated = 0;
    QSet<QString> processedParts;

    for (int row = 2; row <= range.lastRow(); ++row) {
        QVector<QVariant> rowData;
        for (int col = 1; col <= 7; ++col) {
            auto cell = sheet->cellAt(row, col);
            rowData.append(cell ? cell->value() : QVariant());
        }

        QString partName = rowData.size() > 0 ? rowData[0].toString().trimmed() : "";
        if (partName.isEmpty()) continue;

        QString partNameLower = partName.toLower();
        if (processedParts.contains(partNameLower)) continue;
        processedParts.insert(partNameLower);

        int existingRow = findPartByName(partName);

        if (existingRow != -1) {
            updateExistingPart(existingRow, rowData);
            rowsUpdated++;
        } else {
            m_model->addRow();
            int newRow = m_model->rowCount() - 1;
            int purchaseQty = rowData.size() > 2 ? toStockInt(rowData[2]) : 0;

            m_model->setDataAt(newRow, 0, partName);
            m_model->setDataAt(newRow, 1, rowData.size() > 1 ? rowData[1] : QVariant());
            m_model->setDataAt(newRow, 2, purchaseQty);
            m_model->setDataAt(newRow, 3, rowData.size() > 3 ? rowData[3] : QVariant());
            m_model->setDataAt(newRow, 4, rowData.size() > 4 ? rowData[4] : QVariant());
            m_model->setDataAt(newRow, 5, rowData.size() > 5 ? rowData[5] : QVariant());
            m_model->setDataAt(newRow, 6, rowData.size() > 6 ? rowData[6] : QVariant());
            rowsAdded++;
        }

        // Log the movement
        QString partNo = rowData.size() > 1 ? rowData[1].toString() : "";
        int qty = rowData.size() > 2 ? toStockInt(rowData[2]) : 0;
        logStockMovement(partName, partNo, "IN", qty, "Merge: " + QFileInfo(cleanPath).fileName(), m_currentUser);
    }

    if (!m_permanentFile.isEmpty()) {
        saveToPermanent();
    }

    emit fileMerged(QFileInfo(cleanPath).fileName(), rowsAdded, rowsUpdated);
    emit lowStockCountChanged();
    return true;
}

bool ExcelHandler::appendStockFile(const QString &filePath)
{
    QString cleanPath = cleanFilePath(filePath);

    QXlsx::Document xlsx(cleanPath);
    if (!xlsx.load()) {
        emit errorOccurred("Failed to load file");
        return false;
    }

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) {
        emit errorOccurred("No worksheet found");
        return false;
    }

    QXlsx::CellRange range = sheet->dimension();
    int startRow = qMax(range.firstRow(), 1);
    int endRow = qMax(range.lastRow(), 1);
    int startCol = qMax(range.firstColumn(), 1);
    int endCol = qMin(qMax(range.lastColumn(), 1), 26);

    QVector<QVector<QVariant>> data;
    int consecutiveEmptyRows = 0;

    for (int row = startRow; row <= endRow; ++row) {
        QVector<QVariant> rowData;
        bool rowIsEmpty = true;
        int actualColumns = 0;

        for (int col = startCol; col <= endCol; ++col) {
            auto cell = sheet->cellAt(row, col);
            QVariant cellValue;
            if (cell && cell->value().isValid()) {
                cellValue = cell->value();
                if (!cellValue.toString().trimmed().isEmpty()) {
                    rowIsEmpty = false;
                    actualColumns = qMax(actualColumns, col - startCol + 1);
                }
            }
            rowData.append(cellValue);
        }

        if (row == startRow && !rowIsEmpty) {
            while (rowData.size() > actualColumns) rowData.removeLast();
        }

        if (rowIsEmpty && row > startRow) {
            consecutiveEmptyRows++;
            if (consecutiveEmptyRows >= 5) break;
            continue;
        } else if (!rowIsEmpty) {
            consecutiveEmptyRows = 0;
            if (row > startRow && !data.isEmpty()) {
                int headerCols = data[0].size();
                while (rowData.size() > headerCols) rowData.removeLast();
                while (rowData.size() < headerCols) rowData.append(QVariant());
            }
            data.append(rowData);
        }
    }

    if (!data.isEmpty()) {
        int maxCols = data[0].size();
        for (auto &row : data) {
            while (row.size() < maxCols) row.append(QVariant());
            while (row.size() > maxCols) row.removeLast();
        }
    }

    if (data.isEmpty()) {
        emit errorOccurred("No data found in Excel file");
        return false;
    }

    if (data[0].size() < 3 ||
        data[0][2].toString().trimmed().toLower() != "stock") {
        emit errorOccurred("Only STOCK files can be appended");
        return false;
    }

    // Normalize stock sheets to current 9-column layout.
    {
        auto normalizeHeader = [](const QVariant &value) {
            return value.toString().trimmed().toLower();
        };

        QHash<QString, int> headerColumns;
        for (int col = 0; col < data[0].size(); ++col) {
            QString header = normalizeHeader(data[0][col]);
            if (!header.isEmpty()) {
                headerColumns.insert(header, col);
            }
        }

        bool hasLegacyReorderColumns = headerColumns.contains("min stock") ||
                                       headerColumns.contains("reorder level") ||
                                       headerColumns.contains("reorder lvl") ||
                                       headerColumns.contains("reorder");
        bool hasDateColumn = headerColumns.contains("date");
        bool needsNormalization = data[0].size() != 9 || hasLegacyReorderColumns || !hasDateColumn;

        if (needsNormalization) {
            auto colIndex = [&headerColumns](const QString &header, int fallback) {
                return headerColumns.contains(header) ? headerColumns.value(header) : fallback;
            };
            auto cellValue = [](const QVector<QVariant> &row, int col) -> QVariant {
                if (col < 0 || col >= row.size()) return QVariant();
                return row[col];
            };

            int colPartName = colIndex("part name", 0);
            int colPartNo = colIndex("part no", 1);
            int colStock = colIndex("stock", 2);
            int colDepartment = colIndex("department", 3);
            int colPrepared = colIndex("prepared", 4);
            int colApproved = colIndex("approved", 5);
            int colVendor = headerColumns.contains("vendor name")
                                ? headerColumns.value("vendor name")
                                : colIndex("vendor", 6);
            int colDate = colIndex("date", -1);
            int colUnitPrice = colIndex("unit price", data[0].size() > 9 ? 9 : 8);

            QVector<QVector<QVariant>> normalized;
            normalized.reserve(data.size());
            normalized.append({"Part Name", "Part No", "Stock",
                               "Department", "Prepared", "Approved", "Vendor Name",
                               "Date", "Unit Price"});

            for (int row = 1; row < data.size(); ++row) {
                const QVector<QVariant> &sourceRow = data[row];
                QVector<QVariant> targetRow(9);
                targetRow[0] = cellValue(sourceRow, colPartName);
                targetRow[1] = cellValue(sourceRow, colPartNo);
                targetRow[2] = cellValue(sourceRow, colStock);
                targetRow[3] = cellValue(sourceRow, colDepartment);
                targetRow[4] = cellValue(sourceRow, colPrepared);
                targetRow[5] = cellValue(sourceRow, colApproved);
                targetRow[6] = cellValue(sourceRow, colVendor);
                targetRow[7] = cellValue(sourceRow, colDate);
                targetRow[8] = cellValue(sourceRow, colUnitPrice);
                normalized.append(targetRow);
            }

            data = normalized;
        }
    }

    int rowsAdded = 0;
    int rowsUpdated = 0;

    for (int row = 1; row < data.size(); ++row) {
        const QVector<QVariant> &rowData = data[row];
        QString partName = rowData[0].toString().trimmed();
        if (partName.isEmpty()) continue;

        int existingRow = findPartByName(partName);
        if (existingRow != -1) {
            int currentStock = toStockInt(m_model->getData(existingRow, 2));
            int incomingStock = toStockInt(rowData[2]);
            m_model->setDataAt(existingRow, 2, currentStock + incomingStock);

            if (!rowData[1].toString().trimmed().isEmpty()) m_model->setDataAt(existingRow, 1, rowData[1]);
            if (!rowData[3].toString().trimmed().isEmpty()) m_model->setDataAt(existingRow, 3, rowData[3]);
            if (!rowData[4].toString().trimmed().isEmpty()) m_model->setDataAt(existingRow, 4, rowData[4]);
            if (!rowData[5].toString().trimmed().isEmpty()) m_model->setDataAt(existingRow, 5, rowData[5]);
            if (!rowData[6].toString().trimmed().isEmpty()) m_model->setDataAt(existingRow, 6, rowData[6]);
            if (!rowData[7].toString().trimmed().isEmpty()) m_model->setDataAt(existingRow, 7, rowData[7]);
            if (rowData[8].isValid() && rowData[8].toDouble() > 0.0) m_model->setDataAt(existingRow, 8, rowData[8]);

            rowsUpdated++;
        } else {
            m_model->addRow();
            int newRow = m_model->rowCount() - 1;
            for (int col = 0; col < 9; ++col) {
                if (col == 2) {
                    m_model->setDataAt(newRow, col, toStockInt(rowData[col]));
                } else {
                    m_model->setDataAt(newRow, col, rowData[col]);
                }
            }
            rowsAdded++;
        }
    }

    if (!m_permanentFile.isEmpty()) {
        saveToPermanent();
    }

    emit fileMerged(QFileInfo(cleanPath).fileName(), rowsAdded, rowsUpdated);
    emit lowStockCountChanged();
    return true;
}

int ExcelHandler::searchPartName(const QString &partName)
{
    int row = findPartByName(partName);
    if (row != -1) emit searchResultFound(row);
    return row;
}

QVariantList ExcelHandler::searchAllMatches(const QString &searchText)
{
    QVariantList results;
    int rows = m_model->rowCount();
    QString search = searchText.trimmed().toLower();

    for (int row = 1; row < rows; ++row) {
        QString partName = m_model->getData(row, 0).toString().toLower();
        QString partNo = m_model->getData(row, 1).toString().toLower();
        QString vendor = m_model->getData(row, 6).toString().toLower();

        if (partName.contains(search) || partNo.contains(search) || vendor.contains(search)) {
            QVariantMap result;
            result["row"]      = row;
            result["partName"] = m_model->getData(row, 0);
            result["partNo"]   = m_model->getData(row, 1);
            result["stock"]    = m_model->getData(row, 2);
            result["vendor"]   = m_model->getData(row, 6);
            result["department"] = m_model->getData(row, 3);
            result["date"] = m_model->getData(row, 7);
            results.append(result);
        }
    }

    return results;
}

bool ExcelHandler::uploadFileForPart(int row, const QString &filePath)
{
    Q_UNUSED(row) Q_UNUSED(filePath)
    return false;
}

QString ExcelHandler::getUploadedFilePath(int row) { Q_UNUSED(row) return ""; }
bool ExcelHandler::openUploadedFile(int row) { Q_UNUSED(row) return false; }
bool ExcelHandler::hasUploadedFile(int row) { Q_UNUSED(row) return false; }

// ==================== CREATE FILES ====================

void ExcelHandler::createNew(int rows, int cols)
{
    Q_UNUSED(cols)

    QVector<QVector<QVariant>> data;
    data.reserve(rows);

    // 9 columns: Date added, Min Stock/Reorder removed
    QVector<QVariant> header = {"Part Name", "Part No", "Stock",
                                "Department", "Prepared", "Approved", "Vendor Name",
                                "Date", "Unit Price"};
    data.append(header);

    for (int i = 1; i < rows; ++i) {
        QVector<QVariant> row(9);
        data.append(row);
    }

    m_model->setExcelData(data);
    m_currentFile = "";
    setUnsavedChanges(false);
    emit currentFileChanged();
}

void ExcelHandler::createStockFile(int rows)
{
    QVector<QVector<QVariant>> data;
    data.reserve(rows);

    QVector<QVariant> header = {"Part Name", "Part No", "Stock",
                                "Department", "Prepared", "Approved", "Vendor Name",
                                "Date", "Unit Price"};
    data.append(header);

    for (int i = 1; i < rows; ++i) {
        QVector<QVariant> row(9);
        data.append(row);
    }

    m_model->setExcelData(data);
    m_currentFile = "";
    setUnsavedChanges(false);
    emit currentFileChanged();
    emit lowStockCountChanged();

    qDebug() << "Stock file created (9 columns with date and unit price)";
}

void ExcelHandler::createPurchaseFile(int rows)
{
    QVector<QVector<QVariant>> data;
    data.reserve(rows);

    QVector<QVariant> header = {"Part Name", "Part No", "Purchase",
                                "Department", "Prepared", "Approved", "Vendor Name"};
    data.append(header);

    for (int i = 1; i < rows; ++i) {
        QVector<QVariant> row(7);
        data.append(row);
    }

    m_model->setExcelData(data);
    m_currentFile = "";
    setUnsavedChanges(false);
    emit currentFileChanged();
}

QString ExcelHandler::getFileName() const
{
    if (m_currentFile.isEmpty()) return "Untitled";
    return QFileInfo(m_currentFile).fileName();
}

QString ExcelHandler::getFileType() const
{
    QVariant header = m_model->getData(0, 2);
    QString headerText = header.toString().trimmed().toLower();
    return (headerText == "purchase") ? "purchase" : "stock";
}

bool ExcelHandler::loadExcel(const QString &filePath)
{
    QString cleanPath = cleanFilePath(filePath);

    QFileInfo fileInfo(cleanPath);
    if (!fileInfo.exists()) {
        emit errorOccurred("File does not exist: " + cleanPath);
        return false;
    }

    QString suffix = fileInfo.suffix().toLower();
    if (suffix != "xlsx" && suffix != "xls") {
        emit errorOccurred("Please select an Excel file (.xlsx or .xls)");
        return false;
    }

    QXlsx::Document xlsx(cleanPath);
    if (!xlsx.load()) {
        emit errorOccurred("Failed to load Excel file");
        return false;
    }

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) {
        emit errorOccurred("No worksheet found");
        return false;
    }

    QXlsx::CellRange range = sheet->dimension();
    int startRow = qMax(range.firstRow(), 1);
    int endRow = qMax(range.lastRow(), 1);
    int startCol = qMax(range.firstColumn(), 1);
    int endCol = qMin(qMax(range.lastColumn(), 1), 26);

    QVector<QVector<QVariant>> data;
    int consecutiveEmptyRows = 0;

    for (int row = startRow; row <= endRow; ++row) {
        QVector<QVariant> rowData;
        bool rowIsEmpty = true;
        int actualColumns = 0;

        for (int col = startCol; col <= endCol; ++col) {
            auto cell = sheet->cellAt(row, col);
            QVariant cellValue;
            if (cell && cell->value().isValid()) {
                cellValue = cell->value();
                if (!cellValue.toString().trimmed().isEmpty()) {
                    rowIsEmpty = false;
                    actualColumns = qMax(actualColumns, col - startCol + 1);
                }
            }
            rowData.append(cellValue);
        }

        if (row == startRow && !rowIsEmpty) {
            while (rowData.size() > actualColumns) rowData.removeLast();
        }

        if (rowIsEmpty && row > startRow) {
            consecutiveEmptyRows++;
            if (consecutiveEmptyRows >= 5) break;
            continue;
        } else if (!rowIsEmpty) {
            consecutiveEmptyRows = 0;
            if (row > startRow && !data.isEmpty()) {
                int headerCols = data[0].size();
                while (rowData.size() > headerCols) rowData.removeLast();
                while (rowData.size() < headerCols) rowData.append(QVariant());
            }
            data.append(rowData);
        }
    }

    if (!data.isEmpty()) {
        int maxCols = data[0].size();
        for (auto &row : data) {
            while (row.size() < maxCols) row.append(QVariant());
            while (row.size() > maxCols) row.removeLast();
        }
    }

    if (data.isEmpty()) {
        emit errorOccurred("No data found in Excel file");
        return false;
    }

    // Normalize stock sheets to current 9-column layout.
    // Older files may still use Min Stock / Reorder Level columns.
    if (!data.isEmpty() && data[0].size() >= 3) {
        auto normalizeHeader = [](const QVariant &value) {
            return value.toString().trimmed().toLower();
        };

        QString col3Header = normalizeHeader(data[0][2]);
        if (col3Header == "stock") {
            QHash<QString, int> headerColumns;
            for (int col = 0; col < data[0].size(); ++col) {
                QString header = normalizeHeader(data[0][col]);
                if (!header.isEmpty()) {
                    headerColumns.insert(header, col);
                }
            }

            bool hasLegacyReorderColumns = headerColumns.contains("min stock") ||
                                           headerColumns.contains("reorder level") ||
                                           headerColumns.contains("reorder lvl") ||
                                           headerColumns.contains("reorder");
            bool hasDateColumn = headerColumns.contains("date");
            bool needsNormalization = data[0].size() != 9 || hasLegacyReorderColumns || !hasDateColumn;

            if (needsNormalization) {
                auto colIndex = [&headerColumns](const QString &header, int fallback) {
                    return headerColumns.contains(header) ? headerColumns.value(header) : fallback;
                };
                auto cellValue = [](const QVector<QVariant> &row, int col) -> QVariant {
                    if (col < 0 || col >= row.size()) return QVariant();
                    return row[col];
                };

                int colPartName = colIndex("part name", 0);
                int colPartNo = colIndex("part no", 1);
                int colStock = colIndex("stock", 2);
                int colDepartment = colIndex("department", 3);
                int colPrepared = colIndex("prepared", 4);
                int colApproved = colIndex("approved", 5);
                int colVendor = headerColumns.contains("vendor name")
                                    ? headerColumns.value("vendor name")
                                    : colIndex("vendor", 6);
                int colDate = colIndex("date", -1);
                int colUnitPrice = colIndex("unit price", data[0].size() > 9 ? 9 : 8);

                QVector<QVector<QVariant>> normalized;
                normalized.reserve(data.size());
                normalized.append({"Part Name", "Part No", "Stock",
                                   "Department", "Prepared", "Approved", "Vendor Name",
                                   "Date", "Unit Price"});

                for (int row = 1; row < data.size(); ++row) {
                    const QVector<QVariant> &sourceRow = data[row];
                    QVector<QVariant> targetRow(9);
                    targetRow[0] = cellValue(sourceRow, colPartName);
                    targetRow[1] = cellValue(sourceRow, colPartNo);
                    targetRow[2] = cellValue(sourceRow, colStock);
                    targetRow[3] = cellValue(sourceRow, colDepartment);
                    targetRow[4] = cellValue(sourceRow, colPrepared);
                    targetRow[5] = cellValue(sourceRow, colApproved);
                    targetRow[6] = cellValue(sourceRow, colVendor);
                    targetRow[7] = cellValue(sourceRow, colDate);
                    targetRow[8] = cellValue(sourceRow, colUnitPrice);
                    normalized.append(targetRow);
                }

                data = normalized;
                qDebug() << "Normalized stock sheet to 9-column dashboard layout";
            }

            // Normalize stock column values to integers.
            for (int row = 1; row < data.size(); ++row) {
                if (data[row].size() > 2) {
                    data[row][2] = toStockInt(data[row][2]);
                }
            }
        }
    }

    m_model->setExcelData(data);
    m_currentFile = cleanPath;
    setUnsavedChanges(false);

    emit currentFileChanged();
    emit fileLoaded(fileInfo.fileName());
    emit lowStockCountChanged();

    qDebug() << "Loaded:" << data.size() << "rows x" << (data.isEmpty() ? 0 : data[0].size()) << "cols";
    return true;
}

bool ExcelHandler::saveExcel(const QString &filePath)
{
    QString savePath = filePath.isEmpty() ? m_currentFile : cleanFilePath(filePath);

    if (savePath.isEmpty()) {
        emit errorOccurred("No file path specified");
        return false;
    }

    if (!savePath.endsWith(".xlsx", Qt::CaseInsensitive) && !savePath.endsWith(".xls", Qt::CaseInsensitive)) {
        savePath += ".xlsx";
    }

    QXlsx::Document xlsx;
    QVector<QVector<QVariant>> data = m_model->getExcelData();

    for (int row = 0; row < data.size(); ++row) {
        for (int col = 0; col < data[row].size(); ++col) {
            xlsx.write(row + 1, col + 1, data[row][col]);
        }
    }

    if (!xlsx.saveAs(savePath)) {
        emit errorOccurred("Failed to save file");
        return false;
    }

    m_currentFile = savePath;
    setUnsavedChanges(false);
    emit currentFileChanged();
    emit fileSaved(QFileInfo(savePath).fileName());

    return true;
}

bool ExcelHandler::validateFileStructure(const QString &filePath)
{
    QString cleanPath = cleanFilePath(filePath);

    QXlsx::Document xlsx(cleanPath);
    if (!xlsx.load()) return false;

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) return false;

    auto col3Cell = sheet->cellAt(1, 3);
    QString col3Header = col3Cell ? col3Cell->value().toString().trimmed().toLower() : "";

    return (col3Header == "purchase");
}

QString ExcelHandler::browseOpenFile(const QString &title, const QString &filter)
{
    return QFileDialog::getOpenFileName(nullptr, title, QString(), filter);
}

QString ExcelHandler::browseSaveFile(const QString &title, const QString &filter)
{
    return QFileDialog::getSaveFileName(nullptr, title, QString(), filter);
}

QString ExcelHandler::browseFolder(const QString &title)
{
    return QFileDialog::getExistingDirectory(nullptr, title, QString());
}

static QDateTime parseReportDate(const QString &value, const QTime &fallbackTime)
{
    QString text = value.trimmed();
    if (text.isEmpty()) return QDateTime();

    QDateTime dt = QDateTime::fromString(text, "yyyy-MM-dd hh:mm:ss");
    if (!dt.isValid()) dt = QDateTime::fromString(text, "yyyy-MM-dd hh:mm");
    if (!dt.isValid()) {
        QDate date = QDate::fromString(text, "yyyy-MM-dd");
        if (date.isValid()) {
            dt = QDateTime(date, fallbackTime);
        }
    }
    return dt;
}

bool ExcelHandler::exportReport(const QString &fromDate, const QString &toDate, const QString &filePath)
{
    if (filePath.trimmed().isEmpty()) {
        emit errorOccurred("Report file path is required");
        return false;
    }

    QDateTime fromDt = parseReportDate(fromDate, QTime(0, 0, 0));
    QDateTime toDt = parseReportDate(toDate, QTime(23, 59, 59));
    if (!fromDt.isValid()) fromDt = QDateTime::fromSecsSinceEpoch(0);
    if (!toDt.isValid()) toDt = QDateTime::currentDateTime();

    auto inRange = [&fromDt, &toDt](const QDateTime &dt) {
        if (!dt.isValid()) return false;
        return dt >= fromDt && dt <= toDt;
    };

    QString savePath = filePath;
    if (!savePath.endsWith(".xlsx", Qt::CaseInsensitive)) {
        savePath += ".xlsx";
    }

    QXlsx::Document xlsx;
    xlsx.renameSheet("Sheet1", "StockMovements");
    xlsx.selectSheet("StockMovements");

    xlsx.write(1, 1, "Date");
    xlsx.write(1, 2, "Part Name");
    xlsx.write(1, 3, "Type");
    xlsx.write(1, 4, "Qty");
    xlsx.write(1, 5, "Reference");
    xlsx.write(1, 6, "Done By");

    int row = 2;
    for (const auto &mov : m_stockMovements) {
        QDateTime dt = parseReportDate(mov.value("date").toString(), QTime(0, 0, 0));
        if (!inRange(dt)) continue;
        xlsx.write(row, 1, mov.value("date"));
        xlsx.write(row, 2, mov.value("partName"));
        xlsx.write(row, 3, mov.value("type"));
        xlsx.write(row, 4, mov.value("qty"));
        xlsx.write(row, 5, mov.value("reference"));
        xlsx.write(row, 6, mov.value("doneBy"));
        row++;
    }

    xlsx.addSheet("Issues");
    xlsx.selectSheet("Issues");
    xlsx.write(1, 1, "Date");
    xlsx.write(1, 2, "Issue No");
    xlsx.write(1, 3, "Part Name");
    xlsx.write(1, 4, "Qty");
    xlsx.write(1, 5, "Department");
    xlsx.write(1, 6, "Issued By");

    row = 2;
    for (const auto &note : m_issueNotes) {
        QDateTime dt = parseReportDate(note.value("date").toString(), QTime(0, 0, 0));
        if (!inRange(dt)) continue;
        xlsx.write(row, 1, note.value("date"));
        xlsx.write(row, 2, note.value("issueNo"));
        xlsx.write(row, 3, note.value("partName"));
        xlsx.write(row, 4, note.value("qty"));
        xlsx.write(row, 5, note.value("department"));
        xlsx.write(row, 6, note.value("issuedBy"));
        row++;
    }

    xlsx.addSheet("GRN");
    xlsx.selectSheet("GRN");
    xlsx.write(1, 1, "Date");
    xlsx.write(1, 2, "GRN No");
    xlsx.write(1, 3, "PO No");
    xlsx.write(1, 4, "Part Name");
    xlsx.write(1, 5, "Received Qty");
    xlsx.write(1, 6, "Accepted Qty");
    xlsx.write(1, 7, "Rejected Qty");
    xlsx.write(1, 8, "Remarks");
    xlsx.write(1, 9, "Received By");

    row = 2;
    for (const auto &grn : m_grnRecords) {
        QDateTime dt = parseReportDate(grn.value("date").toString(), QTime(0, 0, 0));
        if (!inRange(dt)) continue;
        xlsx.write(row, 1, grn.value("date"));
        xlsx.write(row, 2, grn.value("grnNo"));
        xlsx.write(row, 3, grn.value("poNo"));
        xlsx.write(row, 4, grn.value("partName"));
        xlsx.write(row, 5, grn.value("receivedQty"));
        xlsx.write(row, 6, grn.value("acceptedQty"));
        xlsx.write(row, 7, grn.value("rejectedQty"));
        xlsx.write(row, 8, grn.value("remarks"));
        xlsx.write(row, 9, grn.value("receivedBy"));
        row++;
    }

    xlsx.addSheet("PurchaseOrders");
    xlsx.selectSheet("PurchaseOrders");
    xlsx.write(1, 1, "PO No");
    xlsx.write(1, 2, "Date");
    xlsx.write(1, 3, "Vendor");
    xlsx.write(1, 4, "Part Name");
    xlsx.write(1, 5, "Part No");
    xlsx.write(1, 6, "Department");
    xlsx.write(1, 7, "Qty");
    xlsx.write(1, 8, "Unit Price");
    xlsx.write(1, 9, "Total Amount");
    xlsx.write(1, 10, "Expected Date");
    xlsx.write(1, 11, "Status");
    xlsx.write(1, 12, "Received Qty");
    xlsx.write(1, 13, "Prepared By");
    xlsx.write(1, 14, "Approved By");
    xlsx.write(1, 15, "Received By");
    xlsx.write(1, 16, "Received Date");

    row = 2;
    for (const auto &po : m_purchaseOrders) {
        QDateTime dt = parseReportDate(po.value("date").toString(), QTime(0, 0, 0));
        if (!inRange(dt)) continue;
        xlsx.write(row, 1, po.value("poNo"));
        xlsx.write(row, 2, po.value("date"));
        xlsx.write(row, 3, po.value("vendor"));
        xlsx.write(row, 4, po.value("partName"));
        xlsx.write(row, 5, po.value("partNo"));
        xlsx.write(row, 6, po.value("department"));
        xlsx.write(row, 7, po.value("qty"));
        xlsx.write(row, 8, po.value("unitPrice"));
        xlsx.write(row, 9, po.value("totalAmount"));
        xlsx.write(row, 10, po.value("expectedDate"));
        xlsx.write(row, 11, po.value("status"));
        xlsx.write(row, 12, po.value("receivedQty"));
        xlsx.write(row, 13, po.value("preparedBy"));
        xlsx.write(row, 14, po.value("approvedBy"));
        xlsx.write(row, 15, po.value("receivedBy"));
        xlsx.write(row, 16, po.value("receivedDate"));
        row++;
    }

    if (!xlsx.saveAs(savePath)) {
        emit errorOccurred("Failed to save report");
        return false;
    }

    return true;
}

void ExcelHandler::addNewItem(const QString &partName, const QString &category,
                              int quantity, double unitPrice)
{
    int existingRow = findPartByName(partName);

    if (existingRow != -1) {
        int currentStock = toStockInt(m_model->getData(existingRow, 2));
        m_model->setDataAt(existingRow, 2, currentStock + quantity);

        // Log movement
        QString partNo = m_model->getData(existingRow, 1).toString();
        logStockMovement(partName, partNo, "IN", quantity, "Manual Add", m_currentUser);
    } else {
        m_model->addRow();
        int newRow = m_model->rowCount() - 1;

        m_model->setDataAt(newRow, 0, partName);
        m_model->setDataAt(newRow, 1, "PN-" + QString::number(newRow));
        m_model->setDataAt(newRow, 2, quantity);
        m_model->setDataAt(newRow, 3, category);
        m_model->setDataAt(newRow, 8, unitPrice);  // Column 8 = Unit Price

        logStockMovement(partName, "PN-" + QString::number(newRow), "IN", quantity, "New Item", m_currentUser);
    }

    emit lowStockCountChanged();
}

int ExcelHandler::getNextSerialNumber() const
{
    int maxNo = 0;
    int rows = m_model->rowCount();
    for (int row = 1; row < rows; ++row) {
        int no = m_model->getData(row, 0).toInt();
        if (no > maxNo) maxNo = no;
    }
    return maxNo + 1;
}

void ExcelHandler::onModelDataChanged()
{
    setUnsavedChanges(true);
    scheduleAutoSave();
}

void ExcelHandler::autoSavePermanent()
{
    // The database is the permanent store now.
    saveStockToDb();
    setUnsavedChanges(false);

    // Legacy: also mirror to a permanent xlsx if one was configured.
    if (!m_permanentFile.isEmpty())
        saveToPermanent();
}

void ExcelHandler::autoSyncFromCloud()
{
    if (!m_syncEnabled || m_cloudFolder.isEmpty()) return;

    QString localFile = !m_currentFile.isEmpty() ? m_currentFile : m_permanentFile;
    if (localFile.isEmpty()) return;

    QString cloudFilePath = getCloudFilePath();
    if (cloudFilePath.isEmpty() || !QFile::exists(cloudFilePath)) return;
    if (isFileLocked(cloudFilePath)) return;

    QFileInfo localInfo(localFile);
    QFileInfo cloudInfo(cloudFilePath);

    if (cloudInfo.lastModified() > localInfo.lastModified()) {
        if (m_hasUnsavedChanges) {
            emit conflictDetected("Cloud file updated while local changes exist");
            return;
        }
        syncFromCloud();
    }
}

void ExcelHandler::setUnsavedChanges(bool changed)
{
    if (m_hasUnsavedChanges != changed) {
        m_hasUnsavedChanges = changed;
        emit unsavedChangesChanged();
    }
}

void ExcelHandler::scheduleAutoSave()
{
    // Debounced autosave into the shared database (and, if configured, the
    // legacy permanent xlsx file).
    m_autoSaveTimer.start(500);
}

void ExcelHandler::updateAutoSyncState()
{
    if (m_syncEnabled && !m_cloudFolder.isEmpty()) {
        if (!m_cloudPollTimer.isActive()) m_cloudPollTimer.start();
    } else {
        m_cloudPollTimer.stop();
    }
}

QString ExcelHandler::cleanFilePath(const QString &path)
{
    QString cleanPath = path;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);
#ifdef Q_OS_LINUX
    if (!cleanPath.isEmpty() && !cleanPath.startsWith('/')) cleanPath = "/" + cleanPath;
#endif
    return cleanPath;
}

void ExcelHandler::recalculateSerialNumbers() {}

// ==================== CLOUD SYNC (unchanged) ====================

void ExcelHandler::loadCloudSettings()
{
    QSettings settings("EinsteinRobotics", "StockManager");
    m_cloudFolder = settings.value("cloudFolder", "").toString();
    m_syncEnabled = settings.value("syncEnabled", false).toBool();
    m_currentUser = settings.value("currentUser", "User").toString();
    m_userRole = settings.value("userRole", "editor").toString();
    m_syncStatus = "offline";
    m_lastSyncTime = settings.value("lastSyncTime", "Never").toString();

    if (!m_cloudFolder.isEmpty() && QDir(m_cloudFolder).exists()) {
        m_syncStatus = "synced";
    }

    emit cloudFolderChanged();
    emit syncEnabledChanged();
    emit currentUserChanged();
    emit userRoleChanged();
    emit lastSyncTimeChanged();
    emit syncStatusChanged();
}

void ExcelHandler::saveCloudSettings()
{
    QSettings settings("EinsteinRobotics", "StockManager");
    settings.setValue("cloudFolder", m_cloudFolder);
    settings.setValue("syncEnabled", m_syncEnabled);
    settings.setValue("currentUser", m_currentUser);
    settings.setValue("userRole", m_userRole);
    settings.setValue("lastSyncTime", m_lastSyncTime);
}

void ExcelHandler::setCloudFolder(const QString &folder)
{
    QString cleanPath = cleanFilePath(folder);
    QDir dir(cleanPath);
    if (!dir.exists()) {
        emit errorOccurred("Cloud folder does not exist: " + cleanPath);
        return;
    }
    m_cloudFolder = cleanPath;
    saveCloudSettings();
    emit cloudFolderChanged();
    updateAutoSyncState();
}

void ExcelHandler::setSyncEnabled(bool enabled)
{
    if (m_syncEnabled != enabled) {
        m_syncEnabled = enabled;
        saveCloudSettings();
        emit syncEnabledChanged();
        updateAutoSyncState();
    }
}

void ExcelHandler::setCurrentUser(const QString &username)
{
    if (m_currentUser != username) {
        m_currentUser = username;
        saveCloudSettings();
        emit currentUserChanged();
    }
}

void ExcelHandler::setUserRole(const QString &role)
{
    if (m_userRole != role) {
        m_userRole = role;
        saveCloudSettings();
        emit userRoleChanged();
    }
}

void ExcelHandler::updateSyncStatus(const QString &status)
{
    if (m_syncStatus != status) {
        m_syncStatus = status;
        emit syncStatusChanged();
    }
}

bool ExcelHandler::canEdit() const
{
    return m_userRole == "owner" || m_userRole == "editor";
}

QString ExcelHandler::getCloudFilePath() const
{
    QString sourceFile = !m_currentFile.isEmpty() ? m_currentFile : m_permanentFile;
    if (m_cloudFolder.isEmpty() || sourceFile.isEmpty()) return "";
    return m_cloudFolder + "/" + QFileInfo(sourceFile).fileName();
}

bool ExcelHandler::isFileLocked(const QString &filePath) const
{
    QString lockFile = filePath + ".lock";
    if (!QFile::exists(lockFile)) return false;

    QFileInfo lockInfo(lockFile);
    if (lockInfo.lastModified().secsTo(QDateTime::currentDateTime()) > 300) return false;

    QFile file(lockFile);
    if (file.open(QIODevice::ReadOnly)) {
        QString lockOwner = file.readAll().trimmed();
        file.close();
        return (lockOwner != m_currentUser);
    }
    return false;
}

bool ExcelHandler::lockFile(const QString &filePath)
{
    if (isFileLocked(filePath)) return false;
    QFile file(filePath + ".lock");
    if (file.open(QIODevice::WriteOnly)) {
        file.write(m_currentUser.toUtf8());
        file.close();
        return true;
    }
    return false;
}

bool ExcelHandler::unlockFile(const QString &filePath)
{
    QString lockFile = filePath + ".lock";
    if (QFile::exists(lockFile)) {
        QFile::remove(lockFile);
        return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Dropbox / folder-based cloud sync is deprecated. All supply-chain data now
// lives in the shared SQL database, which handles multi-user concurrency
// natively, so these methods are intentionally no-ops kept only for binary /
// QML compatibility.
// ---------------------------------------------------------------------------
bool ExcelHandler::syncToCloud()
{
    updateSyncStatus("db");
    return false;
}

bool ExcelHandler::syncFromCloud()
{
    updateSyncStatus("db");
    return false;
}

bool ExcelHandler::checkForUpdates()
{
    return false;
}

// ==================== AUTHENTICATION ====================

QString ExcelHandler::login(const QString &username, const QString &password)
{
    if (!m_db) return QString();
    const QString role = m_db->authenticate(username, password);
    if (!role.isEmpty()) {
        setCurrentUser(username);
        setUserRole(role);
        qInfo() << "Login successful for" << username << "as" << role;
    }
    return role;
}

// ==================== DATABASE CONNECTION SETTINGS ====================

QVariantMap ExcelHandler::getDatabaseSettings() const
{
    return m_db ? m_db->connectionSettings() : QVariantMap();
}

bool ExcelHandler::configureDatabase(const QString &driver,
                                     const QString &host, int port,
                                     const QString &name,
                                     const QString &user, const QString &password)
{
    if (!m_db) return false;

    const bool ok = m_db->configureConnection(driver, host, port, name, user, password);
    if (ok) {
        // Reload every cache (including the stock grid) from the new database.
        refreshFromDatabase();
    }
    return ok;
}

QString ExcelHandler::databaseStatus() const
{
    if (!m_db) return "Not initialised";
    return (m_db->isConnected() ? "Connected: " : "Disconnected: ") + m_db->backendName();
}

bool ExcelHandler::isDatabaseConnected() const
{
    return m_db && m_db->isConnected();
}

bool ExcelHandler::isDatabaseServerBackend() const
{
    return m_db && m_db->isServerBackend();
}

QString ExcelHandler::databaseLastError() const
{
    return m_db ? m_db->lastError() : QString("Database not initialised");
}

// ==================== LAN SERVER PROVISIONING ====================

void ExcelHandler::setupThisComputerAsServer()
{
    if (m_serverSetup) m_serverSetup->provisionAsServer();
}

bool ExcelHandler::isServerProvisioned() const
{
    return m_serverSetup && m_serverSetup->isServerProvisioned();
}

QString ExcelHandler::serverLanAddressHint() const
{
    return m_serverSetup ? m_serverSetup->lanAddressHint() : QString();
}

void ExcelHandler::refreshFromDatabase()
{
    if (!m_db || !m_db->isConnected()) return;

    loadVendors();
    loadItemMaster();
    loadPurchaseOrders();
    loadStockMovements();
    loadIssueNotes();
    loadGRNRecords();
    loadStockFromDb();

    emit vendorListChanged();
    emit itemMasterListChanged();
    emit pendingPOCountChanged();
    emit lowStockCountChanged();
}
