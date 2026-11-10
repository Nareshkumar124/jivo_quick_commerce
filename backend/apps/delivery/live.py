"""Live publishing of delivery task changes (T-612, 06 §4): every save of a `DeliveryTask` that
creates it or changes its status or rider sends, after commit, `task.status` to the store's ops
sockets, `rider.status` for the riders concerned and a recomputed `order.eta` to the customer
(`hooks.task_changed`). A signal, so no state change in any service (dispatch, rider actions,
ops actions, T14 at the store) can skip the dispatch board.

States still change only in `apps.delivery.services` (and T14 in `orders.store_ops`); this only
observes them. Rider-facing messages (`task.updated`, `offer.*`) carry a reason the save does
not know, so the services send those themselves.

Change detection (`DeliveryTask._live_snapshot`): the (status, rider) last read from the DB
(`from_db`, `refresh_from_db`) or committed by a save (set in the `on_commit` callback, so a
rolled-back save never moves it). Unknown (a deferred field, a new instance, a partial refresh)
publishes rather than skips: messages carry current state, so an extra one is harmless and a
missed one is not. `previous_status` is therefore null when unknown, including a task saved
twice in one transaction.
"""

from django.db import transaction
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.delivery import hooks
from apps.delivery.models import DeliveryTask


@receiver(post_save, sender=DeliveryTask, dispatch_uid="delivery.live.task_saved")
def task_saved(sender, instance: DeliveryTask, created: bool, raw: bool = False, **kwargs):
    if raw:  # fixtures
        return
    current = (instance.status, instance.rider_id)
    snapshot = None if created else instance._live_snapshot
    if snapshot == current:
        return
    previous_status, previous_rider_id = snapshot if snapshot is not None else (None, None)
    hooks.task_changed(instance, previous_status, previous_rider_id)

    def remember() -> None:
        instance._live_snapshot = current

    transaction.on_commit(remember)
