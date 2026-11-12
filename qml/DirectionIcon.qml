import QtQuick

Canvas {
    property string name: "down"
    property color strokeColor: "black"
    width:24;height:24
    onNameChanged:requestPaint()
    onStrokeColorChanged:requestPaint()
    onPaint:{
        var c=getContext("2d");c.reset();c.scale(width/24,height/24)
        c.strokeStyle=strokeColor;c.lineWidth=2.5;c.lineCap="round";c.lineJoin="round";c.beginPath()
        if(name==="previous"){c.moveTo(16,4);c.lineTo(8,12);c.lineTo(16,20)}
        else if(name==="next"){c.moveTo(8,4);c.lineTo(16,12);c.lineTo(8,20)}
        else if(name==="up"){c.moveTo(4,16);c.lineTo(12,8);c.lineTo(20,16)}
        else {c.moveTo(4,8);c.lineTo(12,16);c.lineTo(20,8)}
        c.stroke()
    }
}
