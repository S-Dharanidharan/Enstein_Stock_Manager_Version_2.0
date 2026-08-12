#ifndef EXCELHANDLER_H
#define EXCELHANDLER_H

#include <QObject>
#include <QAbstractTableModel>
#include <QVariant>
#include <QVector>
#include <QDebug>
#include <QUrl>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QDesktopServices>
#include <QDateTime>
#include <QSet>
#include <QTimer>
#include <xlsxdocument.h>
#include <xlsxworksheet.h>

class DatabaseManager;
class ServerSetup;

// ==================== ExcelTableModel ====================
class ExcelTableModel : public QAbstractTableModel
{
    Q_OBJECT
public:
    explicit ExcelTableModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    bool setData(const QModelIndex &index, const QVariant &value, int role = Qt::EditRole) override;
    Qt::ItemFlags flags(const QModelIndex &index) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setExcelData(const QVector<QVector<QVariant>> &data);
    QVector<QVector<QVariant>> getExcelData() const;

    Q_INVOKABLE QVariant getData(int row, int column) const;
    Q_INVOKABLE bool setDataAt(int row, int column, const QVariant &value);
    Q_INVOKABLE void addRow();
    Q_INVOKABLE bool removeRowAt(int row);
    Q_INVOKABLE void addColumn();
    Q_INVOKABLE void clear();

private:
    QVector<QVector<QVariant>> m_data;
};

// ==================== ExcelHandler ====================
class ExcelHandler : public QObject
{
    Q_OBJECT

    // Existing Properties
    Q_PROPERTY(ExcelTableModel* model READ model CONSTANT)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(bool hasUnsavedChanges READ hasUnsavedChanges NOTIFY unsavedChangesChanged)
    Q_PROPERTY(QString permanentFile READ permanentFile NOTIFY permanentFileChanged)

    // Cloud Sync Properties
    Q_PROPERTY(QString cloudFolder READ cloudFolder WRITE setCloudFolder NOTIFY cloudFolderChanged)
    Q_PROPERTY(bool syncEnabled READ syncEnabled WRITE setSyncEnabled NOTIFY syncEnabledChanged)
    Q_PROPERTY(QString lastSyncTime READ lastSyncTime NOTIFY lastSyncTimeChanged)
    Q_PROPERTY(QString syncStatus READ syncStatus NOTIFY syncStatusChanged)
    Q_PROPERTY(QString currentUser READ currentUser WRITE setCurrentUser NOTIFY currentUserChanged)
    Q_PROPERTY(QString userRole READ userRole WRITE setUserRole NOTIFY userRoleChanged)

    // Supply Chain Properties
    Q_PROPERTY(int lowStockCount READ lowStockCount NOTIFY lowStockCountChanged)
    Q_PROPERTY(int pendingPOCount READ pendingPOCount NOTIFY pendingPOCountChanged)
    Q_PROPERTY(int totalVendors READ totalVendors NOTIFY vendorListChanged)

public:
    explicit ExcelHandler(QObject *parent = nullptr);

    ExcelTableModel* model() const { return m_model; }
    QString currentFile() const { return m_currentFile; }
    bool hasUnsavedChanges() const { return m_hasUnsavedChanges; }
    QString permanentFile() const { return m_permanentFile; }

    // ---- Existing Methods ----
    Q_INVOKABLE void createNew(int rows = 10, int cols = 10);
    Q_INVOKABLE void createStockFile(int rows = 15);
    Q_INVOKABLE void createPurchaseFile(int rows = 15);
    Q_INVOKABLE QString getFileName() const;
    Q_INVOKABLE QString getFileType() const;
    Q_INVOKABLE bool loadExcel(const QString &filePath);
    Q_INVOKABLE bool saveExcel(const QString &filePath = QString());

    Q_INVOKABLE bool setPermanentFile(const QString &filePath);
    Q_INVOKABLE bool loadPermanentFile();
    Q_INVOKABLE bool saveToPermanent();
    Q_INVOKABLE QString getSavedPermanentPath();
    Q_INVOKABLE bool hasSavedPermanentFile();

