"""Support ticket console (05 §2 Support, §3 "Support tickets": Super Admin, Ops, Support; P7).

- List: `apps.support.services.staff_tickets(user)` (empty for anyone else), server-side search,
  filters and pagination (`tables.DataTable`), HTMX swaps the results only.
- Detail: the ticket looked up inside that queryset (another role gets the 403 from the
  capability first; an unknown id is a 404), its thread and the customer's linked order.
- Actions (POST + CSRF, then redirect back): reply (optionally with a status), status,
  priority, assign. Each is a thin wrapper around the T-711 staff services, which re-check
  `support.handle_ticket`, lock the row, enforce the status table and write the audit log.
  Message bodies are personal data: never logged here, never put in a toast.

Support is not store scoped (05 §3, T-711 PM default). Customer phones go through
`pii.display_phone` like every other screen.

P7 services: `with_sla` (list "SLA" column and filter), `sla_state` (detail),
`canned_replies` + `render_canned_reply` (insert a saved reply into the reply box; the agent
edits and sends it with `staff_reply`), `staff_attachment_url` (customer photos: a short-lived
signed URL made when the agent clicks, never embedded in the page; the service writes the
`support.attachment_view` audit entry with the client IP).
"""

from django import forms
from django.contrib import messages
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.exceptions import PermissionDenied, ValidationError
from django.db.models import Q
from django.http import Http404
from django.shortcuts import get_object_or_404, redirect, render
from django.template.loader import render_to_string
from django.urls import reverse
from django.utils import timezone
from django.utils.html import format_html
from django.views.decorators.http import require_POST
from unfold.widgets import UnfoldAdminSelectWidget, UnfoldAdminTextareaWidget

from apps.core.exceptions import ApiError
from apps.core.net import client_ip
from apps.ops_console import capabilities, status
from apps.ops_console.access import forbidden, ops_view
from apps.ops_console.dates import DISPLAY_TZ
from apps.ops_console.pii import can_view_full_phone, customer_label, person_label
from apps.ops_console.tables import Column, DataTable, Filter
from apps.ops_console.views import ops_context
from apps.support import services
from apps.support.choices import TicketCategory, TicketPriority, TicketStatus
from apps.support.models import MESSAGE_MAX_LENGTH

CAPABILITY = capabilities.SUPPORT_TICKETS

ACTIONS = ("reply", "status", "priority", "assign")
UNASSIGNED = "none"
MINE = "me"


def handlers():
    """Active staff who may handle tickets (superusers, or `support.handle_ticket` through a
    group or directly): the assignee choices. `services.assign` checks the same rule again."""
    perm = Permission.objects.filter(
        codename="handle_ticket", content_type__app_label="support"
    ).values("pk")
    return (
        get_user_model()
        .objects.filter(is_active=True, is_staff=True)
        .filter(
            Q(is_superuser=True) | Q(groups__permissions__in=perm) | Q(user_permissions__in=perm)
        )
        .distinct()
        .order_by("name", "email", "pk")
    )


def _staff_name(user) -> str:
    return (user.name or "").strip() or user.email or f"User {user.pk}"


# --------------------------------------------------------------------------- forms


class ReplyForm(forms.Form):
    body = forms.CharField(
        label="Reply",
        max_length=MESSAGE_MAX_LENGTH,
        widget=UnfoldAdminTextareaWidget(attrs={"rows": 4}),
    )
    status = forms.ChoiceField(
        label="Then set status",
        required=False,
        choices=[("", "Keep (open tickets move to In progress)"), *TicketStatus.choices],
        widget=UnfoldAdminSelectWidget,
    )


class StatusForm(forms.Form):
    status = forms.ChoiceField(choices=TicketStatus.choices, widget=UnfoldAdminSelectWidget)


class PriorityForm(forms.Form):
    priority = forms.ChoiceField(choices=TicketPriority.choices, widget=UnfoldAdminSelectWidget)


