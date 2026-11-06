"""Riders admin (05 §2 "Riders", 05 §3 "Rider approval / suspend"; Phase 5).

- Who: `delivery.view_rider` / `view_riderdocument` / `view_ridershift` (Super Admin, Ops,
  Store Manager "view own"); review actions need `delivery.review_rider` (Super Admin, Ops) and
  go only through `apps.delivery.services.kyc` (which re-checks the permission and the store
  scope, locks, and writes the audit log with the request IP).
- Store scoping: every list starts from `kyc.staff_riders(user)` (riders whose home or
  preferred store is one of the user's stores); another store's rider is a 404.
- KYC documents: the file opens only through a short-lived signed URL
  (`kyc.document_file_url`, `delivery.view_kyc_document_file`), and the full document number is
  shown only on request (`kyc.document_number`); both calls are audited. The list shows the
  masked number only. Files and numbers are never logged.
- PII: roles with full customer access (`accounts.view_customer`: Super Admin, Ops) see the
  rider's phone, date of birth and emergency contact; Store Manager sees the name and a masked
  phone. Bank details are shown as the last four digits only, to everyone.
- Delivery tasks and offers (slice 5.3) are read-only for everyone
  (`delivery.view_deliverytask` / `view_deliveryoffer`: Super Admin, Ops, Store Manager own
  stores), scoped to the user's stores by the task's store; another store's task is a 404.
  The delivery OTP (encrypted column) and the failure photo are never shown; the pickup code and
  the OTP appear only as their lock state. Changes go through the Ops dispatch screens
  (`/ops/dispatch/`), which call the delivery services.
- Shifts and location history are read-only for everyone (locations: Super Admin only, the
  `delivery.view_riderlocation` permission), coordinates rounded to 4 decimals (about 10 m).
"""

from django import forms
from django.contrib import admin, messages
from django.contrib.admin.utils import unquote
from django.core.exceptions import PermissionDenied, ValidationError
from django.db.models import BooleanField, Value
from django.http import Http404, HttpResponseRedirect
from django.shortcuts import get_object_or_404
from django.template.response import TemplateResponse
from django.urls import reverse
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import action, display
from unfold.widgets import UnfoldAdminSelectWidget, UnfoldAdminTextareaWidget

from apps.core.exceptions import ApiError
from apps.core.net import client_ip
from apps.delivery.models import (
    DeliveryOffer,
    DeliveryTask,
    Rider,
    RiderDocument,
    RiderLocation,
    RiderShift,
)
from apps.delivery.services import kyc
from apps.ops_console.money import RupeeInput, inr
from apps.ops_console.pii import can_view_full_phone, mask_phone
from apps.stores.services import stores_for

REVIEW = "delivery.review_rider"
VIEW_FILE = "delivery.view_kyc_document_file"


def _full(obj) -> bool:
    return bool(getattr(obj, "full_pii", False))


def _flag(queryset, user):
    return queryset.annotate(full_pii=Value(can_view_full_phone(user), output_field=BooleanField()))


def _refusal(error) -> str:
    if isinstance(error, ApiError):
        return error.message
    if isinstance(error, ValidationError):
        return " ".join(error.messages)
    return str(error) or kyc.MSG_NO_PERMISSION


class ReadOnlyMixin:
    def has_add_permission(self, request, obj=None) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_actions(self, request):
        return {}


class ScopedObjectMixin:
    def get_object(self, request, object_id, from_field=None):
        obj = super().get_object(request, object_id, from_field)
        if obj is None:
            raise Http404("No such record.")
        return obj


# --------------------------------------------------------------------------- forms


class ReasonForm(forms.Form):
    reason = forms.CharField(
        label="Reason (shown to the rider)",
        max_length=300,
        widget=UnfoldAdminTextareaWidget(attrs={"rows": 3}),
    )


