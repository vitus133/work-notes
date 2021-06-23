import logging

class Logger():
    @property
    def logger(self):
        name = 'ztp-site-generator.post-sync'
        lg = logging.getLogger(name)
        lg.setLevel(10)
        formatter = logging.Formatter(
            '%(name)s %(asctime)s %(levelname)s [%(module)s:%(lineno)s]: %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S')
        if not lg.hasHandlers():
            # logging to console only
            handler = logging.StreamHandler()
            handler.setLevel(10)
            handler.setFormatter(formatter)
            lg.addHandler(handler)
        return lg