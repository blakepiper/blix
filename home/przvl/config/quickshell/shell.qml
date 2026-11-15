import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root

    property string battery: ""
    property string batteryEta: ""
    property string brightness: ""
    property string powerMode: ""

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
                    if (key === "battery") root.battery = value;
                    else if (key === "battery_eta") root.batteryEta = value;
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
        id: powerModeProcess
        command: ["@power-mode-command@", "power-mode"]
        running: @has-power-profiles@
        stdout: StdioCollector {
            onStreamFinished: root.powerMode = this.text.trim()
        }
    }

    Process {
        id: powerModeSetProcess
        onExited: powerModeProcess.exec(["@power-mode-command@", "power-mode"])
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            property string activeControl: ""
            function toggleControl(name) {
                if (activeControl === name && controlPopup.visible) {
                    controlPopup.visible = false;
                } else {
                    activeControl = name;
                    controlPopup.visible = true;
                }
            }
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 36
            color: "transparent"
            mask: Region {
                Region { item: workspaceRow }
                Region { item: controlsRow }
            }
            HyprlandFocusGrab {
                active: controlPopup.visible
                windows: [panel, controlPopup]
                onCleared: controlPopup.visible = false
            }

            Row {
                id: workspaceRow
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Repeater {
                    model: Hyprland.workspaces
                    Rectangle {
                        required property var modelData
                        visible: modelData.active || modelData.toplevels.values.length > 0
                        width: 28
                        height: 27
                        radius: 3
                        color: modelData.focused ? "#34394e" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: modelData.focused ? "#d7ffe8" : "#6ee7a0"
                            font.family: "Terminus (TTF)"
                            font.bold: true
                            font.pixelSize: 16
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch(Hyprland.usingLua
                                ? 'hl.dsp.focus({ workspace = "' + modelData.name + '" })'
                                : "workspace " + modelData.name)
                        }
                    }
                }
            }

            Row {
                id: controlsRow
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Text {
                    id: batteryControl
                    visible: @has-battery@ && root.battery !== ""
                    text: Number(root.battery) <= 10 ? "\uf244"
                        : Number(root.battery) <= 35 ? "\uf243"
                        : Number(root.battery) <= 60 ? "\uf242"
                        : Number(root.battery) <= 85 ? "\uf241" : "\uf240"
                    color: Number(root.battery) <= 20 ? "#f7768e" : "#a6da95"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 21
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerModeProcess.exec(["@power-mode-command@", "power-mode"]);
                            panel.toggleControl("battery");
                        }
                    }
                }

                Text {
                    id: volumeControl
                    readonly property var audio: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                        ? Pipewire.defaultAudioSink.audio : null
                    text: !audio || audio.muted || audio.volume === 0 ? "\uf6a9"
                        : audio.volume < 0.35 ? "\uf026"
                        : audio.volume < 0.7 ? "\uf027" : "\uf028"
                    color: "#8aadf4"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 21
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.toggleControl("volume")
                        onWheel: {
                            if (!parent.audio) return;
                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            parent.audio.volume = Math.max(0, Math.min(1, parent.audio.volume + step));
                        }
                    }
                }

                Item {
                    id: brightnessControl
                    visible: @has-backlight@ && root.brightness !== ""
                    width: 25
                    height: 25
                    Canvas {
                        id: sunIcon
                        anchors.fill: parent
                        property real level: Number(root.brightness)
                        onLevelChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = "#eed49f";
                            ctx.fillStyle = "#eed49f";
                            ctx.lineWidth = 2;
                            ctx.lineCap = "round";
                            ctx.globalAlpha = 0.5 + Math.min(100, level) / 200;
                            const center = width / 2;
                            ctx.beginPath();
                            ctx.arc(center, center, 3.5, 0, Math.PI * 2);
                            ctx.fill();
                            const rays = level < 30 ? 4 : 8;
                            const outer = level < 30 ? 9 : level < 70 ? 10.5 : 12;
                            for (let i = 0; i < rays; i++) {
                                const angle = i * 2 * Math.PI / rays;
                                ctx.beginPath();
                                ctx.moveTo(center + Math.cos(angle) * 7, center + Math.sin(angle) * 7);
                                ctx.lineTo(center + Math.cos(angle) * outer, center + Math.sin(angle) * outer);
                                ctx.stroke();
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.toggleControl("brightness")
                        onWheel: {
                            brightnessProcess.exec(["@brightness-command@", "--class=backlight", "set",
                                wheel.angleDelta.y > 0 ? "5%+" : "5%-"]);
                        }
                    }
                }
            }

            PopupWindow {
                id: controlPopup
                anchor {
                    window: panel
                    rect.x: panel.width - 14
                    rect.y: panel.height + 8
                    edges: Edges.Bottom | Edges.Right
                    gravity: Edges.Bottom | Edges.Left
                    adjustment: PopupAdjustment.All
                }
                grabFocus: false
                color: "transparent"
                implicitWidth: 330
                implicitHeight: cardColumn.implicitHeight + 32
                visible: false

                Rectangle {
                    anchors.fill: parent
                    color: "#1e2030"
                    border.color: "#454a62"
                    border.width: 1
                    radius: 14
                    Column {
                        id: cardColumn
                        anchors.centerIn: parent
                        width: parent.width - 32
                        spacing: 12

                        Item {
                            visible: panel.activeControl === "battery" && @has-battery@ && root.battery !== ""
                            width: parent.width
                            height: 120

                            Text {
                                text: "BATTERY"
                                color: "#a6da95"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 14
                            }
                            Text {
                                anchors.right: parent.right
                                text: root.battery + "%"
                                color: "#c0caf5"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 16
                            }
                            Rectangle {
                                y: 29
                                width: parent.width
                                height: 6
                                radius: 3
                                color: "#34394e"
                                Rectangle {
                                    width: Math.max(0, Math.min(1, Number(root.battery) / 100)) * parent.width
                                    height: parent.height
                                    radius: 3
                                    color: Number(root.battery) <= 20 ? "#f7768e" : "#a6da95"
                                }
                            }
                            Text {
                                y: 47
                                text: root.batteryEta
                                color: "#a9b1d6"
                                font.family: "Terminus (TTF)"
                                font.pixelSize: 14
                            }
                            Row {
                                id: modeRow
                                y: 76
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: [
                                        { label: "Saver", value: "power-saver" },
                                        { label: "Balanced", value: "balanced" },
                                        { label: "Performance", value: "performance" }
                                    ]
                                    Rectangle {
                                        required property var modelData
                                        width: (modeRow.width - 12) / 3
                                        height: 34
                                        radius: 7
                                        color: root.powerMode === modelData.value ? "#354d45" : "#2a2e42"
                                        border.color: root.powerMode === modelData.value ? "#a6da95" : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: root.powerMode === modelData.value ? "#d7ffe8" : "#a9b1d6"
                                            font.family: "Terminus (TTF)"
                                            font.bold: true
                                            font.pixelSize: 13
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: powerModeSetProcess.exec([
                                                "@power-mode-command@", "power-mode", modelData.value])
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            visible: panel.activeControl === "volume"
                            width: parent.width
                            height: 70
                            Text {
                                text: "VOLUME"
                                color: "#8aadf4"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 14
                            }
                            Text {
                                anchors.right: muteButton.left
                                anchors.rightMargin: 10
                                text: volumeControl.audio ? Math.round(volumeControl.audio.volume * 100) + "%" : "--"
                                color: "#c0caf5"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 16
                            }
                            Rectangle {
                                id: muteButton
                                anchors.right: parent.right
                                y: -3
                                width: 52
                                height: 25
                                radius: 6
                                color: volumeControl.audio && volumeControl.audio.muted ? "#5a3445" : "#2a2e42"
                                Text {
                                    anchors.centerIn: parent
                                    text: volumeControl.audio && volumeControl.audio.muted ? "MUTED" : "MUTE"
                                    color: volumeControl.audio && volumeControl.audio.muted ? "#f7768e" : "#a9b1d6"
                                    font.family: "Terminus (TTF)"
                                    font.bold: true
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (volumeControl.audio) volumeControl.audio.muted = !volumeControl.audio.muted
                                }
                            }
                            Slider {
                                id: volumeSlider
                                y: 30
                                width: parent.width
                                height: 30
                                from: 0
                                to: 100
                                enabled: volumeControl.audio !== null
                                value: volumeControl.audio ? volumeControl.audio.volume * 100 : 0
                                onMoved: if (volumeControl.audio) volumeControl.audio.volume = value / 100
                                background: Rectangle {
                                    x: volumeSlider.leftPadding
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - 3
                                    width: volumeSlider.availableWidth
                                    height: 6
                                    radius: 3
                                    color: "#34394e"
                                    Rectangle {
                                        width: volumeSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 3
                                        color: "#8aadf4"
                                    }
                                }
                                handle: Rectangle {
                                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: "#c0caf5"
                                    border.color: "#8aadf4"
                                }
                            }
                        }

                        Item {
                            visible: panel.activeControl === "brightness" && @has-backlight@ && root.brightness !== ""
                            width: parent.width
                            height: 70
                            Text {
                                text: "BRIGHTNESS"
                                color: "#eed49f"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 14
                            }
                            Text {
                                anchors.right: parent.right
                                text: root.brightness + "%"
                                color: "#c0caf5"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 16
                            }
                            Slider {
                                id: brightnessSlider
                                y: 30
                                width: parent.width
                                height: 30
                                from: 1
                                to: 100
                                value: Number(root.brightness)
                                onMoved: {
                                    root.brightness = Math.round(value).toString();
                                    brightnessProcess.exec(["@brightness-command@", "--class=backlight",
                                        "--min-value=1", "set", root.brightness + "%"]);
                                }
                                background: Rectangle {
                                    x: brightnessSlider.leftPadding
                                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - 3
                                    width: brightnessSlider.availableWidth
                                    height: 6
                                    radius: 3
                                    color: "#34394e"
                                    Rectangle {
                                        width: brightnessSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 3
                                        color: "#eed49f"
                                    }
                                }
                                handle: Rectangle {
                                    x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: "#c0caf5"
                                    border.color: "#eed49f"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
