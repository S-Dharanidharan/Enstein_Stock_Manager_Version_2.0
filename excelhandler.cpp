#include "excelhandler.h"
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
    updateAutoSyncState();

    // Load supply chain data
    loadVendors();
    loadItemMaster();
    loadPurchaseOrders();
    loadStockMovements();
    loadIssueNotes();
    loadGRNRecords();
    loadSupplyChainCounters();

    qDebug() << "ExcelHandler created with Supply Chain support";
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
    QString path = m_dataDir + "/vendors.xlsx";

    if (!QFile::exists(path)) return;

    QXlsx::Document xlsx(path);
    if (!xlsx.load()) return;

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) return;

    QXlsx::CellRange range = sheet->dimension();

    for (int row = 2; row <= range.lastRow(); ++row) {
        QVariantMap vendor;
        vendor["vendorName"]    = sheet->cellAt(row, 1) ? sheet->cellAt(row, 1)->value().toString() : "";
        vendor["vendorAddress"] = sheet->cellAt(row, 2) ? sheet->cellAt(row, 2)->value().toString() : "";
        vendor["bankBranch"]    = sheet->cellAt(row, 3) ? sheet->cellAt(row, 3)->value().toString() : "";
        vendor["ifsc"]          = sheet->cellAt(row, 4) ? sheet->cellAt(row, 4)->value().toString() : "";
        vendor["accountNumber"] = sheet->cellAt(row, 5) ? sheet->cellAt(row, 5)->value().toString() : "";
        vendor["cin"]           = sheet->cellAt(row, 6) ? sheet->cellAt(row, 6)->value().toString() : "";
        vendor["gstin"]         = sheet->cellAt(row, 7) ? sheet->cellAt(row, 7)->value().toString() : "";
        vendor["panNumber"]     = sheet->cellAt(row, 8) ? sheet->cellAt(row, 8)->value().toString() : "";
        vendor["panName"]       = sheet->cellAt(row, 9) ? sheet->cellAt(row, 9)->value().toString() : "";
        vendor["contactPerson"] = sheet->cellAt(row, 10) ? sheet->cellAt(row, 10)->value().toString() : "";
        vendor["email"]         = sheet->cellAt(row, 11) ? sheet->cellAt(row, 11)->value().toString() : "";
        vendor["phone"]         = sheet->cellAt(row, 12) ? sheet->cellAt(row, 12)->value().toString() : "";
        vendor["itemCategory"]  = sheet->cellAt(row, 13) ? sheet->cellAt(row, 13)->value().toString() : "";

        // Backward compatibility with old vendor sheet layout (12 columns)
        if (vendor["itemCategory"].toString().trimmed().isEmpty() &&
            sheet->cellAt(row, 12) &&
            !sheet->cellAt(row, 12)->value().toString().trimmed().isEmpty()) {
            vendor["itemCategory"] = sheet->cellAt(row, 12)->value().toString();
            vendor["phone"] = "";
        }

        if (!vendor["vendorName"].toString().trimmed().isEmpty()) {
            m_vendors.append(vendor);
        }
    }
    qDebug() << "Loaded" << m_vendors.size() << "vendors";
}

