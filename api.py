import os
import threading

import yandex_music

from track import Track

token = os.getenv('YANDEX_MUSIC_TOKEN')
assert token, "TOKEN NOT FOUND"

station_id = "user:onyourwave"
ui_string = "desktop_win-home-playlist_of_the_day-playlist-default"


class API:
    client = yandex_music.Client(token).init()

    def __init__(self, station_id='user:onyourwave'):
        self.station_id = station_id
        self.station = None
        self.current_track = None
        self.next_track = None

    @property
    def tracks(self):
        while True:
            self.station = self.client.rotor_station_tracks(self.station_id, **(
                {'queue': self.current_track.track.track_id}
                if self.current_track else {}
            ))

            tracks = self.client.tracks([t.track.track_id for t in self.station.sequence])

            if self.current_track is None:
                self.__event_radio_started()

                self.current_track = Track(tracks.pop(0))
                self.current_track.download()

            for track in tracks:
                self.next_track = Track(track)
                self.__event_track_start()

                t = threading.Thread(target=self.next_track.download)
                t.daemon = True
                t.start()

                yield self.current_track

                self.__event_track_finish()

                t.join()

                self.current_track = self.next_track

    def __event_radio_started(self):
        self.client.rotor_station_feedback_radio_started(
            station=self.station_id,
            from_=self.station_id.replace(':', '-'),
            batch_id=self.station.batch_id
        )

    def __event_track_start(self):
        self.client.play_audio(
            from_=ui_string,
            track_id=self.current_track.id,
            album_id=self.current_track.album_id,
            play_id=self.current_track.play_id,
            track_length_seconds=self.current_track.duration,
            total_played_seconds=self.current_track.position,
            end_position_seconds=self.current_track.position,
        )
        self.client.rotor_station_feedback_track_started(
            station=self.station_id,
            track_id=self.current_track.id,
            batch_id=self.station.batch_id
        )

    def __event_track_finish(self):
        self.client.play_audio(
            from_=ui_string,
            track_id=self.current_track.id,
            album_id=self.current_track.album_id,
            play_id=self.current_track.play_id,
            track_length_seconds=self.current_track.duration,
            total_played_seconds=self.current_track.position,  # ZERO
            end_position_seconds=self.current_track.position,
        )
        if self.current_track.position:
            self.client.rotor_station_feedback_skip(
                station=self.station_id,
                track_id=self.current_track.id,
                total_played_seconds=self.current_track.position,
                batch_id=self.station.batch_id,
            )

        self.client.rotor_station_feedback_track_finished(
            station=self.station_id,
            track_id=self.current_track.id,
            batch_id=self.station.batch_id,
            total_played_seconds=self.current_track.duration,
        )
