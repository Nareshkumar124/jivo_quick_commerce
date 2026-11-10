"""drf-spectacular postprocessing hook: publish the WebSocket messages (apps.realtime.contract)
as `Ws...` components, so the generated Dart client has a model per message type."""

from apps.realtime import contract


def add_websocket_components(result, generator, request, public):
    schemas = result.setdefault("components", {}).setdefault("schemas", {})
    for name, schema in contract.components().items():
        schemas[name] = schema

    return result