bool ExcelHandler::saveVendors()
{
    QString path = m_dataDir + "/vendors.xlsx";
    QXlsx::Document xlsx;

    // Header
    xlsx.write(1, 1, "Vendor Name");
    xlsx.write(1, 2, "Vendor Address");
    xlsx.write(1,3, "Bank Branch");
    xlsx.write(1,4, "IFSC");
    xlsx.write(1,5, "Account Number");
    xlsx.write(1,6, "CIN");
    xlsx.write(1,7, "GSTIN");
    xlsx.write(1,8, "PAN");
    xlsx.write(1,9, "PAN Name");
    xlsx.write(1,10, "Contact Person");
    xlsx.write(1,11, "Email");
    xlsx.write(1,12, "Phone");
    xlsx.write(1,13, "Item Category");

    for (int i = 0; i < m_vendors.size(); ++i) {
        int row = i + 2;
        xlsx.write(row, 1, m_vendors[i]["vendorName"]);
        xlsx.write(row, 2, m_vendors[i]["vendorAddress"]);
        xlsx.write(row, 3, m_vendors[i]["bankBranch"]);
        xlsx.write(row, 4, m_vendors[i]["ifsc"]);
        xlsx.write(row, 5, m_vendors[i]["accountNumber"]);
        xlsx.write(row, 6, m_vendors[i]["cin"]);
        xlsx.write(row, 7, m_vendors[i]["gstin"]);
        xlsx.write(row, 8, m_vendors[i]["panNumber"]);
        xlsx.write(row, 9, m_vendors[i]["panName"]);
        xlsx.write(row, 10, m_vendors[i]["contactPerson"]);
        xlsx.write(row, 11, m_vendors[i]["email"]);
        xlsx.write(row, 12, m_vendors[i]["phone"]);
        xlsx.write(row, 13, m_vendors[i]["itemCategory"]);
    }
                                
    if (!xlsx.saveAs(path)) {
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
    QString path = m_dataDir + "/item_master.xlsx";

    if (!QFile::exists(path)) return;

    QXlsx::Document xlsx(path);
    if (!xlsx.load()) return;

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) return;

    QXlsx::CellRange range = sheet->dimension();

    for (int row = 2; row <= range.lastRow(); ++row) {
        QVariantMap item;
        item["partNo"]   = sheet->cellAt(row, 1) ? sheet->cellAt(row, 1)->value().toString() : "";
        item["partName"] = sheet->cellAt(row, 2) ? sheet->cellAt(row, 2)->value().toString() : "";
        item["category"] = sheet->cellAt(row, 3) ? sheet->cellAt(row, 3)->value().toString() : "";
        item["unitPrice"] = sheet->cellAt(row, 4) ? sheet->cellAt(row, 4)->value().toDouble() : 0.0;
        item["stockQty"] = sheet->cellAt(row, 5) ? sheet->cellAt(row, 5)->value().toInt() : 0;

        if (!item["partNo"].toString().trimmed().isEmpty()) {
            m_itemMaster.append(item);
        }
    }
    qDebug() << "Loaded" << m_itemMaster.size() << "items in Item Master";
}

void ExcelHandler::saveItemMaster()
{
    QString path = m_dataDir + "/item_master.xlsx";
    QXlsx::Document xlsx;

    // Header
    xlsx.write(1, 1, "Part No");
    xlsx.write(1, 2, "Part Name");
    xlsx.write(1, 3, "Category");
    xlsx.write(1, 4, "Unit Price");
    xlsx.write(1, 5, "Stock Quantity");

    for (int i = 0; i < m_itemMaster.size(); ++i) {
        int row = i + 2;
        xlsx.write(row, 1, m_itemMaster[i]["partNo"]);
        xlsx.write(row, 2, m_itemMaster[i]["partName"]);
        xlsx.write(row, 3, m_itemMaster[i]["category"]);
        xlsx.write(row, 4, m_itemMaster[i]["unitPrice"]);
        xlsx.write(row, 5, m_itemMaster[i]["stockQty"]);
    }

    xlsx.saveAs(path);
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
    QString path = m_dataDir + "/purchase_orders.xlsx";

    if (!QFile::exists(path)) return;

    QXlsx::Document xlsx(path);
    if (!xlsx.load()) return;

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) return;

    QXlsx::CellRange range = sheet->dimension();
    if (range.lastRow() < 2) return;

    QHash<QString, int> headerColumns;
    for (int col = 1; col <= range.lastColumn(); ++col) {
        auto headerCell = sheet->cellAt(1, col);
        QString header = headerCell ? headerCell->value().toString().trimmed().toLower() : "";
        if (!header.isEmpty()) {
            headerColumns.insert(header, col);
        }
    }

    auto columnFor = [&headerColumns](const QString &headerName, int fallbackColumn) {
        return headerColumns.contains(headerName.toLower()) ? headerColumns.value(headerName.toLower()) : fallbackColumn;
    };

    const int colPoNo = columnFor("po no", 1);
    const int colDate = columnFor("date", 2);
    const int colVendor = columnFor("vendor", 3);
    const int colPartName = columnFor("part name", 4);
    const int colPartNo = columnFor("part no", 5);
    const int colDepartment = columnFor("department", -1);
    const int colQty = columnFor("qty", 6);
    const int colUnitPrice = columnFor("unit price", 7);
    const int colTotalAmount = columnFor("total amount", 8);
    const int colExpectedDate = columnFor("expected date", 9);
    const int colStatus = columnFor("status", 10);
    const int colReceivedQty = columnFor("received qty", 11);
    const int colPreparedBy = columnFor("prepared by", -1);
    const int colApprovedBy = columnFor("approved by", -1);
    const int colReceivedBy = columnFor("received by", -1);
    const int colReceivedDate = columnFor("received date", -1);

    for (int row = 2; row <= range.lastRow(); ++row) {
        auto getCellValue = [sheet, row](int col) -> QVariant {
            if (col < 1) return QVariant();
            auto cell = sheet->cellAt(row, col);
            return cell ? cell->value() : QVariant();
        };

        QVariantMap po;
        po["poNo"]         = getCellValue(colPoNo).toString();
        po["date"]         = getCellValue(colDate).toString();
        po["vendor"]       = getCellValue(colVendor).toString();
        po["partName"]     = getCellValue(colPartName).toString();
        po["partNo"]       = getCellValue(colPartNo).toString();
        po["department"]   = getCellValue(colDepartment).toString();
        po["qty"]          = getCellValue(colQty).toInt();
        po["unitPrice"]    = getCellValue(colUnitPrice).toDouble();
        po["totalAmount"]  = getCellValue(colTotalAmount).toDouble();
        po["expectedDate"] = getCellValue(colExpectedDate).toString();
        po["status"]       = getCellValue(colStatus).toString();
        po["receivedQty"]  = getCellValue(colReceivedQty).toInt();
        po["preparedBy"]   = getCellValue(colPreparedBy).toString();
        po["approvedBy"]   = getCellValue(colApprovedBy).toString();
        po["receivedBy"]   = getCellValue(colReceivedBy).toString();
        po["receivedDate"] = getCellValue(colReceivedDate).toString();

        if (po["status"].toString().trimmed().isEmpty()) {
            po["status"] = "Draft";
        }

        if (po["totalAmount"].toDouble() <= 0.0 && po["qty"].toInt() > 0 && po["unitPrice"].toDouble() > 0.0) {
            po["totalAmount"] = po["qty"].toInt() * po["unitPrice"].toDouble();
        }

        if (!po["poNo"].toString().trimmed().isEmpty()) {
            m_purchaseOrders.append(po);
        }
    }

    qDebug() << "Loaded" << m_purchaseOrders.size() << "purchase orders";
}

