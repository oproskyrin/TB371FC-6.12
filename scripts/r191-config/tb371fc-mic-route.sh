#!/bin/sh
# R191: main microphone (AMIC1 -> WCD938x ADC1 -> TX macro DEC0) -> TX_CODEC_DMA_TX_3 -> MultiMedia2 (hw:0,2).
# Stock Android handset-mic also uses ADC4/INP5 (second mic); with two SoundWire ports active the 6.12
# SoundWire channel mapping corrupts the stream, so it stays off for now.
c() { amixer -q -c0 cset name="$1" "$2" || echo "tb371fc-mic-route: '$1' = '$2' failed"; }
# everything else off: a second active ADC/SoundWire port corrupts the stream (old mixer states may be restored)
for a in 2 3 4; do c "ADC$a Switch" 0; c "ADC${a}_MIXER Switch" 0; done
for d in 1 2 3 4 5 6 7; do c "TX_AIF1_CAP Mixer DEC$d" 0; done
c 'MultiMedia1 Mixer TX_CODEC_DMA_TX_3' 0
c 'ADC1 Switch' 1; c 'ADC1_MIXER Switch' 1; c 'ADC1 Volume' 8; c 'TX0 MODE' ADC_HIFI
c 'TX DEC0 MUX' SWR_MIC; c 'TX SMIC MUX0' ADC0; c 'TX_AIF1_CAP Mixer DEC0' 1
c 'MultiMedia2 Mixer TX_CODEC_DMA_TX_3' 1
echo "tb371fc-mic-route: done"