    // Imports a stock xlsx into the shared database (replaces the old
    // "permanent file" concept: the database is the permanent store now).
    Q_INVOKABLE bool importStockFile(const QString &filePath);

    Q_INVOKABLE bool appendFromFile(const QString &filePath);
    Q_INVOKABLE bool appendStockFile(const QString &filePath);
    Q_INVOKABLE bool validateFileStructure(const QString &filePath);
    Q_INVOKABLE QString browseOpenFile(const QString &title, const QString &filter);
    Q_INVOKABLE QString browseSaveFile(const QString &title, const QString &filter);
    Q_INVOKABLE QString browseFolder(const QString &title);
    Q_INVOKABLE bool exportReport(const QString &fromDate, const QString &toDate, const QString &filePath);

    Q_INVOKABLE int searchPartName(const QString &partName);
    Q_INVOKABLE QVariantList searchAllMatches(const QString &searchText);

    Q_INVOKABLE bool uploadFileForPart(int row, const QString &filePath);
    Q_INVOKABLE QString getUploadedFilePath(int row);
    Q_INVOKABLE bool openUploadedFile(int row);
    Q_INVOKABLE bool hasUploadedFile(int row);

    Q_INVOKABLE void addNewItem(const QString &partName,
                                const QString &category,
                                int quantity,
                                double unitPrice);
    Q_INVOKABLE int getNextSerialNumber() const;

    // ---- Authentication (backed by the shared users table) ----
    Q_INVOKABLE QString login(const QString &username, const QString &password);

    // ---- Database connection settings ----
    Q_INVOKABLE QVariantMap getDatabaseSettings() const;
    Q_INVOKABLE bool configureDatabase(const QString &driver,
                                       const QString &host, int port,
                                       const QString &name,
                                       const QString &user, const QString &password);
    Q_INVOKABLE QString databaseStatus() const;
    Q_INVOKABLE bool isDatabaseConnected() const;
    // True only when actually connected to a shared server (PostgreSQL), not
    // the local SQLite fallback. Lets the UI detect a silent fallback.
    Q_INVOKABLE bool isDatabaseServerBackend() const;
    // Human-readable reason the last connection attempt failed (empty if none).
    Q_INVOKABLE QString databaseLastError() const;
    // Reloads all supply-chain caches from the database (pull latest in multi-user).
    Q_INVOKABLE void refreshFromDatabase();

    // ---- LAN server provisioning ----
    // Turns this computer into the shared PostgreSQL server for every other
    // installation of the app. Runs asynchronously; connect to
    // serverProvisionProgress()/serverProvisionFinished() for status.
    Q_INVOKABLE void setupThisComputerAsServer();
    Q_INVOKABLE bool isServerProvisioned() const;
    Q_INVOKABLE QString serverLanAddressHint() const;

    // ---- Cloud Sync (deprecated: storage now lives in the shared database) ----
    Q_INVOKABLE bool syncToCloud();
    Q_INVOKABLE bool syncFromCloud();
    Q_INVOKABLE bool checkForUpdates();
    Q_INVOKABLE QString getCloudFilePath() const;
    Q_INVOKABLE bool canEdit() const;
    Q_INVOKABLE void setCloudFolder(const QString &folder);
    Q_INVOKABLE void setCurrentUser(const QString &username);
    Q_INVOKABLE void setUserRole(const QString &role);
    Q_INVOKABLE void setSyncEnabled(bool enabled);

    QString cloudFolder() const { return m_cloudFolder; }
    bool syncEnabled() const { return m_syncEnabled; }
    QString lastSyncTime() const { return m_lastSyncTime; }
    QString syncStatus() const { return m_syncStatus; }
    QString currentUser() const { return m_currentUser; }
    QString userRole() const { return m_userRole; }

    // ==================== SUPPLY CHAIN METHODS ====================

    // ---- Vendor Management ----
    Q_INVOKABLE bool addVendorDetails(QVariantMap vendor);
    Q_INVOKABLE bool updateVendorDetails(QVariantMap vendor);