void ExcelHandler::savePurchaseOrders()
{
    QString path = m_dataDir + "/purchase_orders.xlsx";
    QXlsx::Document xlsx;

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

    for (int i = 0; i < m_purchaseOrders.size(); ++i) {
        int row = i + 2;
        xlsx.write(row, 1,  m_purchaseOrders[i]["poNo"]);
        xlsx.write(row, 2,  m_purchaseOrders[i]["date"]);
        xlsx.write(row, 3,  m_purchaseOrders[i]["vendor"]);
        xlsx.write(row, 4,  m_purchaseOrders[i]["partName"]);
        xlsx.write(row, 5,  m_purchaseOrders[i]["partNo"]);
        xlsx.write(row, 6,  m_purchaseOrders[i]["department"]);
        xlsx.write(row, 7,  m_purchaseOrders[i]["qty"]);
        xlsx.write(row, 8,  m_purchaseOrders[i]["unitPrice"]);
        xlsx.write(row, 9,  m_purchaseOrders[i]["totalAmount"]);
        xlsx.write(row, 10, m_purchaseOrders[i]["expectedDate"]);
        xlsx.write(row, 11, m_purchaseOrders[i]["status"]);
        xlsx.write(row, 12, m_purchaseOrders[i]["receivedQty"]);
        xlsx.write(row, 13, m_purchaseOrders[i]["preparedBy"]);
        xlsx.write(row, 14, m_purchaseOrders[i]["approvedBy"]);
        xlsx.write(row, 15, m_purchaseOrders[i]["receivedBy"]);
        xlsx.write(row, 16, m_purchaseOrders[i]["receivedDate"]);
    }

    xlsx.saveAs(path);
}

QString ExcelHandler::getNextPONumber()
{
    return "PO-" + QString::number(m_nextPONumber).rightJustified(4, '0');
}

