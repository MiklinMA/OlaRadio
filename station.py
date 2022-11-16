import threading

from client import Client
from track import Track


class Station:
    def __init__(self, token, station_id=None):
        self.client = Client(token, station_id)
        self.id = station_id or 'user:onyourwave'

        self.station = None
        self.current_track = None
        self.next_track = None

    @property
    def tracks(self):
        while True:
            tracks = self.client.get_station_tracks(
                self.current_track.id
                if self.current_track else None
            )

            if self.current_track is None:
                self.client.event_radio_started()

                self.current_track = Track(tracks.pop(0), self)
                self.current_track.download()

            for track in tracks:
                self.next_track = Track(track, self)
                self.event_track_trace(self.current_track)
                self.client.event_track_started(self.current_track.id)

                t = threading.Thread(target=self.next_track.download)
                t.daemon = True
                t.start()

                yield self.current_track

                self.event_track_trace(self.current_track)
                self.client.event_track_finished(
                    self.current_track.id,
                    self.current_track.duration,
                )

                t.join()

                self.current_track = self.next_track

    def event_track_trace(self, track=None):
        track = track or self.current_track
        self.client.event_play_audio(
            track.id,
            track.cached,
            track.play_id,
            track.duration,
            track.position,
            track.album_id,
        )
        print("Trace:", track.position, '/', track.duration)

    def event_track_skip(self, track=None):
        track = track or self.current_track
        self.client.event_track_skip(
            self.current_track.id,
            self.current_track.position,
        )

    def event_track_like(self, track=None):
        track = track or self.current_track
        self.client.event_like(track.id)

    def event_track_dislike(self, track=None):
        track = track or self.current_track
        self.client.event_dislike(track.id)
