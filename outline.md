
- Intro
  - What have I done?
  - Why did I do it?
  - What did I use to do it?
    - Video4Linux2
      - /dev/video0
      - Configuring device with v4l2-ctl
    - FFmpeg
      - Recording from a Microphone, Screen, Camera
      - Container for codec copy
      - Transcoding the streams
    - MLT
      - frei0r.alphagrad filter
    - Bash

- Demonstrate the process being replaced
  - Record the screen and microphone with Vokoscreen
  - Record the camera and microphone with guvcview
  - Import both clips into kdenlive
  - Set audio reference
  - Align audio to reference
  - Trim videos
  - Apply Alpha Linear Gradient filter to camera
  - Render


# Recording a Microphone on Linux using FFmpeg (via PulseAudio)

PulseAudio is a layer that sits in between your applications and your audio drivers.
It can be thought of as like a digital switchboard for all the audio streams going
through your system and provides a means of managing which application's audio is
being routed to which cards. Beyond that It can be used to split and remap channels
in audio streams, say 7.1 to 5.1 surround or vice-versa, you could use it to send
audio over a network, or even just something as simple as allowing two applications
to use the same device at the same time. It comes as standard on most desktop linux
distributions these days so it's pretty likely you'll encounter it at some point.

As PulseAudio is a Client/Server architecture, there are a number of different tools
and libraries that could be used to interact with it. For this demonstration I will
be using `pactl`, which is the shell client that's bundled with the server and used
to configure it. As an aside, I use pavucontrol as a GUI client to PulseAudio since
managing volume levels is definitely nicer with a slider.

One such client for PulseAudio is FFmpeg's "pulse" input device. Now don't let the
terminology fool you here, in this case it's a _virtual device_ rather than a piece
of hardware in your computer, though that is also certainly an option.

In most cases the simplest incantation for "Record Microphone" is unplug-and-replug
the desired microphone and speak unto the shell:

```
$ ffmpeg -f pulse -i default output.wav
```

Now while that will probably work most of the time, I didn't use the word
"incantation" for nothing. The only reason that is likely to work is because of
Pulse's switch-on-connect module whereby the default device tracks the most recently
identified device. This is on by default in many desktop linux distributions.

When we reconnect the microphone, we're not only relying on the switch-on-connect
module being present and enabled, we're also assuming that no other client has
connected and changed the default device while we weren't looking. It's entirely
possible. So all in all it's better to be specific.

All we need to do is replace "default" with an actual device name, which can be found
with the following command:

```
$ pactl list sources
... snip ...
Source #3
        State: SUSPENDED
        Name: alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo
        Description: PCM2902 Audio Codec Analogue Stereo
        Driver: module-alsa-card.c
        Sample Specification: s16le 2ch 44100Hz
        Channel Map: front-left,front-right
        Owner Module: 25
        Mute: no
        Volume: front-left: 65536 / 100% / 0.00 dB,   front-right: 65536 / 100% / 0.00 dB
                balance 0.00
        Base Volume: 65536 / 100% / 0.00 dB
        Monitor of Sink: n/a
        Latency: 0 usec, configured 0 usec
        Flags: HARDWARE DECIBEL_VOLUME LATENCY
        Properties:
                alsa.resolution_bits = "16"
                device.api = "alsa"
                device.class = "sound"
                alsa.class = "generic"
                alsa.subclass = "generic-mix"
                alsa.name = "USB Audio"
                alsa.id = "USB Audio"
                alsa.subdevice = "0"
                alsa.subdevice_name = "subdevice #0"
                alsa.device = "0"
                alsa.card = "1"
                alsa.card_name = "USB Audio CODEC"
                alsa.long_card_name = "Burr-Brown from TI USB Audio CODEC at usb-0000:00:14.0-1, full speed"
                alsa.driver_name = "snd_usb_audio"
                device.bus_path = "pci-0000:00:14.0-usb-0:1:1.0"
                sysfs.path = "/devices/pci0000:00/0000:00:14.0/usb1/1-1/1-1:1.0/sound/card1"
                udev.id = "usb-Burr-Brown_from_TI_USB_Audio_CODEC-00"
                device.bus = "usb"
                device.vendor.id = "08bb"
                device.vendor.name = "Texas Instruments"
                device.product.id = "2902"
                device.product.name = "PCM2902 Audio Codec"
                device.serial = "Burr-Brown_from_TI_USB_Audio_CODEC"
                device.string = "front:1"
                device.buffering.buffer_size = "352800"
                device.buffering.fragment_size = "176400"
                device.access_mode = "mmap+timer"
                device.profile.name = "analog-stereo"
                device.profile.description = "Analogue Stereo"
                device.description = "PCM2902 Audio Codec Analogue Stereo"
                alsa.mixer_name = "USB Mixer"
                alsa.components = "USB08bb:2902"
                module-udev-detect.discovered = "1"
                device.icon_name = "audio-card-usb"
        Ports:
                analog-input: Analogue Input (priority: 10000)
        Active Port: analog-input
        Formats:
                pcm
```

