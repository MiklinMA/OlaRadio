import os
import sys
import threading
from queue import Queue
from random import random

import pygame

from api import API


cache = os.getenv('YANDEX_MUSIC_CACHE', os.getenv('TMPDIR'))
assert cache


def main_loop():
    current_track = None

    def generate_play_id():
        return "%s-%s-%s" % (int(random() * 1000), int(random() * 1000), int(random() * 1000))

    while True:
        tracks = API.get_tracks(current_track)

        # DEBUG
        print("Tracks:")
        for track in tracks:
            _, title, _ = get_info(track)
            print(title)
        print("====================")

        if current_track is None:
            API.radio_started()
            current_track = tracks.pop(0)
            current_track.play_id = generate_play_id()
            download(current_track)

        for track in tracks:
            track.play_id = generate_play_id()

            API.track_start(current_track)

            t = threading.Thread(target=download, args=[track])
            t.daemon = True
            t.start()

            yield current_track

            API.track_finish(current_track)

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
        raise API.YandeMusicError('Unavailable bitrate')

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

    for track in main_loop():
        if not p.play(track):
            break


if __name__ == '__main__':
    serve()
