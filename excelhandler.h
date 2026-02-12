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

    // ---- Cloud Sync ----
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

    // Supply Chain Data (in-memory, saved to xlsx files)
    QVector<QVariantMap> m_vendors;
    QVector<QVariantMap> m_itemMaster;
    QVector<QVariantMap> m_purchaseOrders;
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
