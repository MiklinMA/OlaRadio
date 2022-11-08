import os
from random import random

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

    def download(self):
        if os.path.exists(self.path):
            return

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

    def trace(self):
        self.station.event_track_trace(self)

    def skip(self):
        self.station.event_track_skip(self)
