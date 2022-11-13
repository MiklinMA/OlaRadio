import sys
import threading
from queue import Queue

import pygame


class Player:
    def __init__(self) -> None:
        pygame.mixer.init()
        self.track = None
        self.exit = False
        self.cmds = dict(
            pause=self.pause, p=self.pause,
            unpause=self.unpause, u=self.unpause,
            stop=self.stop, s=self.stop,
            next=self.next, n=self.next,
            like=self.like, l=self.like,
            dislike=self.dislike, d=self.dislike,
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

        def get_cmd():
            cmd = ""
            while not self.iq.empty():
                cmd += self.iq.get()
            return cmd.replace('\n', '')

        print(f"\n{track.name}\n--------\n{track.lyrics or 'No lyrics...'}\n")
        pygame.mixer.music.load(track.path)
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

        if self.track.position == 0:
            self.track.position = self.track.duration

        self.track = None
        self.playing = lambda: False
        print()

        return not self.exit

    @property
    def position(self):
        return int(pygame.mixer.music.get_pos() / 1000)

    def pause(self):
        self.playing = lambda: self.track is not None
        pygame.mixer.music.pause()

    def unpause(self):
        self.playing = lambda: pygame.mixer.music.get_busy()
        pygame.mixer.music.unpause()

    def stop(self):
        self.exit = True
        pygame.mixer.music.stop()

    def next(self):
        self.track.position = self.position
        self.track.skip()
        pygame.mixer.music.stop()

    def like(self):
        self.track.like()

    def dislike(self):
        self.track.position = self.position
        self.track.dislike()
        pygame.mixer.music.stop()
