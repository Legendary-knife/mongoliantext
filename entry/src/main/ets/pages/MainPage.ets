import { MongolianText } from "@mongolian/mongoliantext";

@Entry
@Component
export struct MainPage {
  @State message: string = 'ᠡᠳᠡᠭᠡᠳᠡᠭ ᠡᠳᠡᠭ\\nᠡᠳᠡᠭᠡ ᠡᠭᠡᠳᠡᠭ';

  build() {
    Row() {
      Column() {
        Text('MongolianText 组件示例')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 12 })

        MongolianText({
          text: this.message,
          textSize: 26,
          lineSpacing: 8,
          autoHeight: true,
          maxHeight: 420,
          paddingLeft: 10,
          paddingTop: 8,
          textColor: '#111111',
          textBackGroudColor: '#F3F5F7'
        })
          .height(420)
          .backgroundColor('#F3F5F7')

        Text('点击下方按钮切换示例文本')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 12, bottom: 8 })

        Text('切换')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#DDE7FF')
          .borderRadius(8)
          .onClick(() => {
            this.message = this.message.includes('中文显示示例')
              ? '蒙古文 + 英文示例\\nᠡᠳᠡᠭᠡᠳᠡᠭ ᠡᠳᠡᠭ werwer wrt'
              : '蒙古文竖排示例\\nᠡᠳᠡᠭᠡ ᠳᠡᠭ中文显示示例';
          })
      }
      .width('100%')
      .padding(16)
    }
    .height('100%')
  }
}
