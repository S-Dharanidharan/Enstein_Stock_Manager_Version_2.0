#include "dbmanager.h"

#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QSqlField>
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QCryptographicHash>
#include <QDebug>

namespace {
const char *kConnectionName = "stockmanager_conn";
const char *kPasswordSalt   = "enstein_stock_salt_v2";
}

DatabaseManager::DatabaseManager(QObject *parent)
    : QObject(parent),
      m_connectionName(kConnectionName)
{
}

DatabaseManager::~DatabaseManager()
{
    if (QSqlDatabase::contains(m_connectionName)) {
        {
            QSqlDatabase db = QSqlDatabase::database(m_connectionName, false);
            if (db.isOpen()) db.close();
        }
        QSqlDatabase::removeDatabase(m_connectionName);
    }
}

QSqlDatabase DatabaseManager::database() const
{
    return QSqlDatabase::database(m_connectionName, false);
}

bool DatabaseManager::isConnected() const { return m_connected; }
bool DatabaseManager::isServerBackend() const { return m_serverBackend; }
QString DatabaseManager::backendName() const { return m_backendLabel; }
bool DatabaseManager::isPostgres() const { return m_driver == "QPSQL"; }

void DatabaseManager::setError(const QString &context, const QString &detail)
{
    m_lastError = context + ": " + detail;
    qWarning() << "[DatabaseManager]" << m_lastError;
    emit databaseError(m_lastError);
}

QString DatabaseManager::hashPassword(const QString &plain) const
{
    const QByteArray salted = (plain + QString::fromLatin1(kPasswordSalt)).toUtf8();
    return QString::fromLatin1(
        QCryptographicHash::hash(salted, QCryptographicHash::Sha256).toHex());
}

// ==================== Connection ====================

QVariantMap DatabaseManager::connectionSettings() const
{
    QSettings settings("EinsteinRobotics", "StockManager");
    QVariantMap map;
    map["driver"]   = settings.value("database/driver", "QSQLITE").toString();
    map["host"]     = settings.value("database/host", "").toString();
    map["port"]     = settings.value("database/port", 5432).toInt();
    map["name"]     = settings.value("database/name", "stockmanager").toString();
    map["user"]     = settings.value("database/user", "").toString();
    map["password"] = settings.value("database/password", "").toString();
    return map;
}

bool DatabaseManager::configureConnection(const QString &driver,
                                          const QString &host, int port,
                                          const QString &name,
                                          const QString &user, const QString &password)
{
    QSettings settings("EinsteinRobotics", "StockManager");
    settings.setValue("database/driver", driver);
    settings.setValue("database/host", host);
    settings.setValue("database/port", port);
    settings.setValue("database/name", name);
    settings.setValue("database/user", user);
    settings.setValue("database/password", password);
    settings.sync();
    return connectDatabase();
}

bool DatabaseManager::connectDatabase()
{
    // Tear down any existing connection first (supports reconnect).
    if (QSqlDatabase::contains(m_connectionName)) {
        {
            QSqlDatabase old = QSqlDatabase::database(m_connectionName, false);
            if (old.isOpen()) old.close();
        }
        QSqlDatabase::removeDatabase(m_connectionName);
    }
    m_connected = false;

    const QVariantMap cfg = connectionSettings();
    m_driver = cfg.value("driver").toString(); 
    if (m_driver.isEmpty()) m_driver = "QSQLITE";

    auto openLocalSqlite = [this]() -> bool {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(dir);
        const QString path = dir + "/stockmanager.db";

        m_driver = "QSQLITE";
        QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", m_connectionName);
        db.setDatabaseName(path);
        if (!db.open()) {
            setError("Open local SQLite", db.lastError().text());
            return false;
        }
        QSqlQuery(db).exec("PRAGMA foreign_keys = ON");
        m_serverBackend = false;
        m_backendLabel = "SQLite (local: " + path + ")";
        return true;
    };

    bool opened = false;
    if (m_driver == "QSQLITE") {
        opened = openLocalSqlite();
    } else {
        // Server backend (Postgres/MySQL/...).
        if (!QSqlDatabase::isDriverAvailable(m_driver)) {
            setError("SQL driver", m_driver + " is not available in this build");
            opened = openLocalSqlite();   // stay usable offline
        } else {
            QSqlDatabase db = QSqlDatabase::addDatabase(m_driver, m_connectionName);
            db.setHostName(cfg.value("host").toString());
            db.setPort(cfg.value("port").toInt());
            db.setDatabaseName(cfg.value("name").toString());
            db.setUserName(cfg.value("user").toString());
            db.setPassword(cfg.value("password").toString());
            if (!db.open()) {
                setError("Connect to " + m_driver, db.lastError().text());
                if (QSqlDatabase::contains(m_connectionName))
                    QSqlDatabase::removeDatabase(m_connectionName);
                opened = openLocalSqlite();   // fall back to local so the app still runs
            } else {
                m_serverBackend = true;
                m_backendLabel = QString("%1 (%2/%3)")
                                     .arg(m_driver == "QPSQL" ? "PostgreSQL" : m_driver,
                                          cfg.value("host").toString(),
                                          cfg.value("name").toString());
                opened = true;
            }
        }
    }

    if (!opened) {
        emit connectionChanged(false);
        return false;
    }

    if (!createSchema()) {
        emit connectionChanged(false);
        return false;
    }
    seedDefaults();

    m_connected = true;
    qInfo() << "[DatabaseManager] Connected to" << m_backendLabel;
    emit connectionChanged(true);
    return true;
}

