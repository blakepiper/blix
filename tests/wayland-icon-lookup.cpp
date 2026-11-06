#include <QGuiApplication>
#include <QDebug>
#include <QIcon>
#include <QImage>
#include <QPixmap>

int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);
  // Qt applications retain the shared Adwaita theme. Firefox's exact-size
  // fallback must still resolve to the session's retro asset.
  QIcon::setThemeName("Adwaita");
  const QImage expected = QIcon(QString::fromLocal8Bit(argv[1])).pixmap(48, 48).toImage();
  const QImage vector = QIcon(QString::fromLocal8Bit(argv[2])).pixmap(48, 48).toImage();
  if (expected.isNull()) return 1;
  for (const char *name : {"firefox", "firefox-esr", "org.mozilla.firefox"}) {
    const QImage actual = QIcon::fromTheme(name).pixmap(48, 48).toImage();
    if (actual != expected && actual != vector) {
      qWarning() << name << actual.size() << expected.size() << vector.size()
                 << QIcon::themeSearchPaths();
      return 2;
    }
  }
  return 0;
}