QString ExcelHandler::createPurchaseOrder(const QString &vendor,
                                          const QString &partName,
                                          const QString &partNo,
                                          int qty, double unitPrice,
                                          const QString &expectedDate,
                                          const QString &department,
                                          const QString &preparedBy)
{
    if (partName.trimmed().isEmpty()) {
        emit errorOccurred("Part Name is required");
        return "";
    }

    if (qty <= 0) {
        emit errorOccurred("Quantity must be greater than 0");
        return "";
    }

    QString resolvedVendor = vendor.trimmed();
    QString resolvedDepartment = department.trimmed();
    QString resolvedPreparedBy = preparedBy.trimmed().isEmpty() ? m_currentUser : preparedBy.trimmed();
    QString resolvedPartNo = partNo.trimmed();
    double resolvedUnitPrice = unitPrice;

    for (const auto &item : m_itemMaster) {
        if (item["partName"].toString().trimmed().compare(partName.trimmed(), Qt::CaseInsensitive) == 0) {
            if (resolvedPartNo.isEmpty()) resolvedPartNo = item["partNo"].toString().trimmed();
            if (resolvedDepartment.isEmpty()) resolvedDepartment = item["department"].toString().trimmed();
            if (resolvedVendor.isEmpty()) resolvedVendor = item["vendor"].toString().trimmed();
            if (resolvedUnitPrice <= 0.0) resolvedUnitPrice = item["unitPrice"].toDouble();
            break;
        }
    }

    if (resolvedVendor.isEmpty()) {
        emit errorOccurred("Vendor is required");
        return "";
    }

    QString poNo = getNextPONumber();
    m_nextPONumber++;
    saveSupplyChainCounters();

    QVariantMap po;
    po["poNo"]         = poNo;
    po["date"]         = QDateTime::currentDateTime().toString("yyyy-MM-dd");
    po["vendor"]       = resolvedVendor;
    po["partName"]     = partName.trimmed();
    po["partNo"]       = resolvedPartNo;
    po["department"]   = resolvedDepartment;
    po["qty"]          = qty;
    po["unitPrice"]    = resolvedUnitPrice;
    po["totalAmount"]  = qty * resolvedUnitPrice;
    po["expectedDate"] = expectedDate;
    po["status"]       = "Draft";
    po["receivedQty"]  = 0;
    po["preparedBy"]   = resolvedPreparedBy;
    po["approvedBy"]   = "";
    po["receivedBy"]   = "";
    po["receivedDate"] = "";

    m_purchaseOrders.append(po);
    savePurchaseOrders();
    emit pendingPOCountChanged();
    emit purchaseOrderCreated(poNo);

    // Log movement
    logStockMovement(partName, resolvedPartNo, "PO_CREATED", qty, poNo, m_currentUser);

    qDebug() << "Created PO:" << poNo << "for" << partName << "x" << qty;
    return poNo;
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

        po["vendor"] = vendor;
        po["partName"] = partName;
        po["partNo"] = partNo;
        po["department"] = department;
        po["qty"] = qty;
        po["unitPrice"] = unitPrice;
        po["totalAmount"] = qty * unitPrice;
        po["expectedDate"] = expectedDate;
        po["preparedBy"] = preparedBy;

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
    QString path = m_dataDir + "/grn_records.xlsx";

    if (!QFile::exists(path)) return;

    QXlsx::Document xlsx(path);
    if (!xlsx.load()) return;

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) return;

    QXlsx::CellRange range = sheet->dimension();

    for (int row = 2; row <= range.lastRow(); ++row) {
        QVariantMap grn;
        grn["grnNo"]       = sheet->cellAt(row, 1) ? sheet->cellAt(row, 1)->value().toString() : "";
        grn["poNo"]        = sheet->cellAt(row, 2) ? sheet->cellAt(row, 2)->value().toString() : "";
        grn["date"]        = sheet->cellAt(row, 3) ? sheet->cellAt(row, 3)->value().toString() : "";
        grn["partName"]    = sheet->cellAt(row, 4) ? sheet->cellAt(row, 4)->value().toString() : "";
        grn["receivedQty"] = sheet->cellAt(row, 5) ? sheet->cellAt(row, 5)->value().toInt() : 0;
        grn["acceptedQty"] = sheet->cellAt(row, 6) ? sheet->cellAt(row, 6)->value().toInt() : 0;
        grn["rejectedQty"] = sheet->cellAt(row, 7) ? sheet->cellAt(row, 7)->value().toInt() : 0;
        grn["remarks"]     = sheet->cellAt(row, 8) ? sheet->cellAt(row, 8)->value().toString() : "";
        grn["receivedBy"]  = sheet->cellAt(row, 9) ? sheet->cellAt(row, 9)->value().toString() : "";

        if (!grn["grnNo"].toString().trimmed().isEmpty()) {
            m_grnRecords.append(grn);
        }
    }

    qDebug() << "Loaded" << m_grnRecords.size() << "GRN records";
}

