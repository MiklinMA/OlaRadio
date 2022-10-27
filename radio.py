import os
import sys
import threading
from queue import Queue
from random import random

import yandex_music
import pygame

token = os.getenv('YANDEX_MUSIC_TOKEN')
cache = os.getenv('YANDEX_MUSIC_CACHE', os.getenv('TMPDIR'))
player = os.getenv('YANDEX_MUSIC_PLAYER', "vlc --play-and-exit -I dummy")
assert token
assert cache

player = player.split(' ')

client = yandex_music.Client(token).init()
ui_string = "desktop_win-home-playlist_of_the_day-playlist-default"
station_id = "user:onyourwave"


class TaskQueue:
    def __init__(self):
        self.__queue = []
        self.__in_progress = False

    def addTask(self, name, function, kwargs):
        self.__queue.append((name, function, kwargs))
        self.__do_next()

    def __do_next(self):
        if self.__in_progress:
            return
        if not self.__queue:
            return
        self.__in_progress = True
        args = self.__queue.pop(0)
        threading.Thread(target=self.__process, args=args).start()

    def __process(self, name, function, kwargs):
        function(**kwargs)
        self.__in_progress = False
        self.__do_next()

def generate_play_id():
    return "%s-%s-%s" % (int(random() * 1000), int(random() * 1000), int(random() * 1000))

class API:
    def radio_started(station):
        client.rotor_station_feedback_radio_started(
            station=station.station_id,
            from_=station.station_id.replace(':', '-'),
            batch_id=station.batch_id
        )

    def track_start(station, track):
        client.play_audio(
            from_=ui_string,
            track_id=track.id,
            album_id=track.albums[0].id,
            play_id=track.play_id,
            track_length_seconds=int(track.duration_ms / 1000),
            total_played_seconds=0,
            end_position_seconds=0,
        )
        client.rotor_station_feedback_track_started(
            station=station.station_id,
            track_id=track.id,
            batch_id=station.batch_id
        )

    def track_finish(station, track):
        duration = int(track.duration_ms / 1000)
        position = getattr(track, 'skip_position', duration)
        client.play_audio(
            from_=ui_string,
            track_id=track.id,
            album_id=track.albums[0].id,
            play_id=track.play_id,
            track_length_seconds=duration,
            total_played_seconds=position,
            end_position_seconds=position,
        )
        if getattr(track, 'skip_position', None):
            client.rotor_station_feedback_skip(
                station=station.station_id,
                track_id=track.id,
                total_played_seconds=position,
                batch_id=station.batch_id,
            )

        client.rotor_station_feedback_track_finished(
            station=station.station_id,
            track_id=track.id,
            batch_id=station.batch_id,
            total_played_seconds=duration,
        )


def get_track():
    current_track = None

    while True:
        kwargs = dict()
        if current_track:
            kwargs['queue'] = current_track.track_id

        station = client.rotor_station_tracks(station_id, **kwargs)

        station.station_id = station_id
        tracks = client.tracks([t.track.track_id for t in station.sequence])

        # DEBUG
        print("Tracks:")
        for track in tracks:
            _, title, _ = get_info(track)
            print(title)
        print("====================")

        if current_track is None:
            API.radio_started(station)
            current_track = tracks.pop(0)
            current_track.play_id = generate_play_id()
            download(current_track)

        for track in tracks:
            track.play_id = generate_play_id()

            API.track_start(station, current_track)

            t = threading.Thread(target=download, args=[track])
            t.daemon = True
            t.start()

            yield current_track

            API.track_finish(station, current_track)

            t.join()

            current_track = track


def get_info(track, with_lyrics=False):
    artist = " feat. ".join([a.name for a in track.artists])
    title = f"{artist} - {track.title}".replace("/", "")
    path = f'{cache}/{title}.mp3'
    lyrics = 'No lyrics...'

    if with_lyrics:
        sup = track.get_supplement()
        if sup.lyrics:
            lyrics = sup.lyrics.full_lyrics

    return path, title, lyrics

def download(track):
    path, title, _ = get_info(track)

    if os.path.exists(path):
        return

    print(f'Downloading {title}...')
    os.makedirs("/".join(path.split("/")[:-1]), exist_ok=True)

    dis = track.download_info or track.get_download_info()

    br = 0
    info = None

    for di in dis:
        if di.codec != 'mp3':
            continue
        if di.bitrate_in_kbps > br:
            info = di
    if not info:
        raise yandex_music.exceptions.InvalidBitrateError('Unavailable bitrate')

    info.download(path)

class Player:
    def __init__(self) -> None:
        pygame.mixer.init()
        self.track = None
        self.exit = False
        self.cmds = dict(
            pause=self.pause,
            unpause=self.unpause,
            stop=self.stop,
            next=self.next,
        )
        self.iq = Queue()
        self.th = threading.Thread(target=self.getc)
        self.th.daemon = True

    def getc(self):
        while self.playing():
            self.iq.put(sys.stdin.read(1))

    def play(self, track):
        self.track = track
        self.playing = lambda: False

        path, title, lyrics = get_info(self.track, with_lyrics=True)

        def get_cmd():
            cmd = ""
            while not self.iq.empty():
                cmd += self.iq.get()
            return cmd.replace('\n', '')

        print(f"{title}\n--------\n{lyrics}")
        pygame.mixer.music.load(path)
        pygame.mixer.music.play()
        self.playing = lambda: pygame.mixer.music.get_busy()

        if not self.th.is_alive():
            self.th.start()

        print('> ', end='', flush=True)

        while self.playing():
            cmd = get_cmd()
            if cmd in self.cmds:
                self.cmds[cmd]()
                print('> ', end='', flush=True)

            pygame.time.Clock().tick(10)

        self.track = None
        self.playing = lambda: False
        print()

        return not self.exit

    def pause(self):
        if not self.track:
            return

        self.playing = lambda: self.track is not None
        pygame.mixer.music.pause()

    def unpause(self):
        self.playing = lambda: pygame.mixer.music.get_busy()
        pygame.mixer.music.unpause()

    def stop(self):
        self.track = None
        pygame.mixer.music.stop()
        self.exit = True
        # sys.stdin.flush()  # TODO: finish stdin.read somehow

    def next(self):
        self.track.skip_position = int(pygame.mixer.music.get_pos() / 1000)
        self.track = None
        pygame.mixer.music.stop()

def serve():
    p = Player()

    for track in get_track():
        if not p.play(track):
            break

if __name__ == '__main__':
    serve()