As you can see, that command produces a lot of detailed output about each source,
which is very interesting and worth a look, but in this instance we can get a much
more succinct output with:

```
$ pactl list short sources | column -t
0  alsa_output.pci-0000_00_1f.3.analog-stereo.monitor                           module-alsa-card.c  s16le  2ch  44100Hz  SUSPENDED
1  alsa_input.pci-0000_00_1f.3.analog-stereo                                    module-alsa-card.c  s16le  2ch  44100Hz  SUSPENDED
2  alsa_output.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo.monitor  module-alsa-card.c  s16le  2ch  44100Hz  IDLE
3  alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo           module-alsa-card.c  s16le  2ch  44100Hz  SUSPENDED
```

That command will output only one line per source with the source ID, name, what
PulseAudio module is handling it, audio format, the number of channels, the sample
rate, and the source's current status. Piping the output to `column -t` isn't strictly
necessary, but it does tidy up the output a bit by aligning the columns.

PulseAudio sources are typically either actual audio inputs, or they're monitors of
your outputs. Either way, a stream can be read from them and they can be used to
record from.

Now thankfully these names will remain consistent across reboots, so we don't have to
query PulseAudio every time we want to record the microphone, we can just hard-code
that in if we wish, which in this case I will. The input I want to record from is

```
alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo
```

So our record command now looks like:

```
$ ffmpeg \
    -f pulse \
    -i alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo \
    output.wav
```

You can of course choose to transcode the audio at this point if you wish by adding a `-codec:a`
parameter and altering the output file name, like so:

```
$ ffmpeg \
    -f pulse i \
    -i alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo \
    -codec:a aac \
    output.m4a
```

Personally, I prefer to record raw, then transcode later as it minimises any background fan noise
as I'm recording.

# Recording the Screen on Linux using FFmpeg (record X11 display)

At the time of writing, the predominent windowing/display system for linux and most
unixes is X11.  X11 is another client-server architecture, whereby your computer with
it's graphics hardware is the server and each application that wants to draw a window
onto the screen is a client that connects to the server and instructs it on how to draw
what it wants. The drawable space available is what X calls the display, and typically
that display is ":0". If you have more than one physical monitor, then that
display is all of them together.

FFmpeg has an X11 client module called x11grab that we can use to connect to our X
server and request frames from it.

[Invert monitors so that this records blackness]

```
$ ffmpeg -f x11grab -i :0 -codec copy output.nut
```

So that didn't work. We got a tiny little blank video. The problem here is that your
left monitor is smaller than your right one and they're aligned at the bottom. If I flip
my monitors back around again and re-run that command we can see that it is indeed
recording the screen.

The reason for this is because the screen is a virtual box around all your monitors, and
there's some dead space in the top left corner.

Unfortunately however this appears to only be recording a tiny little postage stamp
sized bit of the screen from somewhere in the top left. Proving once again that relying
on the defaults can often yeild unexpected results.

In order to set the size that we want to grab, we configure the input with the
`-video_size 1920x1080` arguments.

```
$ ffmpeg \
  -f x11grab -video_size "${w}x${h}" -i ":0" \
  -codec copy output.nut
```

The video is still offset from the top left corner and so everything is shifted over
however. This just means that we need to be explicit about where we want the origin to
be, and that's part of the input specifier.

```
$ ffmpeg \
  -f x11grab -video_size "${w}x${h}" -i ":0+0,0" \
  -codec copy output.nut
```

By adding the `+0,0` we just reset the origin point to the very top leftmost point on
the screen. Depending on your monitor configuration, that might be enough. If you want
to record the top leftmost 1080 monitor, then that'll do, but we can do better.

Instead, let's pick a monitor to record and be very explicit about it's size and
position when we record it. That way, if we change the resolution of the monitor, our
recordings will match, if we move the monitor to the other side of the desk, the
recorder will still find it.

We can find our monitor's geometry using the xrandr command. Xrandr will list out all
the display outputs on your system, including some that your chipset has, but your OEM
hasn't brought out to actual sockets. It will show you the connected/disconnected status
what the current modes are for your monitors along with a list of what modes they
support.

The following command will list out all our connected displays and their geometries.

