import os
from random import random
import urllib.request

from mutagen import id3

cache = os.getenv('YANDEX_MUSIC_CACHE', os.getenv('TMPDIR'))
assert cache

class Track:
    class Error(Exception):
        ...

    def __init__(self, track, station):
        self.station = station
        self.track = track
        self.id = track.id
        self.album_id = track.albums[0].id
        self.play_id = "%s-%s-%s" % (
            int(random() * 1000),
            int(random() * 1000),
            int(random() * 1000)
        )
        self.duration = int(self.track.duration_ms / 1000)
        self.position = 0

        self.artist = track.artists[0].name
        self.artists = " feat. ".join([a.name for a in track.artists])
        self.title = f"{self.artist} - {track.title}".replace("/", "")
        self.path = f'{cache}/{self.title}.mp3'
        self._lyrics = None

    @property
    def lyrics(self):
        if not self._lyrics:
            sup = self.track.get_supplement()
            if sup.lyrics:
                self._lyrics = sup.lyrics.full_lyrics

        return self._lyrics

    @property
    def exists(self):
        return os.path.exists(self.path)

    def download(self):
        if not self.exists:
            print(f'Downloading {self.title}...')
            os.makedirs("/".join(self.path.split("/")[:-1]), exist_ok=True)

            dis = self.track.download_info or self.track.get_download_info()

            br = 0
            info = None

            for di in dis:
                if di.codec == 'mp3':
                    if di.bitrate_in_kbps > br:
                        info = di

            if not info:
                raise Track.Error(f'Download info unavailable for {self.title}')

            info.download(self.path)

        self.__reload_tags()

    def trace(self):
        self.station.event_track_trace(self)

    def skip(self):
        self.station.event_track_skip(self)

    def like(self):
        self.station.event_track_like(self)

    def dislike(self):
        self.station.event_track_dislike(self)
        if self.exists:
            os.remove(self.path)

    def __reload_tags(self):
        if not self.exists:
            return
        try:
            tags = id3.ID3(self.path)
        except id3.ID3NoHeaderError:
            tags = id3.ID3()

        changed = False

        if not tags.get('TIT2'):
            tags.add(id3.TIT2(encoding=3, text=self.track.title))
            tags.add(id3.TALB(encoding=3, text=self.track.albums[0].title))
            tags.add(id3.TPE1(encoding=3, text=self.artist))
            changed = True

        lyrics = tags.get('USLT::eng')
        if lyrics is not None:
            self._lyrics = lyrics.text
        elif self.lyrics is not None:
            tags.add(id3.USLT(encoding=3, lang='eng', text=self.lyrics))
            changed = True

        if not tags.get('APIC'):
            art = urllib.request.urlopen(
                f'https://{self.track.cover_uri.replace("%%", "200x200")}'
            )
            tags.add(id3.APIC(
                encoding=0,
                mime=art.headers['Content-Type'],
                type=3,  # cover front
                data=art.read(),
            ))
            changed = True

        if changed:
            tags.save(self.path)
