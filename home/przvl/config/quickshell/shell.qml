import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
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
    property int nightlightLevel: 0
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

    Process {
        id: nightlightRead
        command: ["@power-mode-command@", "nightlight-level"]
        stdout: StdioCollector {
            onStreamFinished: {
                const level = Number(this.text.trim());
                if (this.text.trim() !== "" && isFinite(level)
                    && !nightlightDebounce.running && !nightlightSet.running)
                    root.nightlightLevel = Math.max(0, Math.min(100, level));
            }
        }
    }
    Process {
        id: nightlightSet
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) nightlightRead.running = true;
        }
    }
    Timer {
        id: nightlightDebounce
        interval: 250
        onTriggered: {
            if (nightlightSet.running) { restart(); return; }
            nightlightSet.exec(["@power-mode-command@", "nightlight-level",
                "--intensity", root.nightlightLevel.toString()]);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            property string activeControl: ""
            property var systemStats: ({ rows: [] })
            Process {
                command: ["@system-info-command@"]
                running: controlPopup.visible && panel.activeControl === "system"
                stdout: SplitParser {
                    onRead: data => {
                        try { panel.systemStats = JSON.parse(data); } catch (error) { console.warn("Invalid system info:", error); }
                    }
                }
            }
            function toggleControl(name) {
                calendarPopup.visible = false;
                if (activeControl === name && controlPopup.visible) {
                    controlPopup.visible = false;
                } else {
                    activeControl = name;
                    if (name === "brightness") nightlightRead.running = true;
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
            mask: Region {}
            HyprlandFocusGrab {
                active: controlPopup.visible || calendarPopup.visible
                windows: [panel, workspaceGlass, clockGlass, controlsGlass]
                onCleared: {
                    controlPopup.visible = false;
                    calendarPopup.visible = false;
                }
            }

            // Keep membership keyed by workspace ID so ListView can animate removals.
            ListModel { id: workspaceModel; dynamicRoles: true }
            function syncWorkspaces() {
                const workspaces = Hyprland.workspaces.values.filter(w => w.id > 0)
                    .sort((a, b) => a.id - b.id);
                const ids = workspaces.map(w => w.id);
                for (let i = workspaceModel.count - 1; i >= 0; --i)
                    if (ids.indexOf(workspaceModel.get(i).workspaceId) < 0)
                        workspaceModel.remove(i);
                for (let i = 0; i < workspaces.length; ++i) {
                    const w = workspaces[i];
                    if (i >= workspaceModel.count || workspaceModel.get(i).workspaceId !== w.id)
                        workspaceModel.insert(i, { workspaceId: w.id, workspace: w });
                }
            }
            Component.onCompleted: syncWorkspaces()
            Connections {
                target: Hyprland.workspaces
                function onValuesChanged() { panel.syncWorkspaces(); }
            }

            PanelWindow {
                id: workspaceGlass
                screen: panel.screen
                WlrLayershell.namespace: "blix-workspace-glass"
                anchors { top: true; left: true }
                margins.left: 10
                exclusionMode: ExclusionMode.Ignore
                focusable: false
                color: "transparent"
                implicitWidth: Math.ceil(capsule.width)
                implicitHeight: @bar-height@
                mask: Region { item: capsule }

                Rectangle {
                    id: capsule
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44 + workspaceList.width + 8
                    height: 30
                    radius: 15
                    color: "#18101827"
                    border.color: "#40c0caf5"
                    border.width: 1

                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        source: "file://@distro-logo@"
                        fillMode: Image.PreserveAspectFit
                    }
                    Rectangle {
                        x: 39
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 14
                        color: "#33c0caf5"
                    }
                    ListView {
                        id: workspaceList
                        x: 44
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(contentWidth, Math.max(32, panel.width / 2 - 60))
                        height: 26
                        orientation: ListView.Horizontal
                        spacing: 3
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: workspaceModel
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        add: Transition {
                            NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 180 }
                            NumberAnimation { properties: "scale"; from: 0.7; to: 1; duration: 220; easing.type: Easing.OutCubic }
                        }
                        remove: Transition {
                            NumberAnimation { properties: "opacity"; to: 0; duration: 140 }
                            NumberAnimation { properties: "scale"; to: 0.7; duration: 140 }
                        }
                        displaced: Transition {
                            NumberAnimation { properties: "x"; duration: 220; easing.type: Easing.OutCubic }
                        }
                        delegate: Rectangle {
                            id: workspaceButton
                            required property var workspace
                            required property int index
                            function revealFocused() {
                                if (workspace.focused)
                                    workspaceList.positionViewAtIndex(index, ListView.Contain);
                            }
                            Component.onCompleted: Qt.callLater(revealFocused)
                            Connections {
                                target: workspaceButton.workspace
                                function onFocusedChanged() { workspaceButton.revealFocused(); }
                            }
                            width: Math.max(28, workspaceLabel.implicitWidth + 16)
                            height: 26
                            color: "transparent"
                            Text {
                                id: workspaceLabel
                                anchors.centerIn: parent
                                text: workspace.name
                                color: workspace.focused ? "#ffffff" : workspaceMouse.containsMouse ? "#c0caf5" : "#77819d"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 16
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                            MouseArea {
                                id: workspaceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    controlPopup.visible = false;
                                    calendarPopup.visible = false;
                                    Hyprland.dispatch(Hyprland.usingLua
                                        ? 'hl.dsp.focus({ workspace = "' + workspace.name + '" })'
                                        : "workspace " + workspace.name);
                                }
                            }
                        }
                    }
                }
            }

            PanelWindow {
                id: clockGlass
                screen: panel.screen
                WlrLayershell.namespace: "blix-clock-glass"
                anchors.top: true
                exclusionMode: ExclusionMode.Ignore
                focusable: false
                color: "transparent"
                property real expansion: calendarPopup.visible ? 1 : 0
                Behavior on expansion {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
                // Keep the Wayland buffer stable; animate only the card inside it.
                implicitWidth: 264
                implicitHeight: @bar-height@ + 270
                mask: Region { item: clockCard }
                Rectangle {
                    id: clockCard
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 3
                    width: centerClock.implicitWidth + 28
                        + (264 - centerClock.implicitWidth - 28) * clockGlass.expansion
                    height: 30 + 270 * clockGlass.expansion
                    clip: true
                    radius: 15
                    color: "#18101827"
                    border.color: "#40c0caf5"
                    border.width: 1
                    Text {
                        id: centerClock
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (30 - height) / 2
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

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 42 - 10 * (1 - clockGlass.expansion)
                        width: 240
                        opacity: Math.max(0, (clockGlass.expansion - 0.25) / 0.75)
                        visible: clockGlass.expansion > 0
                        enabled: calendarPopup.visible
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

            PanelWindow {
                id: controlsGlass
                screen: panel.screen
                WlrLayershell.namespace: "blix-controls-glass"
                anchors { top: true; right: true }
                margins.right: 10
                exclusionMode: ExclusionMode.Ignore
                focusable: false
                color: "transparent"
                property real expansion: controlPopup.visible ? 1 : 0
                property real expandedWidth: panel.activeControl === "system" ? 264 : 190
                Behavior on expandedWidth {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }
                property real menuHeight: cardColumn.implicitHeight + 24
                Behavior on expansion {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
                Behavior on menuHeight {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }
                // The input mask follows the card, including when the menu is closed.
                implicitWidth: Math.max(264, controlsRow.implicitWidth + 24)
                implicitHeight: Math.min(340, panel.screen.height)
                mask: Region { item: controlsCard }
                Item {
                    id: controlsCard
                    anchors.right: parent.right
                    y: 3
                    width: controlsRow.implicitWidth + 24
                        + Math.max(0, controlsGlass.expandedWidth - controlsRow.implicitWidth - 24) * controlsGlass.expansion
                    height: 30 + controlsGlass.menuHeight * controlsGlass.expansion
                    clip: true
                    readonly property var selectedButton: panel.activeControl === "system" ? systemControl
                        : panel.activeControl === "battery" ? batteryControl
                        : panel.activeControl === "brightness" ? brightnessControl : volumeControl
                    readonly property real tabCenter: controlsRow.x + tabOffset
                    property real tabOffset: selectedButton.x + selectedButton.width / 2
                    Behavior on tabOffset {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }
                    // One contour: the active tab's shoulders join the menu without a seam.
                    readonly property string outline: {
                        const p = controlsGlass.expansion;
                        const w = width, h = height;
                        const left = Math.max(0, tabCenter - 22) * p;
                        const right = w + (Math.min(w, tabCenter + 22) - w) * p;
                        const r = 12;
                        const bottomRadius = Math.min(12, (h - 30) / 2);
                        const br = Math.min(12, (h - 30) / 2, (w - right) / 2);
                        const bl = Math.min(12, (h - 30) / 2, left / 2);
                        const sr = Math.min(8, (w - right) / 2) * p;
                        const sl = Math.min(8, left / 2) * p;
                        if (p < 0.001)
                            return `M 15 0 H ${w-15} Q ${w} 0 ${w} 15 Q ${w} 30 ${w-15} 30 H 15 Q 0 30 0 15 Q 0 0 15 0 Z`;
                        return `M ${left+r} 0 H ${right-r} Q ${right} 0 ${right} ${r}`
                            + ` V ${30-sr} Q ${right} 30 ${right+sr} 30`
                            + ` H ${w-br} Q ${w} 30 ${w} ${30+br}`
                            + ` V ${h-bottomRadius} Q ${w} ${h} ${w-bottomRadius} ${h}`
                            + ` H ${bottomRadius} Q 0 ${h} 0 ${h-bottomRadius}`
                            + ` V ${30+bl} Q 0 30 ${bl} 30`
                            + ` H ${left-sl} Q ${left} 30 ${left} ${30-sl}`
                            + ` V ${r} Q ${left} 0 ${left+r} 0 Z`;
                    }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "#18101827"
                            strokeColor: "#40c0caf5"
                            strokeWidth: 1
                            PathSvg { path: controlsCard.outline }
                        }
                    }
                    Row {
                        id: controlsRow
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        y: 2.5
                        spacing: 14

                        Item {
                            id: systemControl
                            width: 25
                            height: 25
                            Text {
                                anchors.centerIn: parent
                                text: "\uf2db"
                                color: "#f7768e"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.toggleControl("system")
                            }
                        }

                        Item {
                            id: batteryControl
                            visible: @has-battery@ && root.battery !== ""
                            width: 25
                            height: 25
                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: "#00000000"
                                border.width: 0
                                border.color: panel.activeControl === "battery" ? "transparent" : "#20c0caf5"
                                opacity: panel.activeControl === "battery" ? 0 : controlsGlass.expansion
                                Behavior on opacity { NumberAnimation { duration: 160 } }
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
                                radius: 10
                                color: "#00000000"
                                border.width: 0
                                border.color: panel.activeControl === "volume" ? "transparent" : "#20c0caf5"
                                opacity: panel.activeControl === "volume" ? 0 : controlsGlass.expansion
                                Behavior on opacity { NumberAnimation { duration: 160 } }
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
                                radius: 10
                                color: "#00000000"
                                border.width: 0
                                border.color: panel.activeControl === "brightness" ? "transparent" : "#20c0caf5"
                                opacity: panel.activeControl === "brightness" ? 0 : controlsGlass.expansion
                                Behavior on opacity { NumberAnimation { duration: 160 } }
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

                    Column {
                        id: cardColumn
                        x: parent.width - width - 12
                        y: 42 - 10 * (1 - controlsGlass.expansion)
                        width: panel.activeControl === "system" ? 240 : 166
                        opacity: Math.max(0, (controlsGlass.expansion - 0.25) / 0.75)
                        visible: controlsGlass.expansion > 0
                        enabled: controlPopup.visible
                        spacing: 8

                        Item {
                            visible: panel.activeControl === "system"
                            width: parent.width
                            height: Math.min(280, controlsGlass.height - 60)
                            Text {
                                text: "SYSTEM"
                                color: "#f7768e"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 12
                            }
                            Flickable {
                                anchors { top: parent.top; topMargin: 24; bottom: parent.bottom; left: parent.left; right: parent.right }
                                contentHeight: statsColumn.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { }
                                Column {
                                    id: statsColumn
                                    width: parent.width - 8
                                    spacing: 6
                                    Repeater {
                                        model: panel.systemStats.rows
                                        Row {
                                            required property var modelData
                                            width: statsColumn.width
                                            height: 18
                                            Text {
                                                width: parent.width * 0.46
                                                text: modelData.label
                                                elide: Text.ElideRight
                                                color: "#a9b1d6"
                                                font.family: "Terminus (TTF)"
                                                font.bold: true
                                                style: Text.Outline
                                                styleColor: "#47a9b1d6"
                                                font.pixelSize: 12
                                            }
                                            Text {
                                                width: parent.width * 0.54
                                                text: modelData.value
                                                horizontalAlignment: Text.AlignRight
                                                color: "#c0caf5"
                                                font.family: "Terminus (TTF)"
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                    Text {
                                        visible: panel.systemStats.rows.length === 0
                                        text: "Reading sensors…"
                                        color: "#a9b1d6"
                                        font.family: "Terminus (TTF)"
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }

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
                            height: 128
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
                            Text {
                                y: 66
                                text: "NIGHT LIGHT"
                                color: "#e0af68"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 12
                            }
                            Text {
                                y: 66
                                anchors.right: parent.right
                                text: root.nightlightLevel === 0 ? "OFF" : root.nightlightLevel + "%"
                                color: "#c0caf5"
                                font.family: "Terminus (TTF)"
                                font.bold: true
                                font.pixelSize: 14
                            }
                            Slider {
                                id: nightlightSlider
                                y: 93
                                width: parent.width
                                height: 28
                                from: 0
                                to: 100
                                value: root.nightlightLevel
                                onMoved: {
                                    root.nightlightLevel = Math.round(value);
                                    nightlightDebounce.restart();
                                }
                                background: Rectangle {
                                    x: nightlightSlider.leftPadding
                                    y: nightlightSlider.topPadding + nightlightSlider.availableHeight / 2 - 3
                                    width: nightlightSlider.availableWidth
                                    height: 6
                                    radius: 3
                                    color: "#34394e"
                                    Rectangle {
                                        width: nightlightSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 3
                                        color: "#e0af68"
                                    }
                                }
                                handle: Rectangle {
                                    x: nightlightSlider.leftPadding + nightlightSlider.visualPosition * (nightlightSlider.availableWidth - width)
                                    y: nightlightSlider.topPadding + nightlightSlider.availableHeight / 2 - height / 2
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: "#c0caf5"
                                    border.color: "#e0af68"
                                }
                            }
                        }
                    }
                }
            }

            Scope {
                id: controlPopup
                property bool visible: false
            }

            Scope {
                id: calendarPopup
                property bool visible: false
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

            }
        }
    }
}