void ExcelHandler::saveGRNRecords()
{
    QString path = m_dataDir + "/grn_records.xlsx";
    QXlsx::Document xlsx;

    xlsx.write(1, 1, "GRN No");
    xlsx.write(1, 2, "PO No");
    xlsx.write(1, 3, "Date");
    xlsx.write(1, 4, "Part Name");
    xlsx.write(1, 5, "Received Qty");
    xlsx.write(1, 6, "Accepted Qty");
    xlsx.write(1, 7, "Rejected Qty");
    xlsx.write(1, 8, "Remarks");
    xlsx.write(1, 9, "Received By");

    for (int i = 0; i < m_grnRecords.size(); ++i) {
        int row = i + 2;
        xlsx.write(row, 1, m_grnRecords[i]["grnNo"]);
        xlsx.write(row, 2, m_grnRecords[i]["poNo"]);
        xlsx.write(row, 3, m_grnRecords[i]["date"]);
        xlsx.write(row, 4, m_grnRecords[i]["partName"]);
        xlsx.write(row, 5, m_grnRecords[i]["receivedQty"]);
        xlsx.write(row, 6, m_grnRecords[i]["acceptedQty"]);
        xlsx.write(row, 7, m_grnRecords[i]["rejectedQty"]);
        xlsx.write(row, 8, m_grnRecords[i]["remarks"]);
        xlsx.write(row, 9, m_grnRecords[i]["receivedBy"]);
    }

    xlsx.saveAs(path);
}

QString ExcelHandler::receiveGoods(const QString &poNo,
                                   int receivedQty, int acceptedQty,
                                   int rejectedQty, const QString &remarks,
                                   const QString &receivedBy)
{
    // Find the PO
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

    QString receiverName = receivedBy.trimmed().isEmpty() ? m_currentUser : receivedBy.trimmed();

    // Generate GRN number
    QString grnNo = "GRN-" + QString::number(m_nextGRNNumber).rightJustified(4, '0');
    m_nextGRNNumber++;
    saveSupplyChainCounters();

    QString partName = targetPO->value("partName").toString();
    QString partNo = targetPO->value("partNo").toString();

    // Create GRN record
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

    // Update PO received quantity
    int prevReceived = targetPO->value("receivedQty").toInt();
    int totalReceived = prevReceived + receivedQty;
    (*targetPO)["receivedQty"] = totalReceived;

    int orderQty = targetPO->value("qty").toInt();
    if (totalReceived >= orderQty) {
        (*targetPO)["status"] = "Received";
    } else {
        (*targetPO)["status"] = "Partially Received";
    }
    (*targetPO)["receivedBy"] = receiverName;
    (*targetPO)["receivedDate"] = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm");

    savePurchaseOrders();
    emit pendingPOCountChanged();

    // Update stock in main table (add accepted quantity)
    // Stock column index = 2
    int partRow = findPartRowByName(partName);
    QString poDepartment = targetPO->value("department").toString().trimmed();
    QString poPreparedBy = targetPO->value("preparedBy").toString().trimmed();
    QString poApprovedBy = targetPO->value("approvedBy").toString().trimmed();
    QString poVendor = targetPO->value("vendor").toString().trimmed();
    double poUnitPrice = targetPO->value("unitPrice").toDouble();

    if (partRow != -1) {
        int currentStock = toStockInt(m_model->getData(partRow, 2));
        m_model->setDataAt(partRow, 2, currentStock + acceptedQty);

    // Keep dashboard columns in correct order:
    // 3=Department, 4=Prepared, 5=Approved, 6=Vendor, 7=Date, 8=Unit Price
    QString receivedDate = (*targetPO)["receivedDate"].toString();
        if (!poDepartment.isEmpty()) m_model->setDataAt(partRow, 3, poDepartment);
        if (!poPreparedBy.isEmpty()) m_model->setDataAt(partRow, 4, poPreparedBy);
        if (!poApprovedBy.isEmpty()) m_model->setDataAt(partRow, 5, poApprovedBy);
        if (!poVendor.isEmpty()) m_model->setDataAt(partRow, 6, poVendor);
        if (!receivedDate.isEmpty()) m_model->setDataAt(partRow, 7, receivedDate);
        if (poUnitPrice > 0.0) m_model->setDataAt(partRow, 8, poUnitPrice);

        qDebug() << "Stock updated:" << partName << currentStock << "->" << (currentStock + acceptedQty);
    } else {
        // Part not found in stock table - add new row
        m_model->addRow();
        int newRow = m_model->rowCount() - 1;
        m_model->setDataAt(newRow, 0, partName);
        m_model->setDataAt(newRow, 1, partNo);
        m_model->setDataAt(newRow, 2, acceptedQty);

        // Correct column placement for dashboard
        m_model->setDataAt(newRow, 3, poDepartment);
        m_model->setDataAt(newRow, 4, poPreparedBy);
        m_model->setDataAt(newRow, 5, poApprovedBy);
        m_model->setDataAt(newRow, 6, poVendor);
        m_model->setDataAt(newRow, 7, (*targetPO)["receivedDate"]);
        if (poUnitPrice > 0.0) m_model->setDataAt(newRow, 8, poUnitPrice);

        qDebug() << "New part added to stock:" << partName << "qty:" << acceptedQty;
    }

    // Log stock movement
    logStockMovement(partName, partNo, "IN", acceptedQty, grnNo + " (from " + poNo + ")", receiverName);

    if (rejectedQty > 0) {
        logStockMovement(partName, partNo, "REJECTED", rejectedQty, grnNo, receiverName);
    }

    // Auto-save to permanent file
    if (!m_permanentFile.isEmpty()) {
        saveToPermanent();
    }

    // Auto-upload to cloud after receiving goods (if enabled)
    if (m_syncEnabled && !m_cloudFolder.isEmpty() && canEdit()) {
        if (m_currentFile.isEmpty() && !m_permanentFile.isEmpty()) {
            m_currentFile = m_permanentFile;
        }
        syncToCloud();
    }

    emit goodsReceived(grnNo, poNo);
    emit lowStockCountChanged();

    qDebug() << "GRN" << grnNo << "created for PO" << poNo
             << "| Accepted:" << acceptedQty << "Rejected:" << rejectedQty;

    return grnNo;
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
    QString path = m_dataDir + "/stock_movements.xlsx";

    if (!QFile::exists(path)) return;

    QXlsx::Document xlsx(path);
    if (!xlsx.load()) return;

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) return;

    QXlsx::CellRange range = sheet->dimension();

    for (int row = 2; row <= range.lastRow(); ++row) {
        QVariantMap mov;
        mov["date"]     = sheet->cellAt(row, 1) ? sheet->cellAt(row, 1)->value().toString() : "";
        mov["partName"] = sheet->cellAt(row, 2) ? sheet->cellAt(row, 2)->value().toString() : "";
        mov["partNo"]   = sheet->cellAt(row, 3) ? sheet->cellAt(row, 3)->value().toString() : "";
        mov["type"]     = sheet->cellAt(row, 4) ? sheet->cellAt(row, 4)->value().toString() : "";
        mov["qty"]      = sheet->cellAt(row, 5) ? sheet->cellAt(row, 5)->value().toInt() : 0;
        mov["reference"]= sheet->cellAt(row, 6) ? sheet->cellAt(row, 6)->value().toString() : "";
        mov["doneBy"]   = sheet->cellAt(row, 7) ? sheet->cellAt(row, 7)->value().toString() : "";

        if (!mov["date"].toString().trimmed().isEmpty()) {
            m_stockMovements.append(mov);
        }
    }

    qDebug() << "Loaded" << m_stockMovements.size() << "stock movements";         
}

