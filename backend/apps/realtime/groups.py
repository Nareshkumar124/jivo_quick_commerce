"""Channel-layer group names (ASCII letters, digits, ".", "-", "_"; under 100 characters)."""


def order_group(order_id: int) -> str:
    """The customer tracking socket of one order."""
    return f"order.{int(order_id)}"


def rider_group(rider_id: int) -> str:
    """The rider app socket of one rider (`delivery.Rider` pk)."""
    return f"rider.{int(rider_id)}"


def store_group(store_id: int) -> str:
    """The ops sockets permitted for one store."""
    return f"ops.store.{int(store_id)}"
