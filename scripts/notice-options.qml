// Preview-only alternatives. The installed application is unchanged.
import QtQuick
import QtQuick.Window
import "../qml" as Books

Window {
    id:window;width:1404;height:1872;visible:true;color:"#f4f4f4"
    property int option:Qt.application.arguments.indexOf("--cards")>=0?2:Qt.application.arguments.indexOf("--reading")>=0?3:1
    property string authorTitle:"Don't forget about the authors."
    property string authorIntro:"They deserve to be compensated for their work."
    property string authorBody:"If you enjoy a book, please consider purchasing a physical copy or supporting the author in another way."
    property string libraryBody:"If you can't afford a book, ask your local library if it can purchase a copy for the library."
    property string donateBody:"Please consider donating to Anna's Archive to support the largest truly open library in human history."
    property string benefits:"Membership donations unlock fast downloads without a waitlist, with daily limits based on your tier."
    property string setup:"reStore supports secret-key login and fast downloads: enter your account's secret key in Settings to use your membership in the app."
    property string caveat:"Some tiers also offer reduced browser verification, though CAPTCHA checks can still appear in reStore."
    function findItem(item,name){if(item.objectName===name)return item;for(var i=0;i<item.children.length;i++){var found=findItem(item.children[i],name);if(found)return found}return null}
    component Copy:Text {color:"black";font.family:"DejaVu Sans";font.pixelSize:28;font.weight:Font.Normal;wrapMode:Text.Wrap;textFormat:Text.PlainText;lineHeight:1.22}
    component Eyebrow:Copy {font.pixelSize:18;font.bold:true;font.letterSpacing:2}
    Books.Main {id:app;testing:true;anchors.fill:parent;view:"home";query:"";message:"";Component.onCompleted:window.findItem(app,"homeNotices").visible=false}

    // 1: open editorial layout, with a quiet reading rhythm and a library callout.
    Column {
        visible:window.option===1;x:88;y:254;width:window.width-176;spacing:28
        Eyebrow {text:"SUPPORT THE PEOPLE BEHIND THE BOOKS"}
        Copy {width:parent.width;text:window.authorTitle;font.pixelSize:48;font.bold:true;lineHeight:1.12}
        Copy {width:parent.width;text:window.authorIntro;font.pixelSize:31;font.bold:true}
        Copy {width:parent.width;text:window.authorBody}
        Rectangle {
            width:parent.width;height:libraryCopy.height+44;color:"#e5e5e5"
            Rectangle {width:5;height:parent.height;color:"black"}
            Copy {id:libraryCopy;x:26;y:22;width:parent.width-52;text:window.libraryBody;font.pixelSize:26}
        }
        Item {width:1;height:14}
        Rectangle {width:parent.width;height:2;color:"black"}
        Item {width:1;height:8}
        Eyebrow {text:"SUPPORT OPEN ACCESS"}
        Copy {text:"Keep knowledge open.";font.pixelSize:44;font.bold:true}
        Copy {width:parent.width;text:window.donateBody}
        Rectangle {
            width:parent.width;height:featureCopy.height+44;color:"white";border.width:2;border.color:"black";radius:10
            Copy {id:featureCopy;x:26;y:22;width:parent.width-52;text:window.benefits;font.pixelSize:28;font.bold:true}
        }
        Copy {width:parent.width;text:window.setup;font.pixelSize:26}
        Copy {width:parent.width;text:window.caveat;font.pixelSize:22;color:"#444444"}
    }

    // 2: two compact outlined cards with clear headings and grouped benefits.
    Column {
        visible:window.option===2;x:50;y:232;width:window.width-100;spacing:32
        Rectangle {
            width:parent.width;height:authorCard.height+64;color:"white";radius:16;border.color:"black";border.width:2
            Column {id:authorCard;x:32;y:32;width:parent.width-64;spacing:24
                Row {spacing:20
                    Rectangle {width:56;height:56;radius:28;color:"black";Copy {anchors.centerIn:parent;text:"1";font.pixelSize:28;font.bold:true;color:"white"}}
                    Copy {anchors.verticalCenter:parent.verticalCenter;text:"Support the authors";font.pixelSize:38;font.bold:true}
                }
                Rectangle {width:parent.width;height:2;color:"black"}
                Copy {width:parent.width;text:window.authorTitle+" "+window.authorIntro;font.pixelSize:29;font.bold:true}
                Copy {width:parent.width;text:window.authorBody;font.pixelSize:27}
                Rectangle {
                    width:parent.width;height:libraryCardCopy.height+36;radius:8;color:"#eeeeee"
                    Copy {id:libraryCardCopy;x:18;y:18;width:parent.width-36;text:window.libraryBody;font.pixelSize:26}
                }
            }
        }
        Rectangle {
            width:parent.width;height:donateCard.height+64;color:"white";radius:16;border.color:"black";border.width:2
            Column {id:donateCard;x:32;y:32;width:parent.width-64;spacing:24
                Row {spacing:20
                    Rectangle {width:56;height:56;radius:28;color:"black";Copy {anchors.centerIn:parent;text:"2";font.pixelSize:28;font.bold:true;color:"white"}}
                    Copy {anchors.verticalCenter:parent.verticalCenter;text:"Support Anna's Archive";font.pixelSize:38;font.bold:true}
                }
                Rectangle {width:parent.width;height:2;color:"black"}
                Copy {width:parent.width;text:window.donateBody;font.pixelSize:27}
                Rectangle {
                    width:parent.width;height:membershipCard.height+44;color:"#eeeeee";radius:8
                    Column {id:membershipCard;x:22;y:22;width:parent.width-44;spacing:14
                        Copy {width:parent.width;text:"Your membership works in reStore";font.pixelSize:29;font.bold:true}
                        Copy {width:parent.width;text:window.benefits;font.pixelSize:26}
                        Copy {width:parent.width;text:window.setup;font.pixelSize:25}
                    }
                }
                Copy {width:parent.width;text:window.caveat;font.pixelSize:22;color:"#444444"}
            }
        }
    }

    // 3: a centered reading-page treatment with more whitespace and larger titles.
    Column {
        visible:window.option===3;x:128;y:256;width:window.width-256;spacing:26
        Eyebrow {anchors.horizontalCenter:parent.horizontalCenter;text:"A LITTLE SUPPORT GOES A LONG WAY"}
        Copy {width:parent.width;text:window.authorTitle;font.pixelSize:50;font.bold:true;horizontalAlignment:Text.AlignHCenter;lineHeight:1.1}
        Copy {width:parent.width;text:window.authorIntro;font.pixelSize:28;horizontalAlignment:Text.AlignHCenter}
        Copy {width:parent.width;text:window.authorBody;font.pixelSize:28;horizontalAlignment:Text.AlignHCenter}
        Copy {width:parent.width;text:window.libraryBody;font.pixelSize:26;horizontalAlignment:Text.AlignHCenter}
        Item {width:1;height:12}
        Rectangle {anchors.horizontalCenter:parent.horizontalCenter;width:130;height:4;color:"black"}
        Item {width:1;height:12}
        Copy {width:parent.width;text:"Keep the library open.";font.pixelSize:46;font.bold:true;horizontalAlignment:Text.AlignHCenter}
        Copy {width:parent.width;text:window.donateBody;font.pixelSize:28;horizontalAlignment:Text.AlignHCenter}
        Rectangle {
            width:parent.width;height:readingPerks.height+52;color:"white";border.width:2;border.color:"black";radius:12
            Column {id:readingPerks;x:26;y:26;width:parent.width-52;spacing:20
                Copy {width:parent.width;text:"Membership, built into reStore";font.pixelSize:30;font.bold:true;horizontalAlignment:Text.AlignHCenter}
                Rectangle {width:parent.width;height:1;color:"black"}
                Copy {width:parent.width;text:window.benefits;font.pixelSize:26;horizontalAlignment:Text.AlignHCenter}
                Copy {width:parent.width;text:window.setup;font.pixelSize:25;horizontalAlignment:Text.AlignHCenter}
            }
        }
        Copy {width:parent.width;text:window.caveat;font.pixelSize:21;color:"#444444";horizontalAlignment:Text.AlignHCenter}
    }
    Timer {interval:700;running:true;onTriggered:{var args=Qt.application.arguments,i=args.indexOf("--output");if(i>=0)window.contentItem.grabToImage(function(result){result.saveToFile(args[i+1]);Qt.quit()})}}
}