void ExcelHandler::saveStockMovements()
{
    QString path = m_dataDir + "/stock_movements.xlsx";
    QXlsx::Document xlsx;

    xlsx.write(1, 1, "Date");
    xlsx.write(1, 2, "Part Name");
    xlsx.write(1, 3, "Part No");
    xlsx.write(1, 4, "Type");
    xlsx.write(1, 5, "Qty");
    xlsx.write(1, 6, "Reference");
    xlsx.write(1, 7, "Done By");

    for (int i = 0; i < m_stockMovements.size(); ++i) {
        int row = i + 2;
        xlsx.write(row, 1, m_stockMovements[i]["date"]);
        xlsx.write(row, 2, m_stockMovements[i]["partName"]);
        xlsx.write(row, 3, m_stockMovements[i]["partNo"]);
        xlsx.write(row, 4, m_stockMovements[i]["type"]);
        xlsx.write(row, 5, m_stockMovements[i]["qty"]);
        xlsx.write(row, 6, m_stockMovements[i]["reference"]);
        xlsx.write(row, 7, m_stockMovements[i]["doneBy"]);
    }

    xlsx.saveAs(path);
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
    saveStockMovements();
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
    QString path = m_dataDir + "/issue_notes.xlsx";

    if (!QFile::exists(path)) return;

    QXlsx::Document xlsx(path);
    if (!xlsx.load()) return;

    QXlsx::Worksheet *sheet = xlsx.currentWorksheet();
    if (!sheet) return;

    QXlsx::CellRange range = sheet->dimension();

    for (int row = 2; row <= range.lastRow(); ++row) {
        QVariantMap note;
        note["issueNo"]    = sheet->cellAt(row, 1) ? sheet->cellAt(row, 1)->value().toString() : "";
        note["date"]       = sheet->cellAt(row, 2) ? sheet->cellAt(row, 2)->value().toString() : "";
        note["partName"]   = sheet->cellAt(row, 3) ? sheet->cellAt(row, 3)->value().toString() : "";
        note["qty"]        = sheet->cellAt(row, 4) ? sheet->cellAt(row, 4)->value().toInt() : 0;
        note["department"] = sheet->cellAt(row, 5) ? sheet->cellAt(row, 5)->value().toString() : "";
        note["issuedBy"]   = sheet->cellAt(row, 6) ? sheet->cellAt(row, 6)->value().toString() : "";

        if (!note["issueNo"].toString().trimmed().isEmpty()) {
            m_issueNotes.append(note);
        }
    }

    qDebug() << "Loaded" << m_issueNotes.size() << "issue notes";
}

