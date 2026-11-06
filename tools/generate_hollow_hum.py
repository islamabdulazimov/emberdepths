"""Original synthesized hollowbeak warning hum. CC0-1.0. Python stdlib only."""
from pathlib import Path
import math,struct,wave
rate=22050
samples=[]
for i in range(int(rate*.9)):
 t=i/rate
 fade=min(1,t/.08)*min(1,(.9-t)/.08)
 envelope=(.18+.65*t/.9)*fade
 value=(math.sin(2*math.pi*(72*t+22*t*t))*.7+math.sin(2*math.pi*146*t)*.3)*envelope
 samples.append(struct.pack('<h',int(value*18000)))
with wave.open(str(Path(__file__).resolve().parents[1]/'assets/audio/hollow_hum.wav'),'wb') as w:
 w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes(b''.join(samples))
