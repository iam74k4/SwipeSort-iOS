#!/usr/bin/env python3
"""
一時的なプレースホルダーアプリアイコンを生成するスクリプト
"""
from PIL import Image, ImageDraw, ImageFont
import os

# 出力ディレクトリ
output_dir = "SwipeSort/Assets.xcassets/AppIcon.appiconset"

# 必要なサイズの定義（filename: (width, height)）
sizes = {
    "AppIcon-20x20@1x.png": (20, 20),
    "AppIcon-20x20@2x.png": (40, 40),
    "AppIcon-20x20@3x.png": (60, 60),
    "AppIcon-29x29@1x.png": (29, 29),
    "AppIcon-29x29@2x.png": (58, 58),
    "AppIcon-29x29@3x.png": (87, 87),
    "AppIcon-40x40@1x.png": (40, 40),
    "AppIcon-40x40@2x.png": (80, 80),
    "AppIcon-40x40@3x.png": (120, 120),
    "AppIcon-60x60@2x.png": (120, 120),
    "AppIcon-60x60@3x.png": (180, 180),
    "AppIcon-76x76@1x.png": (76, 76),
    "AppIcon-76x76@2x.png": (152, 152),
    "AppIcon-83.5x83.5@2x.png": (167, 167),
    "AppIcon-1024x1024.png": (1024, 1024),
}

def create_placeholder_icon(filename, width, height):
    """プレースホルダーアイコン画像を生成"""
    # 背景色（青系のグラデーション）
    img = Image.new('RGB', (width, height), color='#4A90E2')
    draw = ImageDraw.Draw(img)
    
    # 角丸の矩形を描画
    border_radius = min(width, height) // 8
    draw.rounded_rectangle(
        [(0, 0), (width-1, height-1)],
        radius=border_radius,
        fill='#5BA3F5',
        outline='#3A7BC8',
        width=max(1, width // 64)
    )
    
    # 中央に"S"の文字を描画（プレースホルダーとして）
    try:
        # フォントサイズを計算
        font_size = int(min(width, height) * 0.6)
        # システムフォントを試す
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except:
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", font_size)
            except:
                font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()
    
    # テキストを中央に配置
    text = "S"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    position = ((width - text_width) // 2, (height - text_height) // 2 - bbox[1])
    
    draw.text(position, text, fill='white', font=font)
    
    # ファイルに保存
    output_path = os.path.join(output_dir, filename)
    img.save(output_path, 'PNG')
    print(f"✓ Created: {filename} ({width}x{height})")

def main():
    """メイン処理"""
    # 出力ディレクトリが存在することを確認
    if not os.path.exists(output_dir):
        print(f"Error: Directory {output_dir} does not exist")
        return
    
    print("Generating placeholder app icons...")
    print(f"Output directory: {output_dir}\n")
    
    # 各サイズの画像を生成
    for filename, (width, height) in sizes.items():
        create_placeholder_icon(filename, width, height)
    
    print(f"\n✓ All placeholder icons generated successfully!")
    print("⚠️  Note: These are temporary placeholder images. Replace with actual app icons before release.")

if __name__ == "__main__":
    main()
