"""Live publishing of delivery task changes (T-612, 06 §4): every save of a `DeliveryTask` that
creates it or changes its status or rider sends, after commit, `task.status` to the store's ops
sockets, `rider.status` for the riders concerned and a recomputed `order.eta` to the customer
(`hooks.task_changed`). A signal, so no state change in any service (dispatch, rider actions,
ops actions, T14 at the store) can skip the dispatch board.

States still change only in `apps.delivery.services` (and T14 in `orders.store_ops`); this only
observes them. Rider-facing messages (`task.updated`, `offer.*`) carry a reason the save does
not know, so the services send those themselves.
"""

from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.delivery import hooks
from apps.delivery.models import DeliveryTask

UNKNOWN = object()


@receiver(post_save, sender=DeliveryTask, dispatch_uid="delivery.live.task_saved")
def task_saved(sender, instance: DeliveryTask, created: bool, raw: bool = False, **kwargs):
    if raw:  # fixtures
        return
    if created:
        previous_status, previous_rider_id = None, None
    else:
        previous_status = getattr(instance, "_live_status", UNKNOWN)
        previous_rider_id = getattr(instance, "_live_rider_id", None)
        if previous_status is UNKNOWN:
            previous_status = None
        elif previous_status == instance.status and previous_rider_id == instance.rider_id:
            return
    hooks.task_changed(instance, previous_status, previous_rider_id)
    instance._live_status = instance.status
    instance._live_rider_id = instance.rider_id
