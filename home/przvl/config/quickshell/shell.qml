import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root

    property string cpu: "--"
    property string ram: "--"
    property string battery: ""
    property string brightness: ""
    readonly property string clockText: Qt.formatDateTime(clock.date, "ddd, MMM d - HH:mm")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Process {
        id: statusProcess
        command: ["@status-command@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.trim().split("\n")) {
                    const separator = line.indexOf("=");
                    if (separator < 0) continue;
                    const key = line.slice(0, separator);
                    const value = line.slice(separator + 1);
                    if (key === "cpu") root.cpu = value;
                    else if (key === "ram") root.ram = value;
                    else if (key === "battery") root.battery = value;
                    else if (key === "brightness") root.brightness = value;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: statusProcess.running = true
    }

    Process {
        id: brightnessProcess
    }

    Process {
        id: settingsProcess
        command: ["@settings-command@"]
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 36

            Rectangle {
                anchors.fill: parent
                color: "#1a1b26"
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    text: "BLIX"
                    color: "white"
                    font.family: "Terminus (TTF)"
                    font.bold: true
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 12
                }

                Repeater {
                    model: 9
                    Rectangle {
                        required property int index
                        width: 28
                        height: 27
                        radius: 3
                        color: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === index + 1
                            ? "#34394e" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: (index + 1).toString()
                            color: "white"
                            font.family: "Terminus (TTF)"
                            font.bold: true
                            font.pixelSize: 16
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch(Hyprland.usingLua
                                ? 'hl.dsp.focus({ workspace = "' + (index + 1) + '" })'
                                : "workspace " + (index + 1))
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    visible: @has-battery@ && root.battery !== ""
                    text: "Bat " + root.battery + "%"
                    color: "white"
                    font.family: "Terminus (TTF)"
                    font.bold: true
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsProcess.running = true
                    }
                }

                Text {
                    readonly property var audio: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                        ? Pipewire.defaultAudioSink.audio : null
                    text: audio ? (audio.muted ? "Vol mute" : "Vol " + Math.round(audio.volume * 100) + "%") : "Vol --"
                    color: "white"
                    font.family: "Terminus (TTF)"
                    font.bold: true
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (parent.audio) parent.audio.muted = !parent.audio.muted
                        onWheel: {
                            if (!parent.audio) return;
                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            parent.audio.volume = Math.max(0, Math.min(1, parent.audio.volume + step));
                        }
                    }
                }

                Text {
                    visible: @has-backlight@ && root.brightness !== ""
                    text: "Bri " + root.brightness + "%"
                    color: "white"
                    font.family: "Terminus (TTF)"
                    font.bold: true
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onWheel: {
                            brightnessProcess.command = ["@brightness-command@", "--class=backlight", "set",
                                wheel.angleDelta.y > 0 ? "5%+" : "5%-"];
                            brightnessProcess.running = true;
                        }
                    }
                }

                Text {
                    text: "Ram " + root.ram + "G"
                    color: "white"
                    font.family: "Terminus (TTF)"
                    font.bold: true
                    font.pixelSize: 16
                }

                Text {
                    text: "CPU " + root.cpu + "%"
                    color: "white"
                    font.family: "Terminus (TTF)"
                    font.bold: true
                    font.pixelSize: 16
                }

                Text {
                    text: root.clockText
                    color: "white"
                    font.family: "Terminus (TTF)"
                    font.bold: true
                    font.pixelSize: 16
                }
            }
        }
    }
}
