/* R160 diagnostic: drive one ALSA PCM through open / hw_params / prepare / start
 * as separate steps, logging a marker to /dev/kmsg and pausing between them.
 * Plays zeros only. Usage: pcm-steps /dev/snd/pcmC0D0p [pause_s] */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sound/asound.h>

static int kfd = -1;
static unsigned pause_s = 3;

static void mark(const char *s)
{
	char b[160];
	int n = snprintf(b, sizeof(b), "== PCMSTEP %s\n", s);
	if (kfd >= 0) write(kfd, b, n);
	printf("%s", b + 3); fflush(stdout);
	sleep(pause_s);
}

static void mask_set(struct snd_pcm_hw_params *p, int par, unsigned v)
{
	struct snd_mask *m = &p->masks[par - SNDRV_PCM_HW_PARAM_FIRST_MASK];
	memset(m, 0, sizeof(*m));
	m->bits[v >> 5] |= 1u << (v & 31);
}

static void iv_set(struct snd_pcm_hw_params *p, int par, unsigned min, unsigned max)
{
	struct snd_interval *i = &p->intervals[par - SNDRV_PCM_HW_PARAM_FIRST_INTERVAL];
	memset(i, 0, sizeof(*i));
	i->min = min; i->max = max; i->integer = 1;
}

int main(int argc, char **argv)
{
	struct snd_pcm_hw_params hp;
	struct snd_xferi x;
	static short buf[48000 * 2];
	int fd, r, i;

	if (argc < 2) return 2;
	if (argc > 2) pause_s = atoi(argv[2]);
	kfd = open("/dev/kmsg", O_WRONLY);

	mark("A open");
	fd = open(argv[1], O_RDWR);
	printf("open fd=%d\n", fd); if (fd < 0) { perror("open"); return 1; }

	memset(&hp, 0, sizeof(hp));
	for (i = 0; i <= SNDRV_PCM_HW_PARAM_LAST_MASK - SNDRV_PCM_HW_PARAM_FIRST_MASK; i++)
		memset(&hp.masks[i], 0xff, sizeof(hp.masks[i]));
	for (i = 0; i <= SNDRV_PCM_HW_PARAM_LAST_INTERVAL - SNDRV_PCM_HW_PARAM_FIRST_INTERVAL; i++) {
		hp.intervals[i].min = 0; hp.intervals[i].max = ~0u;
	}
	hp.rmask = ~0u;
	mask_set(&hp, SNDRV_PCM_HW_PARAM_ACCESS, SNDRV_PCM_ACCESS_RW_INTERLEAVED);
	mask_set(&hp, SNDRV_PCM_HW_PARAM_FORMAT, SNDRV_PCM_FORMAT_S16_LE);
	mask_set(&hp, SNDRV_PCM_HW_PARAM_SUBFORMAT, SNDRV_PCM_SUBFORMAT_STD);
	iv_set(&hp, SNDRV_PCM_HW_PARAM_CHANNELS, 2, 2);
	iv_set(&hp, SNDRV_PCM_HW_PARAM_RATE, 48000, 48000);
	iv_set(&hp, SNDRV_PCM_HW_PARAM_PERIOD_SIZE, 960, 960);
	iv_set(&hp, SNDRV_PCM_HW_PARAM_PERIODS, 4, 4);

	mark("B hw_params");
	r = ioctl(fd, SNDRV_PCM_IOCTL_HW_PARAMS, &hp);
	printf("hw_params r=%d\n", r); if (r) { perror("hw_params"); return 1; }

	mark("C prepare");
	r = ioctl(fd, SNDRV_PCM_IOCTL_PREPARE);
	printf("prepare r=%d\n", r); if (r) { perror("prepare"); return 1; }

	mark("D write (start)");
	memset(buf, 0, sizeof(buf));
	x.buf = buf; x.frames = 3840; x.result = 0;
	r = ioctl(fd, SNDRV_PCM_IOCTL_WRITEI_FRAMES, &x);
	printf("write r=%d frames=%ld\n", r, (long)x.result);

	mark("E drop");
	r = ioctl(fd, SNDRV_PCM_IOCTL_DROP);
	printf("drop r=%d\n", r);
	mark("F close");
	close(fd);
	mark("G done");
	return 0;
}
