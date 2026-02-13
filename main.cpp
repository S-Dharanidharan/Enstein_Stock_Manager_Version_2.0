#include <QApplication>
#include <QQmlApplicationEngine>
#include <QUrl>
#include <QIcon>
#include <QFile>
#include "excelhandler.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    // Optional runtime icon for packaged builds (Windows/Linux).
    QString iconPath = QCoreApplication::applicationDirPath() + "/app-icon.png";
    if (!QFile::exists(iconPath))
        iconPath = "assets/app-icon.png";
    if (QFile::exists(iconPath))
        app.setWindowIcon(QIcon(iconPath));

    QCoreApplication::setOrganizationName("Enstein Robots and Automations Pvt Limited");
    QCoreApplication::setApplicationName("Enstein Stock Manager");
    QCoreApplication::setApplicationVersion("2.0.0");

    qmlRegisterType<ExcelHandler>("ExcelHandler", 1, 0, "ExcelHandler");

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/Enstein/Main.qml")));

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
