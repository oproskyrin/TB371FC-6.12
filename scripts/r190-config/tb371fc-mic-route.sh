#!/bin/sh
# R191: Android "handset-mic" path (vendor mixer_paths_qrd.xml) on the upstream WCD938x/TX macro.
c() { amixer -q -c0 cset name="$1" "$2" || echo "mixer: '$1' = '$2' failed"; }
c 'TX DEC0 MUX' SWR_MIC; c 'TX SMIC MUX0' ADC3; c 'TX_AIF1_CAP Mixer DEC0' 1; c 'TX0 MODE' ADC_HIFI
c 'TX DEC1 MUX' SWR_MIC; c 'TX SMIC MUX1' ADC0; c 'TX_AIF1_CAP Mixer DEC1' 1; c 'TX3 MODE' ADC_HIFI
c 'ADC1_MIXER Switch' 1; c 'ADC4_MIXER Switch' 1; c 'ADC4 MUX' INP5
c 'ADC1 Switch' 1; c 'ADC4 Switch' 1; c 'ADC1 Volume' 6; c 'ADC4 Volume' 6
c 'MultiMedia2 Mixer TX_CODEC_DMA_TX_3' 1
