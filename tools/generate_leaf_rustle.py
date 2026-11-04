"""Original synthetic leaf rustle. No recordings or external samples. CC0-1.0."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
SECONDS = 12


def generate():
    rng = random.Random(72419)
    low = soft = 0.0
    samples = []
    for index in range(RATE * SECONDS):
        time = index / RATE
        noise = rng.uniform(-1, 1)
        low += 0.09 * (noise - low)
        soft += 0.5 * ((noise - low) - soft)
        # Whole-number cycles keep the slow envelopes continuous at the seam.
        breeze = 0.65 + 0.17 * math.sin(math.tau * time / SECONDS)
        detail = 0.85 + 0.15 * math.sin(math.tau * time * 23 / SECONDS)
        samples.append(soft * breeze * detail)
    # Overlap equal-power crossfade: loop endpoint and slope follow the start.
    overlap = RATE // 2
    output = samples[overlap:]
    for index in range(overlap):
        blend = index / (overlap - 1)
        output[-overlap + index] = (
            samples[-overlap + index] * math.cos(blend * math.pi / 2)
            + samples[index] * math.sin(blend * math.pi / 2)
        )
    peak = max(abs(value) for value in output)
    pcm = b"".join(struct.pack("<h", round(value / peak * 0.45 * 32767)) for value in output)
    path = Path(__file__).resolve().parents[1] / "assets/audio/leaf_rustle.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm)
    print(path.relative_to(path.parents[2]), len(output), "samples")


if __name__ == "__main__":
    generate()
