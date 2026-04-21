import numpy as np
import wave

# 参数设置
duration = 0.35  # 秒，作为按钮交互短音效
sample_rate = 44100  # 采样率
amplitude = 0.2  # 音量

# 1. 生成基础电流声 (50Hz 嗡嗡声)
t = np.linspace(0, duration, int(sample_rate * duration))
hum = np.sin(2 * np.pi * 50 * t) 

# 2. 加入“滋滋”的高频随机噪声 (白噪声)
static = np.random.uniform(-1, 1, len(t))

# 3. 混合声音：电流嗡嗡声 + 随机噪声
# 加入一些不稳定的增益波动，让它听起来像“接触不良”
fluctuation = np.sin(2 * np.pi * 0.5 * t) * 0.5 + 0.5
combined = (hum * 0.3 + static * 0.7) * amplitude * fluctuation

# 归一化并转换为 16-bit PCM 格式
audio_data = (combined * 32767).astype(np.int16)

# 保存为 wav 文件
with wave.open('electric_hum.wav', 'w') as f:
    f.setnchannels(1)  # 单声道
    f.setsampwidth(2)  # 2 bytes per sample
    f.setframerate(sample_rate)
    f.writeframes(audio_data.tobytes())

print("赛博电流声已生成：electric_hum.wav")