// ==================== Schema ====================

bool DatabaseManager::createSchema()
{
    QSqlDatabase db = database();
    QSqlQuery q(db);

    // Serial primary key differs between backends.
    const QString serialPk = isPostgres() ? "BIGSERIAL PRIMARY KEY"
                                           : "INTEGER PRIMARY KEY AUTOINCREMENT";

    const QStringList ddl = {
        "CREATE TABLE IF NOT EXISTS users ("
        "  username TEXT PRIMARY KEY,"
        "  password_hash TEXT,"
        "  role TEXT,"
        "  display_name TEXT)",

        "CREATE TABLE IF NOT EXISTS counters ("
        "  name TEXT PRIMARY KEY,"
        "  value INTEGER)",

        "CREATE TABLE IF NOT EXISTS vendors ("
        "  vendor_name TEXT PRIMARY KEY,"
        "  vendor_address TEXT,"
        "  bank_branch TEXT,"
        "  ifsc TEXT,"
        "  account_number TEXT,"
        "  cin TEXT,"
        "  gstin TEXT,"
        "  pan_number TEXT,"
        "  pan_name TEXT,"
        "  contact_person TEXT,"
        "  email TEXT,"
        "  phone TEXT,"
        "  item_category TEXT)",

        "CREATE TABLE IF NOT EXISTS item_master ("
        "  part_no TEXT PRIMARY KEY,"
        "  part_name TEXT,"
        "  category TEXT,"
        "  department TEXT,"
        "  vendor TEXT,"
        "  required_qty INTEGER,"
        "  unit_price DOUBLE PRECISION,"
        "  stock_qty INTEGER)",

        "CREATE TABLE IF NOT EXISTS purchase_orders ("
        "  po_no TEXT PRIMARY KEY,"
        "  po_date TEXT,"
        "  vendor TEXT,"
        "  part_name TEXT,"
        "  part_no TEXT,"
        "  department TEXT,"
        "  qty INTEGER,"
        "  unit_price DOUBLE PRECISION,"
        "  total_amount DOUBLE PRECISION,"
        "  expected_date TEXT,"
        "  status TEXT,"
        "  received_qty INTEGER,"
        "  prepared_by TEXT,"
        "  approved_by TEXT,"
        "  received_by TEXT,"
        "  received_date TEXT)",

        // Line items of a purchase order: one PO can hold many parts, each
        // with its own vendor, quantity and price.
        "CREATE TABLE IF NOT EXISTS po_items ("
        "  id " + serialPk + ","
        "  po_no TEXT,"
        "  part_name TEXT,"
        "  part_no TEXT,"
        "  vendor TEXT,"
        "  department TEXT,"
        "  qty INTEGER,"
        "  unit_price DOUBLE PRECISION,"
        "  total_amount DOUBLE PRECISION,"
        "  received_qty INTEGER)",

        "CREATE TABLE IF NOT EXISTS grn_records ("
        "  grn_no TEXT PRIMARY KEY,"
        "  po_no TEXT,"
        "  grn_date TEXT,"
        "  part_name TEXT,"
        "  received_qty INTEGER,"
        "  accepted_qty INTEGER,"
        "  rejected_qty INTEGER,"
        "  remarks TEXT,"
        "  received_by TEXT)",

        "CREATE TABLE IF NOT EXISTS stock_movements ("
        "  id " + serialPk + ","
        "  mov_date TEXT,"
        "  part_name TEXT,"
        "  part_no TEXT,"
        "  type TEXT,"
        "  qty INTEGER,"
        "  reference TEXT,"
        "  done_by TEXT)",

        // The main stock dashboard grid. Rows live in the shared database so
        // every user sees the same stock; xlsx files are import/export only.
        "CREATE TABLE IF NOT EXISTS stock_rows ("
        "  id " + serialPk + ","
        "  part_name TEXT,"
        "  part_no TEXT,"
        "  stock INTEGER,"
        "  department TEXT,"
        "  prepared TEXT,"
        "  approved TEXT,"
        "  vendor TEXT,"
        "  row_date TEXT,"
        "  unit_price DOUBLE PRECISION)",

        // One material issue (issue_no) can contain several part lines, so
        // the primary key is a plain serial id, not the issue number.
        "CREATE TABLE IF NOT EXISTS issue_notes ("
        "  id " + serialPk + ","
        "  issue_no TEXT,"
        "  issue_date TEXT,"
        "  part_name TEXT,"
        "  qty INTEGER,"
        "  department TEXT,"
        "  issued_by TEXT)"
    };

    for (const QString &stmt : ddl) {
        if (!q.exec(stmt)) {
            setError("Create schema", q.lastError().text());
            return false;
        }
    }

    return migrateSchema();
}

