import QtQuick

Rectangle {
    id: picker
    color: "#f4f4f4"
    property var folders: []
    property string current: ""
    property string selected: ""
    signal chosen(string id)
    signal cancelled
    function folder(id) { return folders.find(function(f){return f.id===id}) || {id:"",name:"My files",parent:""} }
    function path(id) {
        var parts=[],seen={}
        while(id && !seen[id]) {seen[id]=true;var f=folder(id);parts.unshift(f.name);id=f.parent}
        return "My files"+(parts.length?" / "+parts.join(" / "):"")
    }
    Column {
        anchors.fill: parent; anchors.margins: 28; spacing: 22
        Row { spacing:12
            Action {label:"Cancel";onTriggered:picker.cancelled()}
            Action {objectName:"chooseFolder";width:230;label:"Use this folder";selected:true;onTriggered:picker.chosen(picker.current)}
        }
        AppText {text:"Download folder";font.pixelSize:32;font.bold:true}
        AppText {width:parent.width;text:picker.path(picker.current);wrapMode:Text.Wrap;font.pixelSize:24}
        Action {objectName:"parentFolder";visible:picker.current!=="";label:"Up";icon:"up";onTriggered:picker.current=picker.folder(picker.current).parent}
        ListView {
            width:parent.width;height:picker.height-y-190;clip:true;spacing:12
            model:picker.folders.filter(function(f){return f.id!=="" && f.parent===picker.current})
            delegate:Rectangle {
                required property var modelData
                width:ListView.view.width;height:88;radius:12;color:"white";border.color:"black";border.width:2
                AppText {x:20;anchors.verticalCenter:parent.verticalCenter;width:parent.width-70;text:modelData.name;font.pixelSize:27;elide:Text.ElideRight}
                DirectionIcon {anchors.right:parent.right;anchors.rightMargin:22;anchors.verticalCenter:parent.verticalCenter;name:"next"}
                MouseArea {anchors.fill:parent;onClicked:picker.current=modelData.id}
            }
            AppText {anchors.centerIn:parent;visible:parent.count===0;text:"No subfolders";font.pixelSize:23;color:"black"}
        }
    }
}
