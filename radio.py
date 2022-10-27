import os
import sys
import threading
from queue import Queue

from yandex_music import Client
import pygame

token = os.getenv('YANDEX_MUSIC_TOKEN')
cache = os.getenv('YANDEX_MUSIC_CACHE', os.getenv('TMPDIR'))
player = os.getenv('YANDEX_MUSIC_PLAYER', "vlc --play-and-exit -I dummy")
assert token
assert cache

player = player.split(' ')

client = Client(token).init()
station = "user:onyourwave"

def get_track():
    while True:
        tracks = client.rotor_station_tracks(station).sequence
        print("Tracks:")
        for x in tracks:
            _, title, _ = get_info(x.track)
            print(title)
        print("====================")

        first = tracks.pop(0)
        track = first.track
        download(track)

        for x in tracks:
            t = threading.Thread(target=download, args=[x.track])
            t.daemon = True
            t.start()
            yield track
            t.join()
            track = x.track

        yield track

def get_info(track):
    artist = " feat. ".join([a.name for a in track.artists])
    title = f"{artist} - {track.title}".replace("/", "")
    path = f'{cache}/{title}.mp3'
    lyrics = 'No lyrics...'

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
    track.download(path)

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

        path, title, lyrics = get_info(self.track)

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

        client.rotor_station_feedback_track_started(station, track.id)
        print('> ', end='', flush=True)

        while self.playing():
            cmd = get_cmd()
            if cmd in self.cmds:
                self.cmds[cmd]()
                print('> ', end='', flush=True)

            pygame.time.Clock().tick(10)

        if self.track:
            client.rotor_station_feedback_track_finished(
                station,
                self.track.id,
                int(self.track.duration_ms / 1000)
            )
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

        client.rotor_station_feedback_skip(
            station,
            self.track.id,
            int(pygame.mixer.music.get_pos() / 1000),
        )

        self.track = None
        pygame.mixer.music.stop()

def serve():
    p = Player()

    for track in get_track():
        if not p.play(track):
            break

if __name__ == '__main__':
    serve()