bool DatabaseManager::tableHasColumn(const QString &table, const QString &column)
{
    QSqlDatabase db = database();
    QSqlQuery q(db);

    if (isPostgres()) {
        q.prepare("SELECT 1 FROM information_schema.columns "
                  "WHERE table_name = ? AND column_name = ?");
        q.addBindValue(table);
        q.addBindValue(column);
        if (!q.exec()) return false;
        return q.next();
    }

    // SQLite
    if (!q.exec("PRAGMA table_info(" + table + ")")) return false;
    while (q.next()) {
        if (q.value(1).toString().compare(column, Qt::CaseInsensitive) == 0)
            return true;
    }
    return false;
}

// Upgrades databases created by earlier versions of the app in place.
bool DatabaseManager::migrateSchema()
{
    QSqlDatabase db = database();
    QSqlQuery q(db);

    const QString serialPk = isPostgres() ? "BIGSERIAL PRIMARY KEY"
                                           : "INTEGER PRIMARY KEY AUTOINCREMENT";

    // v1 -> v2: issue_notes used issue_no as primary key (one line per
    // issue). Rebuild it with a serial id so an issue can hold many lines.
    if (!tableHasColumn("issue_notes", "id")) {
        const QStringList steps = {
            "ALTER TABLE issue_notes RENAME TO issue_notes_old",
            "CREATE TABLE issue_notes ("
            "  id " + serialPk + ","
            "  issue_no TEXT,"
            "  issue_date TEXT,"
            "  part_name TEXT,"
            "  qty INTEGER,"
            "  department TEXT,"
            "  issued_by TEXT)",
            "INSERT INTO issue_notes (issue_no, issue_date, part_name, qty, department, issued_by) "
            "SELECT issue_no, issue_date, part_name, qty, department, issued_by FROM issue_notes_old",
            "DROP TABLE issue_notes_old"
        };
        for (const QString &stmt : steps) {
            if (!q.exec(stmt)) {
                setError("Migrate issue_notes", q.lastError().text());
                return false;
            }
        }
        qInfo() << "[DatabaseManager] Migrated issue_notes to multi-line schema";
    }

    // v1 -> v2: purchase orders created before line items existed get one
    // po_items row synthesised from their header. Idempotent.
    if (!q.exec("INSERT INTO po_items (po_no, part_name, part_no, vendor, department, "
                "qty, unit_price, total_amount, received_qty) "
                "SELECT p.po_no, p.part_name, p.part_no, p.vendor, p.department, "
                "p.qty, p.unit_price, p.total_amount, p.received_qty "
                "FROM purchase_orders p "
                "WHERE NOT EXISTS (SELECT 1 FROM po_items i WHERE i.po_no = p.po_no)")) {
        setError("Backfill po_items", q.lastError().text());
        return false;
    }

    return true;
}