    Q_INVOKABLE bool deleteVendor(const QString &name);
    Q_INVOKABLE QVariantList getVendorList();
    Q_INVOKABLE QStringList getVendorNames();
    Q_INVOKABLE QVariantMap getVendorByName(const QString &name);
    int totalVendors() const { return m_vendors.size(); }
    
    // ---- Item Master Management ----
    Q_INVOKABLE bool addItemMasterDetails(QVariantMap itemDetails);
    Q_INVOKABLE bool updateItemMasterDetails(QVariantMap itemDetails);
    Q_INVOKABLE QVariantList getItemMasterList();
    Q_INVOKABLE bool deleteItem(const QString &partName);
    //Q_INVOKABLE bool updateItemMasterDetails(const QString &partNo, QVariantMap itemDetails);

    // ---- Purchase Order Management ----
    // One PO holding several line items; each item carries its own vendor.
    // items: list of maps {partName, partNo, vendor, department, qty, unitPrice}
    Q_INVOKABLE QString createPurchaseOrderItems(const QVariantList &items,
                                                 const QString &expectedDate,
                                                 const QString &preparedBy = "");
    Q_INVOKABLE QVariantList getPOItems(const QString &poNo);

    // Legacy single-item entry point (delegates to createPurchaseOrderItems).
    Q_INVOKABLE QString createPurchaseOrder(const QString &vendor,
                                            const QString &partName,
                                            const QString &partNo,
                                            int qty, double unitPrice,
                                            const QString &expectedDate,
                                            const QString &department = "",
                                            const QString &preparedBy = "");
    Q_INVOKABLE bool sendPOForApproval(const QString &poNo, const QString &approvedBy);
    Q_INVOKABLE QVariantList getPOList(const QString &statusFilter = "");
    Q_INVOKABLE bool updatePOStatus(const QString &poNo, const QString &newStatus);
    Q_INVOKABLE bool updatePurchaseOrder(const QString &poNo, const QVariantMap &poDetails);
    Q_INVOKABLE QVariantMap getPOByNumber(const QString &poNo);
    Q_INVOKABLE QString getNextPONumber();
    int pendingPOCount() const;

    // ---- Goods Receipt Note (GRN) ----
    // Receive against a specific PO line item (multi-item POs).
    Q_INVOKABLE QString receiveGoodsForItem(int itemId,
                                            int receivedQty, int acceptedQty,
                                            int rejectedQty, const QString &remarks,
                                            const QString &receivedBy = "");
    // Legacy whole-PO entry point (delegates to the first open line).
    Q_INVOKABLE QString receiveGoods(const QString &poNo,
                                     int receivedQty, int acceptedQty,
                                     int rejectedQty, const QString &remarks,
                                     const QString &receivedBy = "");
    Q_INVOKABLE QVariantList getGRNList();

    // ---- Stock Movement Log ----
    Q_INVOKABLE bool logStockMovement(const QString &partName, const QString &partNo,
                                      const QString &movementType, int qty,
                                      const QString &reference, const QString &doneBy);
    Q_INVOKABLE QVariantList getStockMovements(const QString &partNameFilter = "");
    Q_INVOKABLE QVariantList getAllMovements();

    // ---- Material Issue ----
    // Issue several parts to one department under a single issue number.
    // items: list of maps {partName, qty}
    Q_INVOKABLE QString issueMultipleStock(const QVariantList &items,
                                           const QString &department,
                                           const QString &issuedBy);
    Q_INVOKABLE QString issueStock(const QString &partName, int qty,
                                   const QString &department, const QString &issuedBy);
    Q_INVOKABLE QVariantList getIssueNotes();

    // ---- Low Stock Alerts ----
    Q_INVOKABLE QVariantList getLowStockItems();
    Q_INVOKABLE int lowStockCount();
    Q_INVOKABLE bool autoGeneratePOForLowStock();

signals:
    void currentFileChanged();
    void unsavedChangesChanged();
    void permanentFileChanged();
    void errorOccurred(const QString &error);
    void fileLoaded(const QString &fileName);
    void fileSaved(const QString &fileName);
    void fileMerged(const QString &fileName, int rowsAdded, int rowsUpdated);
    void searchResultFound(int row);

