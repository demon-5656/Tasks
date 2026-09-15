import os,sentry_sdk
sentry_sdk.init(dsn=os.environ['SENTRY_DSN'],send_default_pii=False,default_integrations=False,environment='netology',release='netology-sentry@1.0')
with sentry_sdk.new_scope() as scope:
    scope.set_tag('exercise','10-monitoring-05-sentry')
    scope.set_tag('check','email-alert')
    try:
        raise RuntimeError('Netology: проверка доставки уведомления Sentry')
    except RuntimeError as error:
        event_id=sentry_sdk.capture_exception(error)
    sentry_sdk.flush(timeout=20)
    print('event_id='+str(event_id))