void ExcelHandler::saveIssueNotes()
{
    QString path = m_dataDir + "/issue_notes.xlsx";
    QXlsx::Document xlsx;

    xlsx.write(1, 1, "Issue No");
    xlsx.write(1, 2, "Date");
    xlsx.write(1, 3, "Part Name");
    xlsx.write(1, 4, "Qty");
    xlsx.write(1, 5, "Department");
    xlsx.write(1, 6, "Issued By");

    for (int i = 0; i < m_issueNotes.size(); ++i) {
        int row = i + 2;
        xlsx.write(row, 1, m_issueNotes[i]["issueNo"]);
        xlsx.write(row, 2, m_issueNotes[i]["date"]);
        xlsx.write(row, 3, m_issueNotes[i]["partName"]);
        xlsx.write(row, 4, m_issueNotes[i]["qty"]);
        xlsx.write(row, 5, m_issueNotes[i]["department"]);
        xlsx.write(row, 6, m_issueNotes[i]["issuedBy"]);
    }

    xlsx.saveAs(path);
}

QString ExcelHandler::issueStock(const QString &partName, int qty,
                                 const QString &department, const QString &issuedBy)
{
    if (partName.trimmed().isEmpty()) {
        emit errorOccurred("Part name is required");
        return "";
    }

    if (qty <= 0) {
        emit errorOccurred("Quantity must be greater than 0");
        return "";
    }

    // Find part in stock
    int partRow = findPartRowByName(partName);
    if (partRow == -1) {
        emit errorOccurred("Part not found in stock: " + partName);
        return "";
    }

    // Check available stock
    int currentStock = toStockInt(m_model->getData(partRow, 2));
    if (currentStock < qty) {
        emit errorOccurred("Insufficient stock! Available: " + QString::number(currentStock)
                           + ", Requested: " + QString::number(qty));
        return "";
    }

    // Generate issue number
    QString issueNo = "ISS-" + QString::number(m_nextIssueNumber).rightJustified(4, '0');
    m_nextIssueNumber++;
    saveSupplyChainCounters();

    // Deduct stock
    m_model->setDataAt(partRow, 2, currentStock - qty);

    // Create issue note
    QVariantMap note;
    note["issueNo"]    = issueNo;
    note["date"]       = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm");
    note["partName"]   = partName;
    note["qty"]        = qty;
    note["department"] = department;
    note["issuedBy"]   = issuedBy;

    m_issueNotes.append(note);
    saveIssueNotes();

    // Log movement
    QString partNo = m_model->getData(partRow, 1).toString();
    logStockMovement(partName, partNo, "OUT", qty, issueNo + " -> " + department, issuedBy);

    // Auto-save
    if (!m_permanentFile.isEmpty()) {
        saveToPermanent();
    }

    emit stockIssued(issueNo, partName, qty);
    emit lowStockCountChanged();

    qDebug() << "Issued:" << partName << "x" << qty << "to" << department << "(" << issueNo << ")";
    return issueNo;
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

int ExcelHandler::lowStockCount()
{
    // Low stock columns are removed from the main dashboard layout.
    return 0;
}

QVariantList ExcelHandler::getLowStockItems()
{
    return QVariantList();
}

bool ExcelHandler::autoGeneratePOForLowStock()
{
    emit errorOccurred("Low stock auto-generation is disabled for current column layout");
    return false;
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
    if (m_permanentFile.isEmpty()) return;
    saveToPermanent();

    if (m_syncEnabled && !m_cloudFolder.isEmpty() && canEdit()) {
        if (m_currentFile.isEmpty()) m_currentFile = m_permanentFile;
        syncToCloud();
    }
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
    if (m_permanentFile.isEmpty()) return;
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

bool ExcelHandler::syncToCloud()
{
    if (m_cloudFolder.isEmpty()) {
        emit errorOccurred("No cloud folder configured");
        return false;
    }
    if (m_currentFile.isEmpty()) {
        emit errorOccurred("No file loaded");
        return false;
    }
    if (!canEdit()) {
        emit errorOccurred("No permission to upload");
        return false;
    }

    updateSyncStatus("syncing");
    QString cloudFilePath = getCloudFilePath();

    if (QFileInfo(m_currentFile).canonicalFilePath() == QFileInfo(cloudFilePath).canonicalFilePath()) {
        if (saveExcel(m_currentFile)) {
            m_lastSyncTime = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss");
            saveCloudSettings();
            emit lastSyncTimeChanged();
            updateSyncStatus("synced");
            emit syncCompleted(true);
            return true;
        }
        updateSyncStatus("offline");
        return false;
    }

    if (isFileLocked(cloudFilePath)) {
        emit errorOccurred("File locked by another user");
        updateSyncStatus("conflict");
        return false;
    }

    lockFile(cloudFilePath);

    if (!saveExcel(m_currentFile)) {
        unlockFile(cloudFilePath);
        updateSyncStatus("synced");
        return false;
    }

    if (QFile::exists(cloudFilePath)) QFile::remove(cloudFilePath);

    if (QFile::copy(m_currentFile, cloudFilePath)) {
        m_lastSyncTime = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss");
        saveCloudSettings();
        emit lastSyncTimeChanged();
        updateSyncStatus("synced");
        emit syncCompleted(true);
        QTimer::singleShot(1000, [this, cloudFilePath]() { unlockFile(cloudFilePath); });
        return true;
    }

    unlockFile(cloudFilePath);
    emit errorOccurred("Failed to upload to cloud");
    updateSyncStatus("offline");
    return false;
}

bool ExcelHandler::syncFromCloud()
{
    if (m_cloudFolder.isEmpty()) {
        emit errorOccurred("No cloud folder configured");
        return false;
    }

    updateSyncStatus("syncing");
    QString cloudFilePath = getCloudFilePath();

    if (!QFile::exists(cloudFilePath)) {
        emit errorOccurred("No file found in cloud");
        updateSyncStatus("offline");
        return false;
    }

    if (isFileLocked(cloudFilePath)) {
        emit errorOccurred("File locked by another user");
        updateSyncStatus("conflict");
        return false;
    }

    QString originalFile = m_currentFile;

    if (loadExcel(cloudFilePath)) {
        if (!m_permanentFile.isEmpty()) {
            QFile::remove(m_permanentFile);
            if (QFile::copy(cloudFilePath, m_permanentFile)) {
                m_currentFile = m_permanentFile;
            } else {
                m_currentFile = cloudFilePath;
            }
        } else if (!originalFile.isEmpty()) {
            QFile::remove(originalFile);
            if (QFile::copy(cloudFilePath, originalFile)) {
                m_currentFile = originalFile;
            } else {
                m_currentFile = cloudFilePath;
            }
        } else {
            m_currentFile = cloudFilePath;
        }

        m_lastSyncTime = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss");
        saveCloudSettings();
        emit lastSyncTimeChanged();
        emit currentFileChanged();
        updateSyncStatus("synced");
        emit syncCompleted(true);
        return true;
    }

    updateSyncStatus("offline");
    return false;
}

bool ExcelHandler::checkForUpdates()
{
    QString localFile = !m_currentFile.isEmpty() ? m_currentFile : m_permanentFile;
    if (m_cloudFolder.isEmpty() || localFile.isEmpty()) return false;

    QString cloudFilePath = getCloudFilePath();
    if (!QFile::exists(cloudFilePath)) return false;

    QFileInfo localFileInfo(localFile);
    QFileInfo cloudFile(cloudFilePath);

    if (cloudFile.lastModified() > localFileInfo.lastModified()) {
        emit conflictDetected("Cloud file has been updated");
        return true;
    }

    return false;
}
