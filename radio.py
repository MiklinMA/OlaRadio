import os

from station import Station
from player.console import Player

if __name__ == '__main__':
    api = Station(
        token=os.getenv('YANDEX_MUSIC_TOKEN'),
        station_id='user:onyourwave',
    )
    player = Player()

    for track in api.tracks:
        if not player.play(track):
            break