    // Cloud signals
    void cloudFolderChanged();
    void syncEnabledChanged();
    void lastSyncTimeChanged();
    void syncStatusChanged();
    void currentUserChanged();
    void userRoleChanged();
    void syncCompleted(bool success);
    void conflictDetected(const QString &message);

    // LAN server provisioning
    void serverProvisionProgress(const QString &message);
    void serverProvisionFinished(bool success, const QVariantMap &result);

    // Supply Chain signals
    void lowStockCountChanged();
    void pendingPOCountChanged();
    void vendorListChanged();
    void itemMasterListChanged();
    void purchaseOrderCreated(const QString &poNo);
    void goodsReceived(const QString &grnNo, const QString &poNo);
    void stockIssued(const QString &issueNo, const QString &partName, int qty);
    void movementLogged(const QString &partName, const QString &type, int qty);

private slots:
    void onModelDataChanged();                           
    void autoSavePermanent();
    void autoSyncFromCloud();

private:
    DatabaseManager *m_db;
    ServerSetup *m_serverSetup;
    ExcelTableModel *m_model;
    QString m_currentFile;
    QString m_permanentFile;
    bool m_hasUnsavedChanges;
    QString m_uploadsDir;

    // Cloud sync
    QString m_cloudFolder;
    bool m_syncEnabled;
    QString m_lastSyncTime;
    QString m_syncStatus;
    QString m_currentUser;
    QString m_userRole;

    // Supply Chain Data (in-memory caches of the database tables)
    QVector<QVariantMap> m_vendors;
    QVector<QVariantMap> m_itemMaster;
    QVector<QVariantMap> m_purchaseOrders;
    QVector<QVariantMap> m_poItems;        // line items of all POs
    QVector<QVariantMap> m_stockMovements;
    QVector<QVariantMap> m_issueNotes;
    QVector<QVariantMap> m_grnRecords;
    
    // Counters
    int m_nextPONumber;
    int m_nextGRNNumber;
    int m_nextIssueNumber;

    // Supply Chain file paths
    QString m_dataDir;
    QTimer m_autoSaveTimer;
    QTimer m_cloudPollTimer;

    // Existing helpers
    void setUnsavedChanges(bool changed);
    QString cleanFilePath(const QString &path);
    void recalculateSerialNumbers();
    void scheduleAutoSave();
    void savePermanentFileSettings();
    void loadPermanentFileSettings();
    void updateAutoSyncState();
    void initializeUploadsDirectory();
    int findPartByName(const QString &partName);
    bool updateExistingPart(int row, const QVector<QVariant> &newData);

    // Cloud helpers
    void updateSyncStatus(const QString &status);
    void saveCloudSettings();
    void loadCloudSettings();
    bool isFileLocked(const QString &filePath) const;
    bool lockFile(const QString &filePath);
    bool unlockFile(const QString &filePath);

    // Supply Chain helpers
    void initializeDataDirectory();
    void loadVendors();
    bool saveVendors();
    void loadItemMaster();
    void saveItemMaster();

    void loadPurchaseOrders();
    void savePurchaseOrders();
    void loadPOItems();
    // Stock grid persistence in the shared database.
    bool loadStockFromDb();
    void saveStockToDb();
    // Recomputes a PO header's qty/total/received/summary from its lines.
    void recalcPOHeader(QVariantMap &po);
    // Resolves blanks in a PO line from the item master; returns false with
    // an error emitted when validation fails.
    bool resolvePOLine(QVariantMap &line);
    void loadStockMovements();
    void saveStockMovements();
    void loadIssueNotes();
    void saveIssueNotes();
    void loadGRNRecords();
    void saveGRNRecords();
    void loadSupplyChainCounters();
    void saveSupplyChainCounters();
    int findPartRowByName(const QString &partName);
};

#endif // EXCELHANDLER_H
