# AR9271 Custom Firmware for WFB-NG

Firmware AR9271 patché pour [WFB-NG](https://github.com/svpcom/wfb-ng) avec **MCS configurable à la compilation**.

Le firmware stock de l'AR9271 ignore les demandes de débit (rate) du driver Linux `ath9k_htc`. Le rate d'injection est codé en dur dans le firmware. Ce dépôt permet de compiler un firmware qui force le MCS de votre choix, pour optimiser soit la **portée** (MCS0), soit le **débit** (MCS3+).

## Table des MCS

| MCS | Débit (HT20) | Modulation | Sensibilité RX | Usage |
|-----|-------------|------------|-----------------|-------|
| **0** | **6.5 Mbit/s** | BPSK 1/2 | **~-82 dBm** | **Portée maximale** — tunnel IP, télémétrie |
| 1 | 13 Mbit/s | QPSK 1/2 | ~-79 dBm | Bon compromis portée/débit |
| 2 | 19.5 Mbit/s | QPSK 3/4 | ~-77 dBm | Équilibré |
| 3 | 26 Mbit/s | 16-QAM 1/2 | ~-72 dBm | Défaut wifibroadcast — vidéo SD/HD |
| 4 | 39 Mbit/s | 16-QAM 3/4 | ~-68 dBm | Vidéo HD courte portée |
| 5 | 52 Mbit/s | 64-QAM 2/3 | ~-65 dBm | Très courte portée |
| 6 | 58.5 Mbit/s | 64-QAM 3/4 | ~-64 dBm | Très courte portée |
| 7 | 65 Mbit/s | 64-QAM 5/6 | ~-63 dBm | Débit max, portée minimale |

> Chaque palier de MCS en moins donne environ **+3 à +5 dB** de budget de liaison,
> ce qui correspond à peu près à un **doublement de la portée** entre MCS3 et MCS0.

## Prérequis

```bash
sudo apt install build-essential cmake git m4 texinfo
```

## Compilation

```bash
# Cloner ce dépôt (fork de qca/open-ath9k-htc-firmware)
git clone https://github.com/alixpat/open-ath9k-htc-firmware.git
cd open-ath9k-htc-firmware

# Compiler avec MCS0 (portée max) — par défaut
make MCS=0

# Ou avec un autre MCS
make MCS=1    # 13 Mbit/s — compromis portée/débit
make MCS=3    # 26 Mbit/s — vidéo HD (équivalent firmware goodwin)
```

La première compilation prend **30-60 minutes** (toolchain GCC cross-compile pour Xtensa).
Les compilations suivantes sont rapides (~30 secondes).

### Problème connu : échec du test MPFR `tsprintf`

Sur les systèmes récents (Debian Trixie, Ubuntu 24.04+), le test `tsprintf` de la
bibliothèque MPFR échoue. C'est un faux positif sans impact. Le script `build.sh`
gère automatiquement ce cas.

Si le build échoue quand même sur MPFR :

```bash
cd toolchain/build/mpfr-*/
make install
touch .built
cd -
make MCS=0
```

## Installation

```bash
# Installer le firmware compilé
sudo make install MCS=0

# Ou manuellement
sudo cp firmware/htc_9271-MCS0.fw /lib/firmware/ath9k_htc/htc_9271-1.4.0.fw
sudo modprobe -r ath9k_htc && sudo modprobe ath9k_htc
```

### Mécanisme d'installation

Sur les distributions récentes (Debian 12+, Ubuntu 24.04+), le firmware stock est
livré compressé en `.fw.zst`. Le noyau Linux charge les firmwares dans cet ordre :

1. **`.fw`** (non compressé) — **prioritaire**
2. `.fw.zst` (compressé zstd)
3. `.fw.xz`, `.fw.gz`

Le script installe le firmware patché **non compressé** (`.fw`) à côté du stock
compressé (`.fw.zst`). Le noyau charge automatiquement la version patchée.

### Retour au firmware stock

```bash
sudo rm /lib/firmware/ath9k_htc/htc_9271-1.4.0.fw
sudo modprobe -r ath9k_htc && sudo modprobe ath9k_htc
# Le noyau rechargera le .fw.zst stock
```

## Vérification

```bash
# Vérifier que le firmware patché est chargé
dmesg | grep -i "ath9k_htc.*FW"
# La taille doit différer du firmware stock (~51008 bytes)

# Vérifier l'injection
sudo ip link set wlan0 down
sudo iw dev wlan0 set type monitor
sudo ip link set wlan0 up
sudo aireplay-ng --test wlan0
```

## Utilisation avec WFB-NG

Ce firmware est conçu pour fonctionner avec [WFB-NG](https://github.com/svpcom/wfb-ng)
sur des cartes WiFi à chipset Atheros AR9271 (TP-Link TL-WN722N v1, Alfa AWUS036NHA, etc.).

Voir le [guide complet WFB-NG + AR9271](https://github.com/alixpat/open-ath9k-htc-firmware/wiki)
pour la configuration de bout en bout.

## Comment ça marche

Le patch modifie une seule ligne dans `target_firmware/wlan/if_owl.c` :

```c
// Stock firmware (54 Mb OFDM legacy)
bf->bf_rcs[0].rix = 0xb;

// Patché pour MCS0 (6.5 Mb HT20 — portée max)
bf->bf_rcs[0].rix = 0x0c;   // PATCHED_MCS0 = 6.5Mb
```

Le `rix` (rate index) pointe vers une entrée de la table de rates dans
`target_firmware/wlan/ar5416Phy.c`. Les paquets injectés en mode monitor
passent par le chemin multicast (`bf->bf_ismcast`) du firmware, qui utilise
ce rate fixe au lieu du rate control dynamique.

## Matériel testé

- Alfa AWUS036NHA (AR9271 + PA SE2576L)
- Dongles AR9271 génériques

## Fichiers ajoutés par ce fork

| Fichier | Description |
|---------|-------------|
| `build.sh` | Script de build complet avec gestion du MCS |
| `patch_rate.sh` | Patch du rate dans if_owl.c |
| `install.sh` | Installation du firmware avec backup du stock |
| `GNUmakefile` | Wrapper Makefile (`make MCS=x`) |

## Crédits

- [qca/open-ath9k-htc-firmware](https://github.com/qca/open-ath9k-htc-firmware) — firmware open-source original
- [befinitiv/wifibroadcast](https://befinitiv.wordpress.com/wifibroadcast-analog-like-transmission-of-live-video-data/) — projet wifibroadcast original et découverte du patch de rate
- [goodwin/wifibroadcast](https://github.com/goodwin/wifibroadcast) — firmware patché MCS3 pré-compilé
- [svpcom/wfb-ng](https://github.com/svpcom/wfb-ng) — WFB-NG, la version maintenue de wifibroadcast

## Licence

Voir [LICENCE.TXT](LICENCE.TXT) — ClearBSD pour le code Atheros, MIT pour Tensilica, GPLv2 pour les fichiers ECOS.
