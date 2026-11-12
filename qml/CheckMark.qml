// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
Rectangle {
    id:mark
    property bool checked:false
    width:30;height:30;radius:5;color:checked?"black":"white";border.color:"black";border.width:2
    Canvas {
        id:checkCanvas
        anchors.fill:parent
        onPaint:{var c=getContext("2d");c.reset();if(!mark.checked)return;c.strokeStyle="white";c.lineWidth=3;c.lineCap="round";c.beginPath();c.moveTo(width*0.22,height*0.52);c.lineTo(width*0.43,height*0.73);c.lineTo(width*0.79,height*0.28);c.stroke()}
        Connections {target:mark;function onCheckedChanged(){checkCanvas.requestPaint()}}
    }
}
