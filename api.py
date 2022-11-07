import os
import yandex_music

token = os.getenv('YANDEX_MUSIC_TOKEN')
assert token, "TOKEN NOT FOUND"

station_id = "user:onyourwave"
ui_string = "desktop_win-home-playlist_of_the_day-playlist-default"

class API:
    client = yandex_music.Client(token).init()
    station = None

    class YandeMusicError(Exception):
        ...

    @classmethod
    def get_tracks(cls, current_track=None):
        kwargs = dict()
        if current_track:
            kwargs['queue'] = current_track.track_id

        cls.station = cls.client.rotor_station_tracks(station_id, **kwargs)
        cls.station.station_id = station_id
        tracks = cls.client.tracks([t.track.track_id for t in cls.station.sequence])
        return tracks

    @classmethod
    def radio_started(cls):
        cls.client.rotor_station_feedback_radio_started(
            station=cls.station.station_id,
            from_=cls.station.station_id.replace(':', '-'),
            batch_id=cls.station.batch_id
        )

    @classmethod
    def track_start(cls, track):
        cls.client.play_audio(
            from_=ui_string,
            track_id=track.id,
            album_id=track.albums[0].id,
            play_id=track.play_id,
            track_length_seconds=int(track.duration_ms / 1000),
            total_played_seconds=0,
            end_position_seconds=0,
        )
        cls.client.rotor_station_feedback_track_started(
            station=cls.station.station_id,
            track_id=track.id,
            batch_id=cls.station.batch_id
        )

    @classmethod
    def track_finish(cls, track):
        duration = int(track.duration_ms / 1000)
        position = getattr(track, 'skip_position', duration)
        cls.client.play_audio(
            from_=ui_string,
            track_id=track.id,
            album_id=track.albums[0].id,
            play_id=track.play_id,
            track_length_seconds=duration,
            total_played_seconds=position,
            end_position_seconds=position,
        )
        if getattr(track, 'skip_position', None):
            cls.client.rotor_station_feedback_skip(
                station=cls.station.station_id,
                track_id=track.id,
                total_played_seconds=position,
                batch_id=cls.station.batch_id,
            )

        cls.client.rotor_station_feedback_track_finished(
            station=cls.station.station_id,
            track_id=track.id,
            batch_id=cls.station.batch_id,
            total_played_seconds=duration,
        )
