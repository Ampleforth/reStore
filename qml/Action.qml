// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 remarkable2-nextcloudCalendar contributors
import QtQuick

Rectangle {
    id: button
    property string label
    property string icon: ""
    property bool selected: false
    property bool dropdown: false
    property bool checkable: false
    property bool checked: false
    property real fontSize: 22
    readonly property bool pressed: tap.pressed
    signal triggered
    width: 110; height: 58
    radius: 13
    color: !enabled ? "#f7f7f7" : (selected ? "black" : "#e9e9e9")
    border.color: "black"; border.width: 2
    CheckMark {visible:button.checkable;x:14;anchors.verticalCenter:parent.verticalCenter;checked:button.checked}
    AppText { x:button.checkable?56:(button.icon?40:9); anchors.verticalCenter:parent.verticalCenter; width:parent.width-x-(button.dropdown?44:9); horizontalAlignment:button.checkable?Text.AlignLeft:Text.AlignHCenter; elide:Text.ElideRight; text:button.label;color:button.enabled&&button.selected?"white":"black";font.pixelSize:button.fontSize;font.weight:button.selected?Font.Bold:Font.DemiBold }
    DirectionIcon {visible:button.icon!=="";x:12;anchors.verticalCenter:parent.verticalCenter;width:20;height:20;name:button.icon;strokeColor:button.enabled&&button.selected?"white":"black"}
    DirectionIcon {visible:button.dropdown;anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter;width:20;height:18;name:"down";strokeColor:button.enabled&&button.selected?"white":"black"}
    MouseArea { id:tap; anchors.fill: parent; onClicked: button.triggered() }
}
