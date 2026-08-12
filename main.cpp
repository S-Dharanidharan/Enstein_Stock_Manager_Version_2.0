#include <QApplication>
#include <QQmlApplicationEngine>
#include <QUrl>
#include <QIcon>
#include <QFile>
#include "excelhandler.h"

#ifndef APP_VERSION_STR
#define APP_VERSION_STR "2.1.4"
#endif

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    // The icon is compiled into the binary, so a packaged build shows it with
    // no loose file next to the exe. The on-disk paths remain as a fallback for
    // running straight out of a source tree.
    QIcon appIcon(QStringLiteral(":/app-icon.png"));
    if (appIcon.isNull()) {
        QString iconPath = QCoreApplication::applicationDirPath() + "/app-icon.png";
        if (!QFile::exists(iconPath))
            iconPath = QStringLiteral("assets/app-icon.png");
        if (QFile::exists(iconPath))
            appIcon = QIcon(iconPath);
    }
    if (!appIcon.isNull())
        app.setWindowIcon(appIcon);

    QCoreApplication::setOrganizationName("Enstein Robots and Automations Pvt Limited");
    QCoreApplication::setApplicationName("Enstein Stock Manager");
    QCoreApplication::setApplicationVersion(QStringLiteral(APP_VERSION_STR));

    qmlRegisterType<ExcelHandler>("ExcelHandler", 1, 0, "ExcelHandler");

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/Enstein/Main.qml")));

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
