#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusUnixFileDescriptor>
#include <QFile>
#include <QImage>
#include <QJsonDocument>
#include <QJsonObject>
#include <QThread>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    const QString output = argc > 1 ? QString::fromLocal8Bit(argv[1])
                                    : QStringLiteral("/tmp/kwin-screen.png");
    const QString rawOutput = output + QStringLiteral(".raw");
    QFile file(rawOutput);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCritical("cannot open output file");
        return 2;
    }

    QVariantMap options;
    options.insert(QStringLiteral("include-cursor"), false);
    options.insert(QStringLiteral("native-resolution"), true);
    QDBusUnixFileDescriptor descriptor(file.handle());
    QDBusMessage request = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin.ScreenShot2"),
        QStringLiteral("/org/kde/KWin/ScreenShot2"),
        QStringLiteral("org.kde.KWin.ScreenShot2"),
        QStringLiteral("CaptureWorkspace"));
    request << options << QVariant::fromValue(descriptor);
    const QDBusMessage reply = QDBusConnection::sessionBus().call(request, QDBus::Block, 10000);
    fprintf(stderr, "dbus reply type=%d args=%lld error=%s message=%s\n",
            int(reply.type()), static_cast<long long>(reply.arguments().size()),
            reply.errorName().toLocal8Bit().constData(), reply.errorMessage().toLocal8Bit().constData());
    if (reply.type() == QDBusMessage::ErrorMessage) {
        return 4;
    }
    if (reply.arguments().isEmpty()) {
        return 4;
    }

    const QVariantMap result = qdbus_cast<QVariantMap>(reply.arguments().constFirst());
    const qsizetype expectedBytes = qsizetype(result.value(QStringLiteral("stride")).toUInt())
        * qsizetype(result.value(QStringLiteral("height")).toUInt());
    for (int attempt = 0; attempt < 200 && file.size() < expectedBytes; ++attempt) {
        file.flush();
        QThread::msleep(10);
    }
    file.flush();
    file.close();

    QFile rawFile(rawOutput);
    if (!rawFile.open(QIODevice::ReadOnly)) {
        qCritical("cannot reopen raw screenshot");
        return 5;
    }
    const QByteArray raw = rawFile.readAll();
    const int width = result.value(QStringLiteral("width")).toUInt();
    const int height = result.value(QStringLiteral("height")).toUInt();
    const int stride = result.value(QStringLiteral("stride")).toUInt();
    const auto format = QImage::Format(result.value(QStringLiteral("format")).toUInt());
    if (raw.size() < qsizetype(stride) * height) {
        qCritical("short raw screenshot: got %lld, expected %lld",
                  static_cast<long long>(raw.size()), static_cast<long long>(qsizetype(stride) * height));
        return 6;
    }
    const QImage image(reinterpret_cast<const uchar *>(raw.constData()), width, height, stride, format);
    if (image.isNull() || !image.save(output, "PNG")) {
        qCritical("cannot convert raw screenshot to PNG");
        return 7;
    }
    rawFile.close();
    QFile::remove(rawOutput);

    QJsonObject json = QJsonObject::fromVariantMap(result);
    json.insert(QStringLiteral("output"), output);
    json.insert(QStringLiteral("bytes"), QFile(output).size());
    const QByteArray encoded = QJsonDocument(json).toJson(QJsonDocument::Compact);
    QFile metadata(output + QStringLiteral(".json"));
    if (metadata.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        metadata.write(encoded);
        metadata.write("\n");
    }
    puts(encoded.constData());
    return 0;
}