void DatabaseManager::seedDefaults()
{
    // Default administrator so the app is usable on a fresh database.
    ensureUser("admin", "admin123", "owner", "Administrator");
}

// ==================== Generic table access ====================

QVector<QVariantMap> DatabaseManager::selectAll(const QString &table, const QString &orderBy)
{
    QVector<QVariantMap> rows;
    QSqlDatabase db = database();
    if (!db.isOpen()) return rows;

    QString sql = "SELECT * FROM " + table;
    if (!orderBy.isEmpty()) sql += " ORDER BY " + orderBy;

    QSqlQuery q(db);
    if (!q.exec(sql)) {
        setError("Select from " + table, q.lastError().text());
        return rows;
    }

    while (q.next()) {
        const QSqlRecord rec = q.record();
        QVariantMap row;
        for (int i = 0; i < rec.count(); ++i)
            row[rec.fieldName(i)] = q.value(i);
        rows.append(row);
    }
    return rows;
}

bool DatabaseManager::replaceAll(const QString &table, const QVector<QVariantMap> &rows)
{
    QSqlDatabase db = database();
    if (!db.isOpen()) return false;

    if (!db.transaction()) {
        setError("Begin transaction on " + table, db.lastError().text());
        return false;
    }

    QSqlQuery del(db);
    if (!del.exec("DELETE FROM " + table)) {
        setError("Clear " + table, del.lastError().text());
        db.rollback();
        return false;
    }

    if (!rows.isEmpty()) {
        // Column order is derived from the (stable, sorted) map keys.
        const QStringList cols = rows.first().keys();
        QStringList placeholders;
        for (int i = 0; i < cols.size(); ++i) placeholders << "?";

        const QString sql = "INSERT INTO " + table + " (" + cols.join(", ") +
                            ") VALUES (" + placeholders.join(", ") + ")";

        QSqlQuery ins(db);
        for (const QVariantMap &row : rows) {
            ins.prepare(sql);
            for (const QString &col : cols)
                ins.addBindValue(row.value(col));
            if (!ins.exec()) {
                setError("Insert into " + table, ins.lastError().text());
                db.rollback();
                return false;
            }
        }
    }

    if (!db.commit()) {
        setError("Commit " + table, db.lastError().text());
        db.rollback();
        return false;
    }
    return true;
}

bool DatabaseManager::upsert(const QString &table, const QStringList &keyCols, const QVariantMap &row)
{
    QSqlDatabase db = database();
    if (!db.isOpen()) return false;

    // Portable upsert: try UPDATE, INSERT if nothing was updated.
    QStringList setClauses;
    QStringList setCols;
    for (auto it = row.constBegin(); it != row.constEnd(); ++it) {
        if (keyCols.contains(it.key())) continue;
        setClauses << (it.key() + " = ?");
        setCols << it.key();
    }

    QStringList whereClauses;
    for (const QString &k : keyCols) whereClauses << (k + " = ?");

    bool didUpdate = false;
    if (!setClauses.isEmpty()) {
        const QString sql = "UPDATE " + table + " SET " + setClauses.join(", ") +
                            " WHERE " + whereClauses.join(" AND ");
        QSqlQuery upd(db);
        upd.prepare(sql);
        for (const QString &c : setCols) upd.addBindValue(row.value(c));
        for (const QString &k : keyCols) upd.addBindValue(row.value(k));
        if (!upd.exec()) {
            setError("Update " + table, upd.lastError().text());
            return false;
        }
        didUpdate = upd.numRowsAffected() > 0;
    }

    if (didUpdate) return true;

    const QStringList cols = row.keys();
    QStringList placeholders;
    for (int i = 0; i < cols.size(); ++i) placeholders << "?";
    const QString sql = "INSERT INTO " + table + " (" + cols.join(", ") +
                        ") VALUES (" + placeholders.join(", ") + ")";
    QSqlQuery ins(db);
    ins.prepare(sql);
    for (const QString &c : cols) ins.addBindValue(row.value(c));
    if (!ins.exec()) {
        setError("Insert into " + table, ins.lastError().text());
        return false;
    }
    return true;
}