```
$ xrandr | sed -n '/ connected/p'
eDP-1 connected primary 2560x1440+3840+720 (normal left inverted right x axis y axis) 344mm x 194mm
DP-3 connected 3840x2160+0+0 (normal left inverted right x axis y axis) 621mm x 341mm
```

The bit we're interested in is the `2560x1440+3840+720` part. The first part of this is
the resolution in `WIDTHxHEIGHT` format, the origin offset is the `+XPOSITION+YPOSITION`
part. This geometry is the only bit we're interested in so let's just extract that part.

```
$ xrandr | sed -nr '/ connected/s/.* ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+) .*/\1 \2 \3 \4/p'
2560 1440 3840 720
3840 2160 0 0
```

We now have all our display geometries but since we only wanted one, so let's just add
the output name into the regex.

```
$ xrandr | sed -nr '/DP-3 connected/s/.* ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+) .*/\1 \2 \3 \4/p'
3840 2160 0 0
```

Those values can now easily be read into Bash variables using the `read` command.

```
$ read width height xposition yposition < <(
  xrandr | sed -nr '/DP-3 connected/s/.* ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+) .*/\1 \2 \3 \4/p'
)
$ echo "Resolution: ${width}x${height} Position: ${xposition}x${yposition}"
Resolution: 3840x2160 Position: 0x0
```

Once we have those values in variables, putting them into the original command is pretty
trivial.

```
$ ffmpeg \
  -f x11grab -video_size "${width}x${height}" -i ":0+${xposition},${yposition}" \
  -codec copy output.nut
```

And all together...

```
$ read width height xposition yposition < <(
  xrandr | sed -nr '/DP-3 connected/s/.* ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+) .*/\1 \2 \3 \4/p'
)
$ ffmpeg \
  -f x11grab -video_size "${width}x${height}" -i ":0+${xposition},${yposition}" \
  -codec copy output.nut
```

I'll stop short of trying to make this a "one-liner" since it would conflate getting the
output geometry with the construction of the ffmpeg command. It can be done, but it
wouldn't be pretty and would only serve to confuse.

Before I wrap this up, let's quickly address the elephant in the room. What on earth is a
NUT file? Personally, I rather like the Matroska container format, it's very accomodating
and can be read while it's being written, which is the killer feature over mp4 containers
for me. Unfortunately, as accomodating as Matroska is, it doesn't like the BGR pixel
format that `x11grab` returns.

For every pixel there is a Red value, a Blue value, and a Green value and they appear in a
particular order depending on the format. Some formats will be RGB, some are BGR and that
is only the tip of an iceberg that I'm not going to get into here.

NUT is a container format developed by the FFmpeg and Mplayer teams and is _even more_
accomodating than Matroska, though maybe not as widely supported. NUT is happy to accept
the raw frames from x11 with their BRG pixel format.

# Recording a Webcam on Linux using FFmpeg (Video4Linux2)
  - ffmpeg -f v4l2 -i /dev/video0 -codec copy output.mkv
    - Here we specify a particular device using it's /dev/ file.
    - Why is the quality shit?
    - Find out what your camera's capabilities are
      - ffmpeg -f v4l2 -list_formats all -i /dev/video0
      - v4l2-ctl -d /dev/video0 --list-formats-ext
        - Seemingly undocumented?? Not quite. look in v4l2-ctl --help-all
      - uvcdynctrl -d /dev/video0 -f
    - Specify video size and format to use
        - ffmpeg -f v3l2 -video_size 1920x1080 -input_format mjpeg -i /dev/video0 output.mkv

  - The problem with capturing everything individually is that we need to align the videos
    with each other. This can be done in kdenlive, but I have yet to figure how to do it
    at the command line.

# Recording Multiple Streams from Different Sources on Linux with FFmpeg
  - Avoiding the video/audio sync up by recording everything simultaniously into a single container
  - Mapping streams in an output container with FFmpeg
  - Why does the camera lag behind so badly?
    - Video4Linux/UVC latency of about 0.4s opening the device
    - Hold back other streams.
    - Feels clunky, but it's an imperfect world and sometimes we need to compensate for that.

- Configuring a Webcam on Linux (Video4Linux2 60Hz/50Hz)
  - Strobing, 50/60Hz
  - v4l2-ctl -d /dev/videoX -L
  -                         -C key
  -                         -c key=val
  - Demo ffmpeg and v4l2-ctl together

- How can we do the Gradient Overlay programatically?
  - Two MLT Producers
  - frei0r.alphagrad

- MLT 3for1 Preview/Play(/Render)
  - Preview, Camera from v4l, screen from X. no audio
  - Play, Camera from file stream, screen from file stream, audio from file
  - Render, same as play but the consumer is an avformat file

