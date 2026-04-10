import { font } from "@kit.ArkUI";

/**
 * 用于在 ArkUI Canvas 上绘制垂直、多列的蒙古文。
 */
@ComponentV2
export struct MongolianText {
  @Param text: string = ""; // 要渲染的文本内容，支持字面量 "\n" 换行
  @Param textSize: number = 20; // 字号（vp）
  @Param textColor: ResourceColor | string = Color.Black; // 文本颜色
  @Param textBackGroudColor: ResourceColor | string = Color.Transparent; // 组件背景色
  @Param lineSpacing: number = 5; // 列间距（竖排时每列之间的间隔）
  @Param textCounterOutline: number = 1; // 描边宽度，<=0 时不描边
  @Param textOutlineColor: string = ""; // 描边颜色，空字符串表示不启用描边
  @Param autoHeight: boolean = false; // 是否根据文本内容自动计算组件高度
  @Param maxHeight: number = 600; // autoHeight=true 时的最大高度限制（vp）
  @Param paddingLeft: number = 0; // 左内边距（影响首列起始 X）
  @Param paddingTop: number = 0; // 上内边距（影响首字符起始 Y）
  @Param preferredFontFamily: string = ""; // 自定义字体家族名（需与 preferredFontFile 配套）
  @Param inputSwitch: boolean = false; // 是否注册字体（输入法场景一般开启）
  @Param preferredFontFile: string = ""; // 自定义字体文件名（位于 resources/rawfile）

