# openclaw-opencode-bridge

[![npm version](https://img.shields.io/npm/v/openclaw-opencode-bridge)](https://www.npmjs.com/package/openclaw-opencode-bridge)
[![license](https://img.shields.io/npm/l/openclaw-opencode-bridge)](LICENSE)
[![node](https://img.shields.io/node/v/openclaw-opencode-bridge)](package.json)

Language: [English](README_EN.md)

Bridge untuk menghubungkan channel OpenClaw ke OpenCode lewat command prefix seperti `/cc` atau `@cc`.

Pesan dari user akan langsung dieksekusi oleh OpenCode CLI (`opencode run`), lalu hasilnya dikirim balik lewat `openclaw message send`.

<p>
  <img src="DEMO_1.png" alt="Telegram demo — sending a command" width="400" />
  <img src="DEMO_2.png" alt="Telegram demo — receiving a response" width="400" />
</p>

> ⚠️ Fokus pengujian saat ini adalah Telegram. Channel lain mungkin butuh penyesuaian format.

## Donasi

Kalau project ini membantu, kamu bisa dukung lewat:

`0xe81c32383C8F21A14E6C2264939dA512e9F9bb42`

## Fitur Utama

- Prefix command: `@cc`, `/cc`, `@ccn`, `/ccn`, `@ccu`, `@ccm`, `@ccms`
- Reply OpenCode dikirim otomatis ke user lewat channel OpenClaw
- Output dibersihkan dari noise terminal/tool logs
- Timeout bersifat batas maksimum, bukan delay tetap
- Dukungan onboarding/uninstall otomatis

## Alur Kerja Singkat

1. User kirim pesan ber-prefix, contoh: `/cc buat script python`.
2. Plugin menangkap pesan dan menahan reply default gateway.
3. Script bridge menjalankan `opencode run`.
4. Hasil OpenCode dikirim balik ke user melalui `openclaw message send`.

## Prasyarat

| Dependency | Install |
|---|---|
| [OpenClaw](https://openclaw.ai) | `npm i -g openclaw` |
| [OpenCode](https://opencode.ai) | `npm i -g opencode-ai` |
| [tmux](https://github.com/tmux/tmux) | Auto-installed during onboard if missing |

> Sistem operasi yang didukung: Linux dan macOS.

## Instalasi Cepat

```bash
npm i -g openclaw-opencode-bridge
openclaw-opencode-bridge onboard
```

Wizard onboarding akan mengatur plugin, script, AGENTS.md, daemon, dan konfigurasi channel.

Tes awal:

```bash
/cc hello
```

## Daftar Perintah

| Prefix | Fungsi |
|---|---|
| `@cc` · `/cc` | Lanjut ke sesi terbaru (`--continue`) |
| `@ccn` · `/ccn` | Jalankan sesi baru tanpa `--continue` (konteks fresh) |
| `@ccu` · `/ccu` | Tampilkan statistik pemakaian OpenCode |
| `@ccm` · `/ccm` | Tampilkan daftar model OpenCode |
| `@ccms` · `/ccms` | Ganti model OpenCode (nomor atau model-id) |

Contoh:

```bash
/cc refactor auth module dan tambah unit test
/ccn review PR ini: https://github.com/org/repo/pull/42
/ccu
```

## Perilaku Timeout

- `/cc` memakai timeout adaptif dengan base `60s` dan maksimum `300s`.
- `/ccn` memakai timeout adaptif dengan base `90s` dan maksimum `420s`.
- Timeout adalah batas maksimal proses. Kalau OpenCode selesai lebih cepat, reply langsung dikirim saat itu juga.

## Catatan Sesi

- `/ccn` tidak menghapus semua history OpenCode.
- `/cc` biasanya melanjutkan sesi terbaru.
- Data sesi OpenCode tersimpan di direktori data OpenCode user (contoh Linux: `~/.local/share/opencode`).

## Migrasi dari Versi Lama

Versi 2+ menggantikan sistem skill/hook lama menjadi plugin OpenClaw tunggal:

```bash
npm i -g openclaw-opencode-bridge
openclaw-opencode-bridge onboard
```

Komponen legacy akan dibersihkan otomatis saat onboarding.

## Uninstall

```bash
openclaw-opencode-bridge uninstall
```

Ini akan menghapus plugin, script bridge, AGENTS.md hasil instalasi bridge, dan daemon.

## Troubleshooting

| Gejala | Solusi |
|---|---|
| Gateway LLM tetap membalas | Jalankan `openclaw gateway restart` |
| Ada “OpenCode will reply shortly” tapi tidak ada balasan akhir | Cek log `/tmp/opencode-bridge-send.log` lalu ulangi `openclaw-opencode-bridge onboard` |
| Perintah lambat/timeout | Cek prompt terlalu berat, lihat log bridge, pastikan OpenCode CLI normal |
| Output aneh/berantakan | Ulangi onboarding agar script/plugin terbaru terpasang |

## License

[MIT](LICENSE)
