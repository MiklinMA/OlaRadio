import os
from random import random
import urllib.request

from mutagen import id3

cache = os.getenv('YANDEX_MUSIC_CACHE', os.getenv('TMPDIR'))
assert cache, 'CACHE DIR NOT DEFINED'

class Track:
    def __init__(self, track, station):
        self.station = station
        self.id = track['id']
        self.album_id = track['albums'][0]['id']
        self.play_id = "%s-%s-%s" % (
            int(random() * 1000),
            int(random() * 1000),
            int(random() * 1000)
        )
        self.duration = int(track['durationMs'] / 1000)
        self.position = 0

        self.artist = track['artists'][0]['name']
        self.album = track['albums'][0]['title']
        self.title = track['title']

        self.name = f"{self.artist} - {self.title}".replace("/", "")
        self.path = f'{cache}/{self.name}.mp3'

        self._lyrics = None
        self._lyrics_available = track['lyricsAvailable']

        self.cached = self.exists
        self.artwork = f'https://{track["coverUri"].replace("%%", "200x200")}'

        self.artists = " feat. ".join([a['name'] for a in track['artists']])

    @property
    def lyrics(self):
        if not self._lyrics:
            if self._lyrics_available:
                self._lyrics = self.station.client.get_lyrics(self.id)

        return self._lyrics

    @property
    def exists(self):
        return os.path.exists(self.path)

    def download(self):
        if not self.exists:
            print(f'Downloading {self.name}...')
            os.makedirs("/".join(self.path.split("/")[:-1]), exist_ok=True)
            self.station.client.download(self.id, self.path)

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
            tags.add(id3.TIT2(encoding=3, text=self.title))
            tags.add(id3.TALB(encoding=3, text=self.album))
            tags.add(id3.TPE1(encoding=3, text=self.artist))
            print("Title changed")
            changed = True

        if tags.get('USLT::eng'):
            self._lyrics = tags['USLT::eng'].text
        elif self.lyrics is not None:
            tags.add(id3.USLT(encoding=3, lang='eng', text=self.lyrics))
            print("Lyrics changed")
            changed = True

        if not tags.get('APIC'):
            art = urllib.request.urlopen(self.artwork)
            tags.add(id3.APIC(
                encoding=0,
                mime=art.headers['Content-Type'],
                type=3,  # cover front
                data=art.read(),
            ))
            print("Artwork changed")
            changed = True

        if changed:
            tags.save(self.path)