bool DatabaseManager::insert(const QString &table, const QVariantMap &row)
{
    QSqlDatabase db = database();
    if (!db.isOpen() || row.isEmpty()) return false;

    const QStringList cols = row.keys();
    QStringList placeholders;
    for (int i = 0; i < cols.size(); ++i) placeholders << "?";
    const QString sql = "INSERT INTO " + table + " (" + cols.join(", ") +
                        ") VALUES (" + placeholders.join(", ") + ")";
    QSqlQuery q(db);
    q.prepare(sql);
    for (const QString &c : cols) q.addBindValue(row.value(c));
    if (!q.exec()) {
        setError("Insert into " + table, q.lastError().text());
        return false;
    }
    return true;
}

bool DatabaseManager::removeRow(const QString &table, const QString &keyCol, const QVariant &keyVal)
{
    QSqlDatabase db = database();
    if (!db.isOpen()) return false;

    QSqlQuery q(db);
    q.prepare("DELETE FROM " + table + " WHERE " + keyCol + " = ?");
    q.addBindValue(keyVal);
    if (!q.exec()) {
        setError("Delete from " + table, q.lastError().text());
        return false;
    }
    return true;
}

// ==================== Counters ====================

int DatabaseManager::nextCounter(const QString &name)
{
    QSqlDatabase db = database();
    if (!db.isOpen()) return 1;

    db.transaction();

    QString sel = "SELECT value FROM counters WHERE name = ?";
    if (isPostgres()) sel += " FOR UPDATE";

    QSqlQuery q(db);
    q.prepare(sel);
    q.addBindValue(name);
    if (!q.exec()) {
        setError("Read counter " + name, q.lastError().text());
        db.rollback();
        return 1;
    }

    int current = 1;
    if (q.next()) {
        current = q.value(0).toInt();
        QSqlQuery u(db);
        u.prepare("UPDATE counters SET value = ? WHERE name = ?");
        u.addBindValue(current + 1);
        u.addBindValue(name);
        u.exec();
    } else {
        QSqlQuery ins(db);
        ins.prepare("INSERT INTO counters (name, value) VALUES (?, ?)");
        ins.addBindValue(name);
        ins.addBindValue(current + 1);
        ins.exec();
    }

    db.commit();
    return current;
}

int DatabaseManager::peekCounter(const QString &name)
{
    QSqlDatabase db = database();
    if (!db.isOpen()) return 1;

    QSqlQuery q(db);
    q.prepare("SELECT value FROM counters WHERE name = ?");
    q.addBindValue(name);
    if (q.exec() && q.next())
        return q.value(0).toInt();
    return 1;
}

// ==================== Users / authentication ====================

bool DatabaseManager::ensureUser(const QString &username, const QString &plainPassword,
                                 const QString &role, const QString &displayName)
{
    QSqlDatabase db = database();
    if (!db.isOpen()) return false;

    QSqlQuery check(db);
    check.prepare("SELECT username FROM users WHERE username = ?");
    check.addBindValue(username);
    if (check.exec() && check.next())
        return true;   // already exists, leave it untouched

    QSqlQuery ins(db);
    ins.prepare("INSERT INTO users (username, password_hash, role, display_name) "
                "VALUES (?, ?, ?, ?)");
    ins.addBindValue(username);
    ins.addBindValue(hashPassword(plainPassword));
    ins.addBindValue(role);
    ins.addBindValue(displayName.isEmpty() ? username : displayName);
    if (!ins.exec()) {
        setError("Create user " + username, ins.lastError().text());
        return false;
    }
    return true;
}

QString DatabaseManager::authenticate(const QString &username, const QString &plainPassword)
{
    QSqlDatabase db = database();
    if (!db.isOpen()) return QString();

    QSqlQuery q(db);
    q.prepare("SELECT role, password_hash FROM users WHERE username = ?");
    q.addBindValue(username);
    if (!q.exec() || !q.next())
        return QString();

    const QString role = q.value(0).toString();
    const QString stored = q.value(1).toString();
    if (stored == hashPassword(plainPassword))
        return role.isEmpty() ? QString("editor") : role;
    return QString();
}