class AssignForm(forms.Form):
    assignee = forms.ModelChoiceField(
        queryset=get_user_model().objects.none(),
        required=False,
        empty_label="Unassigned",
        widget=UnfoldAdminSelectWidget,
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["assignee"].queryset = handlers()
        self.fields["assignee"].label_from_instance = _staff_name


FORMS = {"reply": ReplyForm, "status": StatusForm, "priority": PriorityForm, "assign": AssignForm}


# --------------------------------------------------------------------------- list


def _badge(kind, code) -> str:
    return render_to_string(
        "ops/components/status_badge.html", {"badge": status.badge_for(kind, code)}
    )


def _ticket_link(ticket) -> str:
    return format_html(
        '<a class="font-semibold text-primary-600 dark:text-primary-500" href="{}">{}</a>',
        reverse("ops:support-ticket", args=[ticket.pk]),
        ticket.number,
    )


def _local(value) -> str:
    return timezone.localtime(value, DISPLAY_TZ).strftime("%d %b, %H:%M") if value else "-"


def _sla_cell(ticket) -> str:
    if getattr(ticket, "sla_breached", False):
        return _badge(status.TICKET_SLA, "breached")
    return ""


def _assigned_filter(request):
    def apply(queryset, value):
        if value == MINE:
            return queryset.filter(assigned_to=request.user)
        if value == UNASSIGNED:
            return queryset.filter(assigned_to__isnull=True)
        return queryset

    return apply


def tickets_table(request) -> dict:
    user = request.user
    full = can_view_full_phone(user)
    queryset = services.with_sla(
        services.staff_tickets(user).select_related("user", "order", "assigned_to")
    )
    return DataTable(
        request,
        queryset,
        table_id="support-tickets",
        url=reverse("ops:support-tickets"),
        columns=[
            Column("Ticket", _ticket_link, css="whitespace-nowrap"),
            Column("Subject", lambda t: t.subject),
            Column("Customer", lambda t: customer_label(t.user, full=full)),
            Column("Status", lambda t: _badge(status.TICKET, t.status)),
            Column("Priority", lambda t: _badge(status.TICKET_PRIORITY, t.priority)),
            Column(
                "Assigned to",
                lambda t: _staff_name(t.assigned_to) if t.assigned_to_id else "Unassigned",
            ),
            Column(
                "Last activity (IST)", lambda t: _local(t.last_activity_at), css="whitespace-nowrap"
            ),
            Column("SLA", _sla_cell),
        ],
        search_fields=("subject", "order__order_number"),
        search_placeholder="Subject or order number",
        filters=[
            Filter(
                "status",
                "Status",
                TicketStatus.choices,
                lambda queryset, value: queryset.filter(status=value),
            ),
            Filter(
                "priority",
                "Priority",
                TicketPriority.choices,
                lambda queryset, value: queryset.filter(priority=value),
            ),
            Filter(
                "category",
                "Category",
                TicketCategory.choices,
                lambda queryset, value: queryset.filter(category=value),
            ),
            Filter(
                "assigned",
                "Assigned",
                [(MINE, "Assigned to me"), (UNASSIGNED, "Unassigned")],
                _assigned_filter(request),
            ),
            Filter(
                "sla",
                "SLA",
                [("breached", "Breached")],
                lambda queryset, value: queryset.filter(sla_breached=True),
            ),
        ],
        per_page=25,
        empty_title="No tickets found",
        empty_message="Try another search or clear the filters.",
    ).context()


@ops_view(capability=CAPABILITY)
def ticket_list(request):
    return render(
        request,
        "ops/support/list.html",
        ops_context(request, title="Support tickets", table=tickets_table(request)),
    )


@ops_view(capability=CAPABILITY)
def ticket_list_partial(request):
    return render(
        request, "ops/components/data_table_results.html", {"table": tickets_table(request)}
    )


# --------------------------------------------------------------------------- detail


def _ticket(user, ticket_id: int):
    queryset = services.staff_tickets(user).select_related("user", "order", "assigned_to")
    return get_object_or_404(queryset, pk=ticket_id)


@ops_view(capability=CAPABILITY)
def ticket_detail(request, ticket_id: int):
    user = request.user
    ticket = _ticket(user, ticket_id)
    full = can_view_full_phone(user)
    messages_qs = (
        ticket.messages.select_related("sender")
        .prefetch_related("attachment_files")
        .order_by("created_at", "id")
    )
    thread = [
        {
            "is_staff": message.is_staff,
            "who": person_label(message.sender, full=full) if message.is_staff else "Customer",
            "at": message.created_at,
            "body": message.body,
            "attachments": [a.key for a in message.attachment_files.all()],
        }
        for message in messages_qs
    ]
    closed = ticket.status == TicketStatus.CLOSED
    allowed_next = services.STAFF_TRANSITIONS[ticket.status]
    status_form = StatusForm()
    status_form.fields["status"].choices = [
        (code, label) for code, label in TicketStatus.choices if code in allowed_next
    ]
    reply_form = ReplyForm()
    reply_form.fields["status"].choices = [
        ("", "Keep (open tickets move to In progress)"),
        *[(code, label) for code, label in TicketStatus.choices if code in allowed_next],
    ]
    context = ops_context(
        request,
        title=f"Ticket {ticket.number}",
        ticket=ticket,
        customer=customer_label(ticket.user, full=full),
        status_badge=status.badge_for(status.TICKET, ticket.status),
        priority_badge=status.badge_for(status.TICKET_PRIORITY, ticket.priority),
        assignee=_staff_name(ticket.assigned_to) if ticket.assigned_to_id else "Unassigned",
        thread=thread,
        closed=closed,
        reply_form=reply_form,
        status_form=status_form if allowed_next else None,
        priority_form=PriorityForm(initial={"priority": ticket.priority}),
        assign_form=AssignForm(initial={"assignee": ticket.assigned_to_id}),
        order_url=_order_url(user, ticket.order_id),
        sla=services.sla_state(ticket),
        canned=[] if closed else list(services.canned_replies(user, ticket.category)),
    )
    return render(request, "ops/support/detail.html", context)


@ops_view(capability=CAPABILITY)
def canned_reply(request, ticket_id: int):
    """HTMX: the reply box filled with a canned reply for this ticket (render_canned_reply);
    the agent edits it, then sends it with the reply form."""
    ticket = _ticket(request.user, ticket_id)
    reply_id = request.GET.get("reply", "")
    body = ""
    if reply_id.isdigit():
        try:
            body = services.render_canned_reply(request.user, int(reply_id), ticket.pk)
        except PermissionDenied:
            return forbidden(request)
        except ValidationError:
            raise Http404("No such canned reply.") from None
    form = ReplyForm(initial={"body": body})
    return render(request, "ops/support/reply_body.html", {"reply_form": form})


@ops_view(capability=CAPABILITY)
def attachment(request, ticket_id: int, key: str):
    """A customer photo on a ticket: redirect to a short-lived signed URL (private bucket).

    The key must belong to the URL's ticket (inside the user's ticket queryset): a valid key of
    another ticket is a 404, before the service is called. The service re-checks the handler
    permission and writes the `support.attachment_view` audit entry (ids and client IP only)."""
    ticket = _ticket(request.user, ticket_id)
    if not ticket.uploads.filter(key=key).exists():
        raise Http404("No such attachment.")
    try:
        url = services.staff_attachment_url(request.user, key, ip=client_ip(request))
    except PermissionDenied:
        return forbidden(request)
    except ValidationError:
        raise Http404("No such attachment.") from None
    return redirect(url)


def _order_url(user, order_id) -> str:
    if order_id is None or not user.has_perm("orders.view_order"):
        return ""
    return reverse("admin:orders_order_change", args=[order_id])


def _first_error(error: ValidationError) -> str:
    return error.messages[0] if error.messages else "Check the form."


@require_POST
@ops_view(capability=CAPABILITY)
def ticket_action(request, ticket_id: int, action: str):
    if action not in ACTIONS:
        raise Http404("No such action.")
    user = request.user
    ticket = _ticket(user, ticket_id)  # 404 before any service call
    form = FORMS[action](request.POST)
    detail = redirect("ops:support-ticket", ticket_id=ticket.pk)
    if not form.is_valid():
        errors = [error for field_errors in form.errors.values() for error in field_errors]
        messages.error(request, errors[0] if errors else "Check the form.")
        return detail
    data = form.cleaned_data
    try:
        if action == "reply":
            services.staff_reply(user, ticket.pk, data["body"], status=data["status"] or None)
            done = "Reply sent."
        elif action == "status":
            services.change_status(user, ticket.pk, data["status"])
            done = f"Status set to {TicketStatus(data['status']).label}."
        elif action == "priority":
            services.set_priority(user, ticket.pk, data["priority"])
            done = f"Priority set to {TicketPriority(data['priority']).label}."
        else:
            services.assign(user, ticket.pk, data["assignee"])
            done = "Assignment saved."
    except PermissionDenied:
        return forbidden(request)
    except ValidationError as error:
        messages.error(request, _first_error(error))
        return detail
    except ApiError as error:
        messages.error(request, error.message)
        return detail
    messages.success(request, done)
    return detail
