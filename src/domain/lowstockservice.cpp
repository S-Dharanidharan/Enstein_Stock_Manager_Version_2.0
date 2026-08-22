#include "domain/lowstockservice.h"

#include "core/appsettings.h"
#include "domain/itemmasterservice.h"
#include "domain/purchaseorderservice.h"
#include "domain/stockservice.h"
#include "models/exceltablemodel.h"

#include <QDateTime>
#include <QVariant>

// Stock cells can hold a quantity typed as text, so every read goes here.
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

QVariantList LowStockService::items()
{
    QVariantList list;

    // Quantity already on order per part (open POs only) so the same
    // shortage is not ordered twice.
    QSet<QString> openPOs;
    for (const auto &po : m_po->orders()) {
        const QString st = po["status"].toString().toLower();
        if (st == "draft" || st == "sent" || st == "partially received")
            openPOs.insert(po["poNo"].toString());
    }
    QHash<QString, int> onOrder;
    for (const auto &line : m_po->lineItems()) {
        if (!openPOs.contains(line["poNo"].toString())) continue;
        int remaining = line["qty"].toInt() - line["receivedQty"].toInt();
        if (remaining > 0)
            onOrder[line["partName"].toString().trimmed().toLower()] += remaining;
    }

    // An item is low when current stock plus open orders cannot cover the
    // required quantity defined in the Item Master.
    for (const auto &item : m_itemMaster->rows()) {
        const int required = item["requiredQty"].toInt();
        if (required <= 0) continue;
        const QString partName = item["partName"].toString().trimmed();
        if (partName.isEmpty()) continue;

        int stock = 0;
        int row = m_stock->findRowByName(partName);
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

int LowStockService::count()
{
    return items().size();
}

bool LowStockService::autoGeneratePO()
{
    const QVariantList low = items();
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
    const QString poNo = m_po->createWithItems(items, expected, m_session->currentUser());
    if (poNo.isEmpty()) return false;

    if (!skipped.isEmpty())
        emit errorOccurred("PO " + poNo + " created. Skipped (no vendor in Item Master): " +
                           skipped.join(", "));

    qDebug() << "Auto-generated" << poNo << "for" << items.size() << "low stock items";
    return true;
}

