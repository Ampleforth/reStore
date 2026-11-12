// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
Rectangle {
    id:keyboard
    property string value:""
    property string label:""
    property bool secret:false
    property bool shift:false
    property bool symbols:false
    property bool extraSymbols:false
    readonly property real letterWidth:(width-24-9*4)/10
    signal edited(string value)
    signal done
    width:parent.width;height:rows.height+36;color:"#eeeeee";border.color:"black"
    function type(value){var position=input.selectionStart;if(input.selectionEnd>position){input.remove(position,input.selectionEnd);input.insert(position,value)}else input.insert(input.cursorPosition,value);edited(input.text)}
    function erase(){if(input.selectionEnd>input.selectionStart)input.remove(input.selectionStart,input.selectionEnd);else if(input.cursorPosition>0)input.remove(input.cursorPosition-1,input.cursorPosition);edited(input.text)}
    onVisibleChanged:if(visible&&Qt.inputMethod)Qt.inputMethod.hide()
    MouseArea {anchors.fill:parent}
    Column {
        id:rows;x:12;y:18;width:parent.width-24;spacing:9
        Item {width:parent.width;height:69
            AppText {anchors.verticalCenter:parent.verticalCenter;width:parent.width-340;text:keyboard.label;font.weight:Font.DemiBold;font.pixelSize:19;color:"black";elide:Text.ElideRight}
            Row {anchors.right:parent.right;spacing:8
                Action {objectName:"hideKeyboardButton";width:110;height:66;label:"Hide";onTriggered:keyboard.done()}
            }
        }
        Rectangle {width:parent.width;height:93;radius:8;color:"white";border.color:"black";border.width:2
            TextInput {id:input;objectName:"keyboardInput";x:12;y:15;width:parent.width-24;height:63;color:"black";font.weight:Font.DemiBold;font.family:"DejaVu Sans";font.pixelSize:28;clip:true;selectByMouse:true;activeFocusOnPress:false;text:keyboard.value;echoMode:keyboard.secret?TextInput.Password:TextInput.Normal;onTextEdited:keyboard.edited(text);onActiveFocusChanged:if(activeFocus&&Qt.inputMethod)Qt.inputMethod.hide()}
        }
        Repeater {
            model:keyboard.symbols?(keyboard.extraSymbols?["[]{}#%^*+=","_\\|~<>€£¥",".,?!'\":"]:["1234567890","@#$%&-+()","*\"':;!?"]):["qwertyuiop","asdfghjkl","zxcvbnm"]
            delegate:Item {
                required property string modelData
                required property int index
                width:rows.width;height:108
                Row {
                    anchors.horizontalCenter:parent.horizontalCenter;spacing:4
                    Repeater {model:parent.parent.modelData.length;delegate:Action {
                        required property int index
                        property string key:parent.parent.modelData.charAt(index)
                        objectName:"key_"+label;width:keyboard.letterWidth;height:108;fontSize:32
                        label:!keyboard.symbols&&keyboard.shift?key.toUpperCase():key
                        onTriggered:keyboard.type(label)
                    }}
                }
                Action {objectName:"shiftKey";visible:index===2;anchors.left:parent.left;width:keyboard.letterWidth*1.4;height:108;label:keyboard.symbols?(keyboard.extraSymbols?"123":"#+="):(keyboard.shift?"SHIFT":"Shift");selected:!keyboard.symbols&&keyboard.shift;onTriggered:{if(keyboard.symbols)keyboard.extraSymbols=!keyboard.extraSymbols;else keyboard.shift=!keyboard.shift}}
                Action {objectName:"deleteKey";visible:index===2;anchors.right:parent.right;width:keyboard.letterWidth*1.4;height:108;label:"Del";onTriggered:keyboard.erase()}
            }
        }
        Row {spacing:4
            Action {objectName:"symbolModeButton";width:keyboard.letterWidth*1.5+2;height:96;label:keyboard.symbols?"ABC":"123";onTriggered:{keyboard.symbols=!keyboard.symbols;keyboard.extraSymbols=false}}
            Action {width:keyboard.letterWidth;height:96;fontSize:32;label:",";onTriggered:keyboard.type(",")}
            Action {objectName:"spaceKey";width:keyboard.letterWidth*5+16;height:96;label:"Space";onTriggered:keyboard.type(" ")}
            Action {width:keyboard.letterWidth;height:96;fontSize:32;label:".";onTriggered:keyboard.type(".")}
            Action {objectName:"doneKey";width:keyboard.letterWidth*1.5+2;height:96;label:"Done";onTriggered:keyboard.done()}
        }
    }
}