  private settings: RenderingContextSettings = new RenderingContextSettings(true); // Canvas 渲染上下文配置
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings); // 实际绘制上下文

  @Local private renderWidth: number = 0; // 当前计算得到的内容宽度（用于组件宽度）
  @Local private componentHeight: number = 0; // 当前组件高度（可能来自 autoHeight 或区域变化）
  @Local private textLines: string[] = []; // 经过换行计算后的列文本集合

  private readonly DEFAULT_FONT_FAMILY_NAME: string = "OyunQaganTig"; // 默认字体家族
  private readonly DEFAULT_FONT_FILE_NAME: string = "OyunQaganTig.ttf"; // 默认字体文件（rawfile）
  private readonly AUTO_HEIGHT_LENGTH_THRESHOLDS: number[] = [3, 10, 20, 30, 40, 50]; // 文本长度阈值
  private readonly AUTO_HEIGHT_FACTORS: number[] = [1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8]; // 对应长度阈值的高度系数

  private renderHeight: number = 0; // autoHeight 计算得到的渲染高度
  private registeredFontFamilies: Set<string> = new Set<string>(); // 已注册字体缓存，避免重复 registerFont

  private getFontFamilyName(): string {
    return this.preferredFontFamily || this.DEFAULT_FONT_FAMILY_NAME;
  }

  aboutToAppear() {
    if (this.inputSwitch) {
      this.registerFont();
    }
  }

  // 配置项变化统一入口：先处理字体与高度，再布局和重绘。

  @Monitor('text','textSize','textColor','textBackGroudColor','lineSpacing',
  'textCounterOutline','textOutlineColor','autoHeight','maxHeight','paddingLeft','paddingTop',
  'preferredFontFamily','preferredFontFile','inputSwitch')
  private refreshByConfigChange(): void {
    if (this.inputSwitch) {
      this.registerFont();
    }
    if (this.autoHeight) {
      this.calculateTextHeight();
    }
    this.calculateLayout();
    this.draw();
  }

  // 根据文本测量宽度与长度系数计算组件高度（autoHeight 开启时生效）。
  private calculateTextHeight() {
    if (!this.context || !this.text) {
      this.renderHeight = this.textSize;
      this.componentHeight = this.renderHeight;
      return;
    }

    const ctx = this.context;
    ctx.font = `${this.textSize}vp ${this.getFontFamilyName()}`;

    const lines = this.getProcessedText().split("\n");
    const maxWidth = this.getMaxLineWidth(lines, ctx);
    const factor = this.getAutoHeightFactor(this.getRenderableTextLength());

    this.renderHeight = this.clampRenderHeight(maxWidth + this.textSize * factor);
    this.componentHeight = this.renderHeight;
  }

  private registerFont() {
    let familyName = this.DEFAULT_FONT_FAMILY_NAME;
    let fileName = this.DEFAULT_FONT_FILE_NAME;

    if (this.preferredFontFamily && this.preferredFontFile) {
      familyName = this.preferredFontFamily;
      fileName = this.preferredFontFile;
    }

    this.registerFontIfNeeded(this.DEFAULT_FONT_FAMILY_NAME, this.DEFAULT_FONT_FILE_NAME);

    if (familyName !== this.DEFAULT_FONT_FAMILY_NAME) {
      this.registerFontIfNeeded(familyName, fileName);
    }
  }

  // 计算换行分列结果并更新渲染宽度。
  private calculateLayout() {
    if (!this.context || this.componentHeight <= 0) {
      return;
    }

    const ctx = this.context;
    ctx.font = `${this.textSize}vp ${this.getFontFamilyName()}`;

    const processedText = this.getProcessedText();
    const paragraphs = processedText.split("\n");
    const wrappedLines: string[] = [];

    const availableHeight = this.componentHeight - this.paddingTop;
    if (availableHeight <= 0) {
      this.textLines = [];
      this.renderWidth = this.paddingLeft;
      return;
    }

    for (let i = 0; i < paragraphs.length; i++) {
      const paragraph = paragraphs[i];
      if (paragraph.length === 0) {
        wrappedLines.push("");
        continue;
      }
      const lines = this.wrapParagraph(paragraph, availableHeight, ctx);
      for (let j = 0; j < lines.length; j++) {
        wrappedLines.push(lines[j]);
      }
    }

    this.textLines = wrappedLines;

    if (this.textLines.length > 0) {
      this.renderWidth = this.paddingLeft + this.textLines.length * (this.textSize + this.lineSpacing) + this.lineSpacing;
    } else {
      this.renderWidth = this.paddingLeft;
    }
  }

  // 按段落换行：优先按空格分词，超长词降级到逐字符拆分。
  private wrapParagraph(paragraph: string, availableHeight: number, ctx: CanvasRenderingContext2D): string[] {
    if (ctx.measureText(paragraph).width <= availableHeight) {
      return [paragraph];
    }

    const words = paragraph.split(" ").filter((word) => word.length > 0);
    if (words.length <= 1) {
      return this.wrapByCharacters(paragraph, availableHeight, ctx);
    }

    const wrappedLines: string[] = [];
    let currentLine = "";

    for (let i = 0; i < words.length; i++) {
      const word = words[i];
      const testLine = currentLine.length > 0 ? `${currentLine} ${word}` : word;

      if (ctx.measureText(testLine).width <= availableHeight) {
        currentLine = testLine;
        continue;
      }

      if (currentLine.length > 0) {
        wrappedLines.push(currentLine);
      }

      if (ctx.measureText(word).width <= availableHeight) {
        currentLine = word;
      } else {
        const wordParts = this.wrapByCharacters(word, availableHeight, ctx);
        for (let k = 0; k < wordParts.length - 1; k++) {
          wrappedLines.push(wordParts[k]);
        }
        currentLine = wordParts[wordParts.length - 1] || "";
      }
    }

    if (currentLine.length > 0) {
      wrappedLines.push(currentLine);
    }

    return wrappedLines.length > 0 ? wrappedLines : [paragraph];
  }

  // 逐字符换行兜底，适配无空格文本与超长 token。
  private wrapByCharacters(text: string, availableHeight: number, ctx: CanvasRenderingContext2D): string[] {
    const chars = Array.from(text);
    const wrappedLines: string[] = [];
    let currentLine = "";

    for (let i = 0; i < chars.length; i++) {
      const char = chars[i];
      const testLine = `${currentLine}${char}`;
      if (currentLine.length > 0 && ctx.measureText(testLine).width > availableHeight) {
        wrappedLines.push(currentLine);
        currentLine = char;
      } else {
        currentLine = testLine;
      }
    }

    if (currentLine.length > 0) {
      wrappedLines.push(currentLine);
    }

    return wrappedLines.length > 0 ? wrappedLines : [text];
  }

  // 绘制规则：
  // 1) 中日韩/全角字符正向绘制
  // 2) 其他字符旋转 90° 进行竖排
  // 3) 通过 run 分段避免破坏蒙古文连字样式
  private draw() {
    if (this.componentHeight <= 0 || this.textLines.length === 0) {
      return;
    }

    const ctx = this.context;
    ctx.clearRect(0, 0, this.renderWidth, this.componentHeight);

    ctx.font = `${this.textSize}vp ${this.getFontFamilyName()}`;
    ctx.fillStyle = this.resolveColor();
    ctx.textAlign = "start";
    ctx.textBaseline = "alphabetic";

    if (this.textOutlineColor && this.textCounterOutline > 0) {
      ctx.strokeStyle = this.textOutlineColor;
      ctx.lineWidth = this.textCounterOutline;
    }

    let currentColumnX = this.paddingLeft;

    for (let i = 0; i < this.textLines.length; i++) {
      const line = this.textLines[i];
      let currentOffset = 0;
      const chars = Array.from(line);
      let runText = "";
      let runIsCjk: boolean | null = null;

      // 输出当前 run 并推进列内偏移。
      const flushRun = () => {
        if (!runText || runIsCjk === null) {
          return;
        }

        if (runIsCjk) {
          const runChars = Array.from(runText);
          for (let k = 0; k < runChars.length; k++) {
            const cjkChar = runChars[k];
            const cjkWidth = ctx.measureText(cjkChar).width;
            const drawX = currentColumnX + (this.textSize - cjkWidth) / 2;
            const drawY = this.paddingTop + currentOffset + this.textSize;
            if (this.textOutlineColor && this.textCounterOutline > 0) {
              ctx.strokeText(cjkChar, drawX, drawY);
            }
            ctx.fillText(cjkChar, drawX, drawY);
            currentOffset += cjkWidth;
          }
        } else {
          const runWidth = ctx.measureText(runText).width;
          ctx.save();
          ctx.translate(currentColumnX + this.textSize, this.paddingTop + currentOffset);
          ctx.rotate(Math.PI / 2);
          if (this.textOutlineColor && this.textCounterOutline > 0) {
            ctx.strokeText(runText, 0, this.textSize);
          }
          ctx.fillText(runText, 0, this.textSize);
          ctx.restore();
          currentOffset += runWidth;
        }
      };

      for (let j = 0; j < chars.length; j++) {
        const char = chars[j];
        const isCjk = this.isCjkOrFullWidthChar(char);

        if (runIsCjk === null) {
          runIsCjk = isCjk;
          runText = char;
          continue;
        }

        if (runIsCjk === isCjk) {
          runText += char;
          continue;
        }

        flushRun();
        runIsCjk = isCjk;
        runText = char;
      }

      flushRun();
      currentColumnX += (this.textSize + this.lineSpacing);
    }
  }

  // 判断字符是否属于 CJK/全角范围（用于决定是否旋转）。
  private isCjkOrFullWidthChar(char: string): boolean {
    if (!char || char.length === 0) {
      return false;
    }
    const codePoint = char.codePointAt(0);
    if (codePoint === undefined) {
      return false;
    }
    return (codePoint >= 0x3400 && codePoint <= 0x4DBF)
      || (codePoint >= 0x4E00 && codePoint <= 0x9FFF)
      || (codePoint >= 0xF900 && codePoint <= 0xFAFF)
      || (codePoint >= 0x20000 && codePoint <= 0x2A6DF)
      || (codePoint >= 0x2A700 && codePoint <= 0x2B73F)
      || (codePoint >= 0x2B740 && codePoint <= 0x2B81F)
      || (codePoint >= 0x2B820 && codePoint <= 0x2CEAF)
      || (codePoint >= 0x3000 && codePoint <= 0x303F)
      || (codePoint >= 0xFF00 && codePoint <= 0xFFEF);
  }

  // 将字面量 "\\n" 归一化为真实换行符。
  private getProcessedText(): string {
    return this.text.replace(/\\n/g, "\n");
  }

  // 取所有行中最大测量宽度。
  private getMaxLineWidth(lines: string[], ctx: CanvasRenderingContext2D): number {
    let maxWidth = 0;
    for (let i = 0; i < lines.length; i++) {
      const width = ctx.measureText(lines[i]).width;
      if (width > maxWidth) {
        maxWidth = width;
      }
    }
    return maxWidth;
  }

  // 获取可渲染文本长度（忽略换行）。
  private getRenderableTextLength(): number {
    const normalizedText = this.getProcessedText().replace(/\n/g, "");
    return Array.from(normalizedText).length;
  }

  // 根据文本长度选择自适应高度系数。
  private getAutoHeightFactor(textLength: number): number {
    for (let i = 0; i < this.AUTO_HEIGHT_LENGTH_THRESHOLDS.length; i++) {
      if (textLength < this.AUTO_HEIGHT_LENGTH_THRESHOLDS[i]) {
        return this.AUTO_HEIGHT_FACTORS[i];
      }
    }
    return this.AUTO_HEIGHT_FACTORS[this.AUTO_HEIGHT_FACTORS.length - 1];
  }

  // 受 maxHeight 限制时裁剪高度。
  private clampRenderHeight(height: number): number {
    if (this.maxHeight > 0) {
      return Math.min(height, this.maxHeight);
    }
    return height;
  }

  // 同 familyName 仅注册一次，避免重复注册开销。
  private registerFontIfNeeded(familyName: string, fileName: string): void {
    if (this.registeredFontFamilies.has(familyName)) {
      return;
    }
    try {
      font.registerFont({
        familyName: familyName,
        familySrc: `/resources/rawfile/${fileName}`
      });
      this.registeredFontFamilies.add(familyName);
    } catch (e) {
    }
  }

  // 统一颜色解析，兼容 string 与 ResourceColor。
  private resolveColor(): string {
    if (typeof this.textColor === "string") {
      return this.textColor;
    }
    return this.textColor.toString();
  }

  // 区域高度变化时重排重绘，1px 阈值用于抑制无效抖动。
  private handleAreaChange(oldArea: Area, newArea: Area) {
    const newHeight = newArea.height as number;

    if (newHeight > 0 && Math.abs(newHeight - this.componentHeight) > 1) {
      this.componentHeight = newHeight;
      this.calculateLayout();
      this.draw();
    }
  }

  build() {
    Stack() {
      Canvas(this.context)
        .width("100%")
        .height("100%")
        .onReady(() => {
          if (this.autoHeight) {
            this.calculateTextHeight();
          }
          if (this.componentHeight > 0) {
            this.calculateLayout();
            this.draw();
          }
        })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.handleAreaChange(oldValue, newValue);
        });
    }
    .width(this.renderWidth > 0 ? this.renderWidth : 1)
    .height(this.autoHeight ? this.componentHeight : "100%")
    .alignContent(Alignment.Start)
    .backgroundColor(this.textBackGroudColor);
  }
}