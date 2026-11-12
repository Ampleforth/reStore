import QtQuick

Item {
    id: picker
    anchors.fill: parent
    visible: false
    z: 100
    property string title: ""
    property var options: []
    property var selectedValue: ""
    property var callback: null
    property real originX: 24
    property real originY: 100
    property real pickerWidth: 600
    function show(anchor, heading, choices, value, done) {
        var point=anchor.mapToItem(picker,0,anchor.height)
        title=heading;options=choices;selectedValue=value;callback=done
        pickerWidth=Math.min(Math.max(anchor.width,420),width-48)
        originX=Math.max(24,Math.min(point.x,width-pickerWidth-24))
        originY=Math.max(24,Math.min(point.y+8,height-panel.height-24))
        visible=true
        var index=choices.findIndex(function(c){return c.value===value})
        Qt.callLater(function(){list.positionViewAtIndex(Math.max(0,index),ListView.Center)})
    }
    function choose(index) {
        if(index<0||index>=options.length)return
        var done=callback, value=options[index].value
        close()
        if(done)done(value)
    }
    function close() {visible=false;callback=null;options=[]}
    MouseArea {anchors.fill:parent;onClicked:picker.close()}
    Rectangle {
        id:panel
        x:picker.originX;y:picker.originY;width:picker.pickerWidth
        height:Math.min(600,picker.height-48,Math.max(136,picker.options.length*64+72))
        radius:16;color:"white";border.color:"black";border.width:2
        MouseArea {anchors.fill:parent}
        AppText {x:20;y:18;width:parent.width-90;text:picker.title;font.pixelSize:24;font.bold:true;color:"black";elide:Text.ElideRight}
        ToolbarButton {anchors.right:parent.right;icon:"close";onTriggered:picker.close()}
        ListView {
            id:list;objectName:"choiceList";x:12;y:68;width:parent.width-24;height:parent.height-80;clip:true;model:picker.options
            delegate:Rectangle {
                required property int index
                required property var modelData
                width:ListView.view.width;height:64;radius:10
                color:modelData.value===picker.selectedValue?"black":"white"
                border.color:"black";border.width:1
                AppText {x:16;anchors.verticalCenter:parent.verticalCenter;width:parent.width-32;text:modelData.label;font.pixelSize:26;font.bold:modelData.value===picker.selectedValue;color:modelData.value===picker.selectedValue?"white":"black";elide:Text.ElideRight}
                MouseArea {anchors.fill:parent;onClicked:picker.choose(index)}
            }
        }
    }
}
