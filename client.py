import time
from datetime import datetime
from hashlib import md5
import xml.dom.minidom as minidom

import requests

DEBUG = True

class Session(requests.Session):
    def __init__(self, token):
        super().__init__()
        self.base_url = 'https://api.music.yandex.net'
        self.headers.update({
            'X-Yandex-Music-Client': 'YandexMusicAndroid/23020251',
            'Authorization': f'OAuth {token}',
            'Accept-Language': 'ru',
        })

    def request(self, method, url, raw=False, *args, **kwargs):
        kwargs.pop('allow_redirects', None)
        error = None
        for i in range(10):
            try:
                result = super().request(
                    method,
                    url if raw else f"{self.base_url}{url}",
                    *args, **kwargs
                )
                break
            except Exception as err:
                time.sleep(5)
                error = err
        else:
            raise(error)

        # first request should be without user-agent header
        self.headers.update({
            'User-Agent': "Yandex-Music-API",
        })
        if DEBUG:
            print(method, url, *args, kwargs or '')

        if raw:
            return result.content

        return result.json()['result']


class Client:
    def __init__(self, token, station_id) -> None:
        self.session = Session(token)
        self.id = station_id
        self.me = self.session.get('/account/status')['account']
        self.batch_id = None

    def get_station_tracks(self, track_id=None):
        params = { 'settings2': True }
        if track_id:
            params['queue'] = track_id

        data = self.session.get(f'/rotor/station/{self.id}/tracks', params=params)

        self.batch_id = data['batchId']

        tracks = [
            dict(
                **t['track'],
                liked=t['liked'],
                params=t['trackParameters'],
            )
            for t in data['sequence']
        ]
        return tracks

    def feedback(self, type, **kwargs):
        return self.session.post(f'/rotor/station/{self.id}/feedback',
            json={
                'type': type,
                'timestamp': datetime.now().timestamp(),
                **kwargs,
            },
            params={
                'batch-id': self.batch_id,
            },
        ) == 'ok'

    def event_radio_started(self):
        self.feedback('radioStarted', **{'from': self.id.replace(':', '-')})

    def event_track_started(self, track_id):
        self.feedback('trackStarted', trackId=track_id)

    def event_track_finished(self, track_id, total_played_seconds):
        self.feedback('trackFinished', trackId=track_id, totalPlayedSeconds=total_played_seconds)

    def event_track_skip(self, track_id, total_played_seconds):
        self.feedback('skip', trackId=track_id, totalPlayedSeconds=total_played_seconds)

    def event_play_audio(self, track_id, from_cache, play_id, duration, played, album_id):
        self.session.post(f'/play-audio', {
            'track-id': track_id,
            'from-cache': str(from_cache),
            'from': "desktop_win-home-playlist_of_the_day-playlist-default",
            'play-id': play_id,
            'uid': self.me['uid'],
            'timestamp': f'{datetime.now().isoformat()}Z',
            'track-length-seconds': duration,
            'total-played-seconds': played,
            'end-position-seconds': played,
            'album-id': album_id,
            'playlist-id': None,
            'client-now': f'{datetime.now().isoformat()}Z',
        })

    def get_lyrics(self, track_id):
        data = self.session.get(f'/tracks/{track_id}/supplement')
        return data.get('lyrics', dict()).get('fullLyrics')

    def download(self, track_id, filename):
        data = self.session.get(f'/tracks/{track_id}/download-info')

        br = 0
        info = None
        for di in data:
            if di['codec'] == 'mp3':
                if di['bitrateInKbps'] > br:
                    info = di
                    br = di['bitrateInKbps']
        if not info:
            raise Exception(f'Download info unavailable')

        xml = self.session.get(info['downloadInfoUrl'], raw=True)

        def _get_text_node_data(elements):
            for element in elements:
                nodes = element.childNodes
                for node in nodes:
                    if node.nodeType == node.TEXT_NODE:
                        return node.data

        doc = minidom.parseString(xml)
        host = _get_text_node_data(doc.getElementsByTagName('host'))
        path = _get_text_node_data(doc.getElementsByTagName('path'))
        ts = _get_text_node_data(doc.getElementsByTagName('ts'))
        s = _get_text_node_data(doc.getElementsByTagName('s'))
        sign = md5(('XGRlBW9FXlekgbPrRHuSiA' + path[1::] + s).encode('utf-8')).hexdigest()

        with open(filename, 'wb') as f:
            f.write(
                self.session.get(
                    f'https://{host}/get-mp3/{sign}/{ts}{path}',
                    raw=True,
                )
            )

    def event_like(self, track_id, remove=False):
        action = 'remove' if remove else 'add-multiple'
        self.session.post(
            f'/users/{self.me["uid"]}/likes/tracks/{action}',
            {'track-ids': track_id},
        )

    def event_dislike(self, track_id, remove=False):
        action = 'remove' if remove else 'add-multiple'
        self.session.post(
            f'/users/{self.me["uid"]}/dislikes/tracks/{action}',
            {'track-ids': track_id},
        )
