// Web Audio API Sound Synthesizer for InPoint Check-in System
// Generates crystal-clear audio feedback without requiring external audio asset files

class SoundManager {
    constructor() {
        this.ctx = null;
        this.enabled = true;
    }

    init() {
        try {
            if (!this.ctx) {
                const AudioContextClass = window.AudioContext || window.webkitAudioContext;
                if (AudioContextClass) {
                    this.ctx = new AudioContextClass();
                }
            }
            if (this.ctx && this.ctx.state === 'suspended') {
                this.ctx.resume().catch(() => {});
            }
        } catch (e) {
            console.warn('AudioContext init skipped:', e);
        }
    }

    toggle() {
        this.enabled = !this.enabled;
        return this.enabled;
    }

    // Standard Check-in Chime: Bright pleasant dual chime (E6 -> A6)
    playCheckInSuccess() {
        if (!this.enabled) return;
        try {
            this.init();
            if (!this.ctx) return;

            const now = this.ctx.currentTime;
            const osc1 = this.ctx.createOscillator();
            const osc2 = this.ctx.createOscillator();
            const gain = this.ctx.createGain();

            osc1.type = 'sine';
            osc1.frequency.setValueAtTime(1318.51, now); // E6
            osc1.frequency.setValueAtTime(1760.00, now + 0.08); // A6

            osc2.type = 'triangle';
            osc2.frequency.setValueAtTime(659.25, now); // E5
            osc2.frequency.setValueAtTime(880.00, now + 0.08); // A5

            gain.gain.setValueAtTime(0.01, now);
            gain.gain.linearRampToValueAtTime(0.18, now + 0.02);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.45);

            osc1.connect(gain);
            osc2.connect(gain);
            gain.connect(this.ctx.destination);

            osc1.start(now);
            osc2.start(now);
            osc1.stop(now + 0.45);
            osc2.stop(now + 0.45);
        } catch (e) {
            console.warn('playCheckInSuccess error:', e);
        }
    }

    // VIP Grand Fanfare Chime: Majestic 4-note chord (C5 -> E5 -> G5 -> C6)
    playVipFanfare() {
        if (!this.enabled) return;
        try {
            this.init();
            if (!this.ctx) return;

            const now = this.ctx.currentTime;
            const notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
            
            notes.forEach((freq, i) => {
                const osc = this.ctx.createOscillator();
                const gain = this.ctx.createGain();

                osc.type = i === 3 ? 'sine' : 'triangle';
                osc.frequency.setValueAtTime(freq, now + i * 0.07);

                const startTime = now + i * 0.07;
                gain.gain.setValueAtTime(0.01, startTime);
                gain.gain.linearRampToValueAtTime(0.16, startTime + 0.03);
                gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.7);

                osc.connect(gain);
                gain.connect(this.ctx.destination);

                osc.start(startTime);
                osc.stop(startTime + 0.7);
            });
        } catch (e) {
            console.warn('playVipFanfare error:', e);
        }
    }

    // Undo / Alert Chime (Gentle lower double note)
    playUndoSound() {
        if (!this.enabled) return;
        try {
            this.init();
            if (!this.ctx) return;

            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();

            osc.type = 'sine';
            osc.frequency.setValueAtTime(587.33, now); // D5
            osc.frequency.setValueAtTime(440.00, now + 0.08); // A4

            gain.gain.setValueAtTime(0.01, now);
            gain.gain.linearRampToValueAtTime(0.15, now + 0.02);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);

            osc.connect(gain);
            gain.connect(this.ctx.destination);

            osc.start(now);
            osc.stop(now + 0.35);
        } catch (e) {
            console.warn('playUndoSound error:', e);
        }
    }
}

window.soundManager = new SoundManager();
