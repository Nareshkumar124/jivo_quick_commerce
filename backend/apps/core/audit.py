"""The audit log (05 §5): every staff mutation on orders, stock, prices, refunds, riders and
config is recorded with `record()`. Call it inside the same transaction as the change, so a
rolled-back change leaves no entry."""

from apps.core.models import AuditLog


def record(actor, action: str, obj, changes: dict | None = None, *, ip: str | None = None):
    """One append-only entry. `obj` is a model instance (or a `(object_type, object_id)` pair);
    `changes` must hold no personal data and no free text (ids, statuses, amounts, reason
    codes; for a note, its length only)."""
    if isinstance(obj, tuple):
        object_type, object_id = obj
    else:
        object_type, object_id = obj._meta.label_lower, obj.pk
    return AuditLog.objects.create(
        actor=actor if getattr(actor, "pk", None) else None,
        action=action,
        object_type=object_type,
        object_id=str(object_id),
        changes=changes or {},
        ip=ip,
    )