class ApproveRiderForm(forms.Form):
    home_store = forms.ChoiceField(
        label="Home store", required=False, widget=UnfoldAdminSelectWidget
    )
    cash_limit = forms.DecimalField(
        label="Cash limit (₹)",
        required=False,
        max_digits=10,
        decimal_places=2,
        min_value=0,
        widget=RupeeInput,
        help_text="Empty: the default limit.",
    )

    def __init__(self, *args, stores=(), **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["home_store"].choices = [("", "The rider's preferred store")] + [
            (str(store.pk), f"{store.code} {store.name}") for store in stores
        ]


class StoreForm(forms.Form):
    store = forms.ChoiceField(label="Home store", widget=UnfoldAdminSelectWidget)

    def __init__(self, *args, stores=(), **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["store"].choices = [(str(s.pk), f"{s.code} {s.name}") for s in stores]


class CashLimitForm(forms.Form):
    amount = forms.DecimalField(
        label="Cash limit (₹)", max_digits=10, decimal_places=2, min_value=0, widget=RupeeInput
    )


def _form_page(model_admin, request, obj, title, form, intro, submit, danger=False):
    context = {
        **model_admin.admin_site.each_context(request),
        "opts": model_admin.opts,
        "title": title,
        "object": obj,
        "form": form,
        "intro": intro,
        "submit": submit,
        "danger": danger,
        "back": reverse(
            f"admin:{model_admin.opts.app_label}_{model_admin.opts.model_name}_change",
            args=[obj.pk],
        ),
    }
    request.current_app = model_admin.admin_site.name
    return TemplateResponse(request, "admin/delivery/action_form.html", context)


# --------------------------------------------------------------------------- riders


class DocumentInline(ReadOnlyMixin, TabularInline):
    model = RiderDocument
    extra = 0
    can_delete = False
    show_change_link = True
    fields = ("doc_type", "status", "doc_number_masked", "uploaded_at", "reviewed_at")
    readonly_fields = fields
    verbose_name_plural = "KYC documents (open one to review it)"


@admin.register(Rider)
class RiderAdmin(ScopedObjectMixin, ReadOnlyMixin, ModelAdmin):
    list_display = (
        "full_name",
        "phone",
        "status",
        "vehicle_type",
        "home_store",
        "is_online",
        "cash",
        "submitted_at",
    )
    list_display_links = ("full_name",)
    list_filter = ("status", "vehicle_type", "is_online")
    list_select_related = ("user", "home_store", "preferred_store")
    search_fields = ("full_name", "vehicle_number")
    search_help_text = "Name or vehicle number"
    ordering = ("-submitted_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    inlines = [DocumentInline]
    actions_detail = [
        "approve",
        "reject",
        "suspend",
        "reinstate",
        "change_home_store",
        "change_cash_limit",
    ]
    fieldsets = (
        (
            "Rider",
            {
                "fields": (
                    "full_name",
                    "phone",
                    "status",
                    "rejection_reason",
                    "suspension_reason",
                    "submitted_at",
                    "approved_at",
                )
            },
        ),
        ("Personal (full access only)", {"fields": ("date_of_birth", "emergency_contact")}),
        (
            "Vehicle and stores",
            {"fields": ("vehicle_type", "vehicle_number", "preferred_store", "home_store")},
        ),
        ("Work", {"fields": ("is_online", "cash", "limit", "rating_avg", "last_location_at")}),
        ("Bank", {"fields": ("bank",)}),
    )

    def get_queryset(self, request):
        return _flag(kyc.staff_riders(request.user), request.user).select_related(
            "user", "home_store", "preferred_store"
        )

    def get_readonly_fields(self, request, obj=None):
        return [name for _title, options in self.fieldsets for name in options["fields"]]

    @display(description="Phone")
    def phone(self, obj) -> str:
        number = obj.user.phone if obj.user_id else ""
        return number if _full(obj) else mask_phone(number)

    @display(description="Cash in hand", ordering="cash_in_hand")
    def cash(self, obj) -> str:
        return inr(obj.cash_in_hand)

    @display(description="Cash limit")
    def limit(self, obj) -> str:
        return inr(obj.cash_limit)

    @display(description="Date of birth")
    def date_of_birth(self, obj) -> str:
        return obj.dob.strftime("%d %b %Y") if _full(obj) and obj.dob else "-"

    @display(description="Emergency contact")
    def emergency_contact(self, obj) -> str:
        if not _full(obj):
            return "(hidden for your role)"
        return f"{obj.emergency_contact_name}, {obj.emergency_contact_phone}"

    @display(description="Bank account")
    def bank(self, obj) -> str:
        if not obj.bank_account_last4:
            return "Not added yet"
        return f"{obj.bank_account_name} · •••• {obj.bank_account_last4} · {obj.ifsc}"

    # ---------------------------------------------------------------- review actions

    def has_review_permission(self, request, object_id=None) -> bool:
        return kyc.can_review(request.user)

    def has_cash_limit_permission(self, request, object_id=None) -> bool:
        """DL-61 (a): Super Admin, Ops, Store Manager (own store riders; the queryset scopes).
        SLICE 5.4: `kyc.set_cash_limit` moves from `review_rider` to `dispatch_order`
        (`kyc.OPS_DELIVERY`); until that merge the button follows the review permission."""
        ops_perm = getattr(kyc, "OPS_DELIVERY", None)
        if ops_perm is None:
            return kyc.can_review(request.user)
        user = request.user
        return bool(user.is_active and user.is_staff and user.has_perm(ops_perm))

    def _rider(self, request, object_id) -> Rider:
        if not kyc.can_review(request.user):
            raise PermissionDenied
        return get_object_or_404(self.get_queryset(request), pk=unquote(object_id))

    def _run(self, request, rider, call, success: str):
        try:
            call()
        except (ValidationError, ApiError, PermissionDenied) as error:
            self.message_user(request, _refusal(error), messages.ERROR)
        else:
            self.message_user(request, success, messages.SUCCESS)
        return HttpResponseRedirect(reverse("admin:delivery_rider_change", args=[rider.pk]))

    @action(description="Approve rider", url_path="approve", permissions=["review"])
    def approve(self, request, object_id):
        rider = self._rider(request, object_id)
        stores = list(stores_for(request.user).filter(is_active=True).order_by("code"))
        form = ApproveRiderForm(request.POST or None, stores=stores)
        if request.method == "POST" and form.is_valid():
            store = form.cleaned_data["home_store"]
            return self._run(
                request,
                rider,
                lambda: kyc.approve_rider(
                    rider.pk,
                    by=request.user,
                    ip=client_ip(request),
                    home_store_id=int(store) if store else None,
                    cash_limit=form.cleaned_data["cash_limit"],
                ),
                f"{rider.full_name} approved: they can go online now.",
            )
        return _form_page(
            self,
            request,
            rider,
            f"Approve {rider.full_name}",
            form,
            "Every required document must be approved and bank details added.",
            "Approve rider",
        )

    def _reason_action(self, request, object_id, service, title, intro, submit, success):
        rider = self._rider(request, object_id)
        form = ReasonForm(request.POST or None)
        if request.method == "POST" and form.is_valid():
            return self._run(
                request,
                rider,
                lambda: service(
                    rider.pk,
                    by=request.user,
                    ip=client_ip(request),
                    reason=form.cleaned_data["reason"],
                ),
                success.format(name=rider.full_name),
            )
        return _form_page(
            self, request, rider, title.format(name=rider.full_name), form, intro, submit, True
        )

    @action(description="Reject rider", url_path="reject", permissions=["review"])
    def reject(self, request, object_id):
        return self._reason_action(
            request,
            object_id,
            kyc.reject_rider,
            "Reject {name}",
            "The rider sees the reason and can submit again.",
            "Reject rider",
            "{name} rejected.",
        )

    @action(description="Suspend rider", url_path="suspend", permissions=["review"])
    def suspend(self, request, object_id):
        return self._reason_action(
            request,
            object_id,
            kyc.suspend_rider,
            "Suspend {name}",
            "The rider is set offline and cannot take orders until reinstated.",
            "Suspend rider",
            "{name} suspended.",
        )

    @action(description="Reinstate rider", url_path="reinstate", permissions=["review"])
    def reinstate(self, request, object_id):
        rider = self._rider(request, object_id)
        if request.method != "POST":
            return _form_page(
                self,
                request,
                rider,
                f"Reinstate {rider.full_name}",
                forms.Form(),
                "The rider can go online again.",
                "Reinstate rider",
            )
        return self._run(
            request,
            rider,
            lambda: kyc.reinstate_rider(rider.pk, by=request.user, ip=client_ip(request)),
            f"{rider.full_name} reinstated.",
        )

    @action(description="Change home store", url_path="home-store", permissions=["review"])
    def change_home_store(self, request, object_id):
        rider = self._rider(request, object_id)
        stores = list(stores_for(request.user).filter(is_active=True).order_by("code"))
        form = StoreForm(request.POST or None, stores=stores)
        if request.method == "POST" and form.is_valid():
            return self._run(
                request,
                rider,
                lambda: kyc.set_home_store(
                    rider.pk,
                    int(form.cleaned_data["store"]),
                    by=request.user,
                    ip=client_ip(request),
                ),
                "Home store changed.",
            )
        return _form_page(
            self,
            request,
            rider,
            f"Home store of {rider.full_name}",
            form,
            "The rider must be offline.",
            "Save",
        )

    @action(description="Change cash limit", url_path="cash-limit", permissions=["cash_limit"])
    def change_cash_limit(self, request, object_id):
        rider = self._rider(request, object_id)
        form = CashLimitForm(request.POST or None)
        if request.method == "POST" and form.is_valid():
            return self._run(
                request,
                rider,
                lambda: kyc.set_cash_limit(
                    rider.pk, form.cleaned_data["amount"], by=request.user, ip=client_ip(request)
                ),
                "Cash limit changed.",
            )
        return _form_page(
            self,
            request,
            rider,
            f"Cash limit of {rider.full_name}",
            form,
            "Above this cash in hand the rider gets no COD orders.",
            "Save",
        )


# --------------------------------------------------------------------------- documents


@admin.register(RiderDocument)
class RiderDocumentAdmin(ScopedObjectMixin, ReadOnlyMixin, ModelAdmin):
    list_display = ("rider_name", "doc_type", "status", "doc_number_masked", "uploaded_at")
    list_display_links = ("rider_name", "doc_type")
    list_filter = ("status", "doc_type")
    list_select_related = ("rider",)
    search_fields = ("rider__full_name",)
    ordering = ("-uploaded_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    actions_detail = ["open_file", "show_number", "approve_document", "reject_document"]
    fields = (
        "rider_link",
        "doc_type",
        "status",
        "doc_number_masked",
        "review_note",
        "uploaded_at",
        "reviewed_at",
    )
    readonly_fields = fields

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .filter(rider__in=kyc.staff_riders(request.user))
            .select_related("rider")
        )

    @display(description="Rider", ordering="rider__full_name")
    def rider_name(self, obj) -> str:
        return obj.rider.full_name

    @display(description="Rider")
    def rider_link(self, obj) -> str:
        url = reverse("admin:delivery_rider_change", args=[obj.rider_id])
        return format_html(
            '<a class="text-primary-600 dark:text-primary-500" href="{}">{}</a>',
            url,
            obj.rider.full_name,
        )

    def has_review_permission(self, request, object_id=None) -> bool:
        return kyc.can_review(request.user)

    def has_view_file_permission(self, request, object_id=None) -> bool:
        return request.user.has_perm(VIEW_FILE)

    def _document(self, request, object_id) -> RiderDocument:
        return get_object_or_404(self.get_queryset(request), pk=unquote(object_id))

    def _back(self, document):
        return HttpResponseRedirect(
            reverse("admin:delivery_riderdocument_change", args=[document.pk])
        )

    @action(description="Open file (signed link)", url_path="file", permissions=["view_file"])
    def open_file(self, request, object_id):
        """POST only (a confirm page on GET), so a link prefetch never makes an audited view."""
        document = self._document(request, object_id)
        if request.method != "POST":
            return _form_page(
                self,
                request,
                document,
                f"Open {document.get_doc_type_display()} of {document.rider.full_name}",
                forms.Form(),
                "Opening the file is recorded in the audit log. The link works for a few minutes.",
                "Open file",
            )
        try:
            url, _expires = kyc.document_file_url(
                document.pk, by=request.user, ip=client_ip(request)
            )
        except (ValidationError, PermissionDenied) as error:
            self.message_user(request, _refusal(error), messages.ERROR)
            return self._back(document)
        return HttpResponseRedirect(url)

    @action(description="Show document number", url_path="number", permissions=["view_file"])
    def show_number(self, request, object_id):
        """POST only (a confirm page on GET), so a link prefetch never makes an audited view."""
        document = self._document(request, object_id)
        if request.method != "POST":
            return _form_page(
                self,
                request,
                document,
                f"Show the {document.get_doc_type_display()} number of {document.rider.full_name}",
                forms.Form(),
                "Showing the number is recorded in the audit log.",
                "Show number",
            )
        try:
            number = kyc.document_number(document.pk, by=request.user, ip=client_ip(request))
        except (ValidationError, PermissionDenied) as error:
            self.message_user(request, _refusal(error), messages.ERROR)
            return self._back(document)
        context = {
            **self.admin_site.each_context(request),
            "opts": self.opts,
            "title": f"{document.get_doc_type_display()} of {document.rider.full_name}",
            "object": document,
            "number": number or "No number for this document type.",
            "back": reverse("admin:delivery_riderdocument_change", args=[document.pk]),
        }
        request.current_app = self.admin_site.name
        response = TemplateResponse(request, "admin/delivery/document_number.html", context)
        response["Cache-Control"] = "no-store"
        return response

    @action(description="Approve document", url_path="approve", permissions=["review"])
    def approve_document(self, request, object_id):
        document = self._document(request, object_id)
        if request.method == "POST":
            try:
                kyc.approve_document(document.pk, by=request.user, ip=client_ip(request))
            except (ValidationError, ApiError, PermissionDenied) as error:
                self.message_user(request, _refusal(error), messages.ERROR)
            else:
                self.message_user(request, "Document approved.", messages.SUCCESS)
            return self._back(document)
        return _form_page(
            self,
            request,
            document,
            f"Approve {document.get_doc_type_display()}",
            forms.Form(),
            "Check the file before approving it.",
            "Approve document",
        )

    @action(description="Reject document", url_path="reject", permissions=["review"])
    def reject_document(self, request, object_id):
        document = self._document(request, object_id)
        form = ReasonForm(request.POST or None)
        if request.method == "POST" and form.is_valid():
            try:
                kyc.reject_document(
                    document.pk,
                    by=request.user,
                    ip=client_ip(request),
                    note=form.cleaned_data["reason"],
                )
            except (ValidationError, ApiError, PermissionDenied) as error:
                self.message_user(request, _refusal(error), messages.ERROR)
            else:
                self.message_user(request, "Document rejected.", messages.SUCCESS)
            return self._back(document)
        return _form_page(
            self,
            request,
            document,
            f"Reject {document.get_doc_type_display()}",
            form,
            "The rider is asked to upload a new copy.",
            "Reject document",
            True,
        )


# --------------------------------------------------------------------------- shifts, locations


@admin.register(RiderShift)
class RiderShiftAdmin(ScopedObjectMixin, ReadOnlyMixin, ModelAdmin):
    list_display = ("rider_name", "started_at", "ended_at", "end_reason")
    list_filter = ("end_reason",)
    list_select_related = ("rider",)
    ordering = ("-started_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    fields = ("rider_name", "started_at", "ended_at", "end_reason")
    readonly_fields = fields

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .filter(rider__in=kyc.staff_riders(request.user))
            .select_related("rider")
        )

    @display(description="Rider", ordering="rider__full_name")
    def rider_name(self, obj) -> str:
        return obj.rider.full_name


@admin.register(RiderLocation)
class RiderLocationAdmin(ScopedObjectMixin, ReadOnlyMixin, ModelAdmin):
    list_display = ("rider_name", "recorded_at", "coordinates", "accuracy_m", "is_mocked")
    list_filter = ("is_mocked",)
    list_select_related = ("rider",)
    ordering = ("-recorded_at", "-id")
    list_per_page = 100
    show_full_result_count = False
    fields = ("rider_name", "recorded_at", "received_at", "coordinates", "accuracy_m", "is_mocked")
    readonly_fields = fields

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .filter(rider__in=kyc.staff_riders(request.user))
            .select_related("rider")
        )

    @display(description="Rider", ordering="rider__full_name")
    def rider_name(self, obj) -> str:
        return obj.rider.full_name

    @display(description="Location (about 10 m)")
    def coordinates(self, obj) -> str:
        return f"{obj.point.y:.4f}, {obj.point.x:.4f}" if obj.point else "-"


# --------------------------------------------------------------------------- tasks and offers


def _ops_task_link(task) -> str:
    return format_html(
        '<a class="text-primary-600" href="{}">Open in dispatch</a>',
        reverse("ops:dispatch-task", args=[task.pk]),
    )


class OfferInline(ReadOnlyMixin, TabularInline):
    model = DeliveryOffer
    extra = 0
    can_delete = False
    fields = ("rider_name", "status", "offered_at", "expires_at", "responded_at", "reject_reason")
    readonly_fields = fields
    ordering = ("-offered_at",)

    def get_queryset(self, request):
        return super().get_queryset(request).select_related("rider")

    @display(description="Rider")
    def rider_name(self, obj) -> str:
        return obj.rider.full_name


@admin.register(DeliveryTask)
class DeliveryTaskAdmin(ScopedObjectMixin, ReadOnlyMixin, ModelAdmin):
    list_display = (
        "order_number",
        "store_code",
        "status",
        "rider_name",
        "assignment_mode",
        "search_started_at",
        "locks",
    )
    list_filter = ("status", "assignment_mode")
    search_fields = ("order__order_number",)
    list_select_related = ("order", "store", "rider")
    ordering = ("-search_started_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    inlines = (OfferInline,)
    fields = (
        "order_number",
        "store_code",
        "status",
        "rider_name",
        "assignment_mode",
        "attempt_count",
        "distance_km",
        "payout_amount_inr",
        "search_started_at",
        "next_dispatch_at",
        "unassigned_at",
        "assigned_at",
        "arrived_store_at",
        "picked_up_at",
        "arrived_customer_at",
        "arrival_override_reason",
        "delivered_at",
        "failed_at",
        "fail_reason",
        "fail_note",
        "fail_call_attempts",
        "returned_at",
        "cancelled_at",
        "pickup_attempts",
        "pickup_lock",
        "otp_attempts",
        "otp_lock",
        "ops_link",
    )
    readonly_fields = fields

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .filter(store__in=stores_for(request.user))
            .defer("delivery_otp_encrypted")
            .select_related("order", "store", "rider")
        )

    @display(description="Order", ordering="order__order_number")
    def order_number(self, obj) -> str:
        return obj.order.order_number

    @display(description="Store", ordering="store__code")
    def store_code(self, obj) -> str:
        return obj.store.code

    @display(description="Rider", ordering="rider__full_name")
    def rider_name(self, obj) -> str:
        return obj.rider.full_name if obj.rider_id else "-"

    @display(description="Estimated payout")
    def payout_amount_inr(self, obj) -> str:
        return inr(obj.payout_amount)

    @display(description="Pickup code")
    def pickup_lock(self, obj) -> str:
        return "Locked" if obj.pickup_locked_at else "Not locked"

    @display(description="Delivery OTP")
    def otp_lock(self, obj) -> str:
        return "Locked" if obj.otp_locked_at else "Not locked"

    @display(description="Locks")
    def locks(self, obj) -> str:
        parts = []
        if obj.pickup_locked_at:
            parts.append("Pickup code locked")
        if obj.otp_locked_at:
            parts.append("OTP locked")
        return ", ".join(parts) or "-"

    @display(description="Ops Console")
    def ops_link(self, obj) -> str:
        return _ops_task_link(obj)


@admin.register(DeliveryOffer)
class DeliveryOfferAdmin(ScopedObjectMixin, ReadOnlyMixin, ModelAdmin):
    list_display = (
        "order_number",
        "store_code",
        "rider_name",
        "status",
        "offered_at",
        "expires_at",
        "responded_at",
        "reject_reason",
    )
    list_filter = ("status", "reject_reason")
    search_fields = ("task__order__order_number",)
    list_select_related = ("task__order", "task__store", "rider")
    ordering = ("-offered_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    fields = (
        "order_number",
        "store_code",
        "rider_name",
        "status",
        "offered_at",
        "expires_at",
        "responded_at",
        "reject_reason",
    )
    readonly_fields = fields

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .filter(task__store__in=stores_for(request.user))
            .defer("task__delivery_otp_encrypted")
            .select_related("task__order", "task__store", "rider")
        )

    @display(description="Order", ordering="task__order__order_number")
    def order_number(self, obj) -> str:
        return obj.task.order.order_number

    @display(description="Store", ordering="task__store__code")
    def store_code(self, obj) -> str:
        return obj.task.store.code

    @display(description="Rider", ordering="rider__full_name")
    def rider_name(self, obj) -> str:
        return obj.rider.full_name


# --------------------------------------------------------------------------- slice 5.4

# SLICE 5.4: cash ledger, earnings, payouts and earning rules (admin_54.py) register only once
# their models are merged into this branch.
from apps.delivery import models as _delivery_models  # noqa: E402

if hasattr(_delivery_models, "Payout"):
    from apps.delivery import admin_54  # noqa: F401
