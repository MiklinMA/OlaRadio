import os
import threading

import yandex_music

from track import Track


class Station:
    def __init__(self, token, station_id=None, ui_string=None):
        self.client = yandex_music.Client(token).init()
        self.id = station_id or 'user:onyourwave'
        self.ui_string = ui_string or "desktop_win-home-playlist_of_the_day-playlist-default"

        self.station = None
        self.current_track = None
        self.next_track = None

    @property
    def tracks(self):
        while True:
            self.station = self.client.rotor_station_tracks(self.id, **(
                {'queue': self.current_track.track.track_id}
                if self.current_track else {}
            ))

            tracks = self.client.tracks([t.track.track_id for t in self.station.sequence])

            if self.current_track is None:
                self.__event_radio_started()

                self.current_track = Track(tracks.pop(0), self)
                self.current_track.download()

            for track in tracks:
                self.next_track = Track(track, self)
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
            station=self.id,
            from_=self.id.replace(':', '-'),
            batch_id=self.station.batch_id
        )

    def __event_track_start(self):
        self.event_track_trace()

        self.client.rotor_station_feedback_track_started(
            station=self.id,
            track_id=self.current_track.id,
            batch_id=self.station.batch_id
        )

    def __event_track_finish(self):
        self.event_track_trace()

        self.client.rotor_station_feedback_track_finished(
            station=self.id,
            track_id=self.current_track.id,
            batch_id=self.station.batch_id,
            total_played_seconds=self.current_track.duration,
        )

    def event_track_trace(self, track=None):
        track = track or self.current_track
        self.client.play_audio(
            from_=self.ui_string,
            track_id=track.id,
            album_id=track.album_id,
            play_id=track.play_id,
            track_length_seconds=track.duration,
            total_played_seconds=track.position,
            end_position_seconds=track.position,
        )
        print("Trace:", track.position, '/', track.duration)

    def event_track_skip(self, track=None):
        track = track or self.current_track
        self.client.rotor_station_feedback_skip(
            station=self.id,
            track_id=track.id,
            total_played_seconds=track.position,
            batch_id=self.station.batch_id,
        )

    def event_track_like(self, track=None):
        track = track or self.current_track
        self.client.users_likes_tracks_add(track_id=track.id)

    def event_track_dislike(self, track=None):
        track = track or self.current_track
        self.client.users_dislikes_tracks_add(track_id=track.id)
