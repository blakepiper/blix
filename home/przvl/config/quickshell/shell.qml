import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

Scope {
    id: root
    readonly property int popupTop: @popup-top@

    property string battery: ""
    property string batteryStatus: ""
    property string batteryEta: ""
    property string brightness: ""
    property string powerMode: ""
    property date currentDate: new Date()

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Process {
        id: statusProcess
        command: ["@status-command@"]
        running: @has-battery@ || @has-backlight@
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.trim().split("\n")) {
                    const separator = line.indexOf("=");
                    if (separator < 0) continue;
                    const key = line.slice(0, separator);
                    const value = line.slice(separator + 1);
                    if (key === "battery") root.battery = value;
                    else if (key === "battery_status") root.batteryStatus = value;
                    else if (key === "battery_eta") root.batteryEta = value;
                    else if (key === "brightness") root.brightness = value;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: @has-battery@ || @has-backlight@
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
                calendarPopup.visible = false;
                if (activeControl === name && controlPopup.visible) {
                    controlPopup.visible = false;
                } else {
                    activeControl = name;
                    controlPopup.visible = true;
                }
            }
            function toggleCalendar() {
                controlPopup.visible = false;
                calendarPopup.visible = !calendarPopup.visible;
            }
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: @bar-height@
            color: "transparent"
            mask: Region {
                Region { item: workspaceRow }
                Region { item: centerClock }
                Region { item: controlsRow }
            }
            HyprlandFocusGrab {
                active: controlPopup.visible || calendarPopup.visible
                windows: [panel, controlPopup, calendarPopup]
                onCleared: {
                    controlPopup.visible = false;
                    calendarPopup.visible = false;
                }
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
                            onPressed: {
                                controlPopup.visible = false;
                                calendarPopup.visible = false;
                            }
                            onClicked: Hyprland.dispatch(Hyprland.usingLua
                                ? 'hl.dsp.focus({ workspace = "' + modelData.name + '" })'
                                : "workspace " + modelData.name)
                        }
                    }
                }
            }

            Text {
                id: centerClock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                property string currentTime: Qt.formatDateTime(new Date(), "HH:mm")
                text: currentTime
                color: "#c0caf5"
                font.family: "Terminus (TTF)"
                font.bold: true
                font.pixelSize: 16

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.toggleCalendar()
                }
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    const now = new Date();
                    centerClock.currentTime = Qt.formatDateTime(now, "HH:mm");
                    root.currentDate = now;
                }
            }

            Row {
                id: controlsRow
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Item {
                    id: batteryControl
                    visible: @has-battery@ && root.battery !== ""
                    width: 25
                    height: 25
                    Rectangle {
                        anchors.fill: parent
                        color: "#00000000"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Number(root.battery) <= 10 ? "\uf244"
                            : Number(root.battery) <= 35 ? "\uf243"
                            : Number(root.battery) <= 60 ? "\uf242"
                            : Number(root.battery) <= 85 ? "\uf241" : "\uf240"
                        color: Number(root.battery) <= 20 ? "#f7768e" : "#a6da95"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 21
                    }
                    Text {
                        visible: root.batteryStatus === "Charging"
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: "\uf0e7"
                        color: "#eed49f"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerModeProcess.exec(["@power-mode-command@", "power-mode"]);
                            panel.toggleControl("battery");
                        }
                    }
                }

                Item {
                    id: volumeControl
                    width: 25
                    height: 25
                    readonly property var audio: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                        ? Pipewire.defaultAudioSink.audio : null
                    Rectangle {
                        anchors.fill: parent
                        color: "#00000000"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: !volumeControl.audio || volumeControl.audio.muted || volumeControl.audio.volume === 0 ? "\uf6a9"
                            : volumeControl.audio.volume < 0.35 ? "\uf026"
                            : volumeControl.audio.volume < 0.7 ? "\uf027" : "\uf028"
                        color: "#8aadf4"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 21
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.toggleControl("volume")
                        onWheel: {
                            if (!volumeControl.audio) return;
                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            volumeControl.audio.volume = Math.max(0, Math.min(1, volumeControl.audio.volume + step));
                        }
                    }
                }

                Item {
                    id: brightnessControl
                    visible: @has-backlight@ && root.brightness !== ""
                    width: 25
                    height: 25
                    Rectangle {
                        anchors.fill: parent
                        color: "#00000000"
                    }
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

            PanelWindow {
                id: controlPopup
                screen: panel.screen
                WlrLayershell.namespace: "blix-control-popup"
                anchors {
                    top: true
                    right: true
                }
                margins {
                    top: root.popupTop
                    right: 10
                }
                exclusionMode: ExclusionMode.Ignore
                focusable: false
                color: "transparent"
                implicitWidth: 165
                implicitHeight: cardColumn.implicitHeight + 20
                visible: false

                Rectangle {
                    anchors.fill: parent
                    color: "#2e101827" // Same dark background alpha as the glass terminal.
                    border.color: "#66c0caf5"
                    border.width: 1
                    radius: 10
                    Column {
                        id: cardColumn
                        anchors.centerIn: parent
                        width: parent.width - 20
                        spacing: 8

                        Item {
                            visible: panel.activeControl === "battery" && @has-battery@ && root.battery !== ""
                            width: parent.width
                            height: 138

                            Text {
                                text: "BATTERY"
                                color: "#a6da95"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 12
                            }
                            Text {
                                anchors.right: parent.right
                                text: root.battery + "%"
                                color: "#c0caf5"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 14
                            }
                            Rectangle {
                                y: 22
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
                                y: 34
                                width: parent.width
                                text: root.batteryEta
                                color: "#a9b1d6"
                                font.family: "Terminus (TTF)"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Column {
                                id: modeColumn
                                y: 54
                                width: parent.width
                                spacing: 4
                                Repeater {
                                    model: [
                                        { label: "Saver", value: "power-saver" },
                                        { label: "Balanced", value: "balanced" },
                                        { label: "Performance", value: "performance" }
                                    ]
                                    Rectangle {
                                        required property var modelData
                                        width: modeColumn.width
                                        height: 24
                                        radius: 6
                                        color: root.powerMode === modelData.value ? "#55354d45" : "#552a2e42"
                                        border.color: root.powerMode === modelData.value ? "#77a6da95" : "#33454a62"
                                        border.width: 1
                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.label
                                            color: root.powerMode === modelData.value ? "#d7ffe8" : "#a9b1d6"
                                            font.family: "Terminus (TTF)"
                                            font.bold: true
                                            font.pixelSize: 12
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
                            height: 62
                            Text {
                                text: "VOLUME"
                                color: "#8aadf4"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 12
                            }
                            Text {
                                anchors.right: muteButton.left
                                anchors.rightMargin: 7
                                text: volumeControl.audio ? Math.round(volumeControl.audio.volume * 100) + "%" : "--"
                                color: "#c0caf5"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 14
                            }
                            Rectangle {
                                id: muteButton
                                anchors.right: parent.right
                                y: -3
                                width: 46
                                height: 23
                                radius: 6
                                color: volumeControl.audio && volumeControl.audio.muted ? "#885a3445" : "#772a2e42"
                                Text {
                                    anchors.centerIn: parent
                                    text: volumeControl.audio && volumeControl.audio.muted ? "MUTED" : "MUTE"
                                    color: volumeControl.audio && volumeControl.audio.muted ? "#f7768e" : "#a9b1d6"
                                    font.family: "Terminus (TTF)"
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (volumeControl.audio) volumeControl.audio.muted = !volumeControl.audio.muted
                                }
                            }
                            Slider {
                                id: volumeSlider
                                y: 27
                                width: parent.width
                                height: 28
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
                            height: 62
                            Text {
                                text: "BRIGHTNESS"
                                color: "#eed49f"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 12
                            }
                            Text {
                                anchors.right: parent.right
                                text: root.brightness + "%"
                                color: "#c0caf5"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 14
                            }
                            Slider {
                                id: brightnessSlider
                                y: 27
                                width: parent.width
                                height: 28
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

            PanelWindow {
                id: calendarPopup
                screen: panel.screen
                WlrLayershell.namespace: "blix-calendar-popup"
                anchors { top: true }
                margins { top: root.popupTop }
                exclusionMode: ExclusionMode.Ignore
                focusable: false
                color: "transparent"
                implicitWidth: 264
                implicitHeight: 270
                visible: false

                property var displayedMonth: {
                    const now = new Date();
                    return new Date(now.getFullYear(), now.getMonth(), 1);
                }
                readonly property int daysInMonth: new Date(
                    displayedMonth.getFullYear(), displayedMonth.getMonth() + 1, 0).getDate()
                readonly property int firstWeekday: displayedMonth.getDay()

                function changeMonth(offset) {
                    displayedMonth = new Date(
                        displayedMonth.getFullYear(), displayedMonth.getMonth() + offset, 1);
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#2e101827"
                    border.color: "#66c0caf5"
                    border.width: 1
                    radius: 10

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Row {
                            width: parent.width
                            height: 26
                            spacing: 8

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 6
                                color: "#552a2e42"
                                Text {
                                    anchors.centerIn: parent
                                    text: "‹"
                                    color: "#c0caf5"
                                    font.family: "Terminus (TTF)"
                                    font.pixelSize: 20
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarPopup.changeMonth(-1)
                                }
                            }

                            Text {
                                width: parent.width - 68
                                height: 26
                                text: Qt.formatDateTime(calendarPopup.displayedMonth, "MMMM yyyy")
                                color: "#c0caf5"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 6
                                color: "#552a2e42"
                                Text {
                                    anchors.centerIn: parent
                                    text: "›"
                                    color: "#c0caf5"
                                    font.family: "Terminus (TTF)"
                                    font.pixelSize: 20
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarPopup.changeMonth(1)
                                }
                            }
                        }

                        Row {
                            id: weekdayRow
                            width: parent.width
                            height: 18
                            spacing: 2

                            Repeater {
                                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                                Item {
                                    required property string modelData
                                    width: (weekdayRow.width - 12) / 7
                                    height: weekdayRow.height
                                    Text {
                                        anchors.fill: parent
                                        text: modelData
                                        color: "#8291b3"
                                        font.family: "Terminus (TTF)"
                                        font.bold: true
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        Grid {
                            id: calendarGrid
                            width: parent.width
                            height: 6 * 28 + 5 * 2
                            columns: 7
                            rowSpacing: 2
                            columnSpacing: 2

                            Repeater {
                                model: 42
                                Rectangle {
                                    required property int index
                                    readonly property int dayNumber: index - calendarPopup.firstWeekday + 1
                                    readonly property bool inDisplayedMonth:
                                        dayNumber >= 1 && dayNumber <= calendarPopup.daysInMonth
                                    readonly property bool isToday: inDisplayedMonth
                                        && dayNumber === root.currentDate.getDate()
                                        && calendarPopup.displayedMonth.getMonth() === root.currentDate.getMonth()
                                        && calendarPopup.displayedMonth.getFullYear() === root.currentDate.getFullYear()
                                    width: (calendarGrid.width - 12) / 7
                                    height: 28
                                    radius: 6
                                    color: isToday ? "#55354d45" : "transparent"
                                    border.color: isToday ? "#77a6da95" : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.fill: parent
                                        text: parent.inDisplayedMonth ? parent.dayNumber : ""
                                        color: parent.isToday ? "#d7ffe8" : "#c0caf5"
                                        font.family: "Terminus (TTF)"
                                        font.pixelSize: 13
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
