from api import API
from player.console import Player


if __name__ == '__main__':
    api = API('user:onyourwave')
    player = Player()

    for track in api.tracks:
        if not player.play(track):
            break
