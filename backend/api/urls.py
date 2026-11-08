from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from . import views

urlpatterns = [
    path("auth/login/", views.LoginView.as_view()),
    path("auth/2fa/setup/", views.TotpSetupView.as_view()),
    path("auth/2fa/enable/", views.TotpEnableView.as_view()),
    path("auth/2fa/disable/", views.TotpDisableView.as_view()),
    path("auth/2fa/verify/", views.TotpVerifyView.as_view()),
    path("auth/register/", views.RegisterView.as_view()),
    path("auth/token/refresh/", TokenRefreshView.as_view()),
    path("auth/logout/", views.LogoutView.as_view()),
    path("auth/me/", views.MeView.as_view()),
    path("auth/password/change/", views.ChangePasswordView.as_view()),
    path("auth/password/forgot/", views.ForgotPasswordView.as_view()),
    path("auth/password/reset/", views.ResetPasswordView.as_view()),
    path("auth/verify/resend/", views.ResendVerifyEmailView.as_view()),
    path(
        "auth/verify/<str:uid>/<str:token>/",
        views.VerifyEmailView.as_view(),
    ),
    path("devices/", views.DeviceTokenView.as_view()),
    path("export/csv/", views.ExportCsvView.as_view()),
    path("export/xlsx/", views.ExportXlsxView.as_view()),
    path("export/pdf/", views.ExportPdfView.as_view()),
    path(
        "subscriptions/<int:pk>/comments/",
        views.CommentListCreateView.as_view(),
    ),
    path(
        "comments/<int:pk>/",
        views.CommentDetailView.as_view(),
    ),
    path(
        "report/monthly/send/",
        views.MonthlyReportEmailView.as_view(),
    ),
    path(
        "payroll-items/",
        views.PayrollItemListCreateView.as_view(),
    ),
    path(
        "payroll-items/<int:pk>/",
        views.PayrollItemDetailView.as_view(),
    ),
    path(
        "employees/<int:pk>/payslip/",
        views.PayslipView.as_view(),
    ),
    path("employees/pay-all/", views.PayAllView.as_view()),
    path(
        "employees/me/payslip/",
        views.MyPayslipView.as_view(),
    ),
    path("suppliers/", views.SupplierListCreateView.as_view()),
    path("webhooks/", views.WebhookListCreateView.as_view()),
    path(
        "webhooks/<int:pk>/",
        views.WebhookDetailView.as_view(),
    ),
    path(
        "suppliers/<int:pk>/",
        views.SupplierDetailView.as_view(),
    ),
    path("insights/", views.InsightsView.as_view()),
    path("employees/", views.EmployeeListCreateView.as_view()),
    path(
        "employees/<int:pk>/",
        views.EmployeeDetailView.as_view(),
    ),
    path("users/", views.UserListView.as_view()),
    path("users/<int:pk>/", views.UserDetailView.as_view()),
    path(
        "subscriptions/", views.SubscriptionListCreateView.as_view()
    ),
    path(
        "subscriptions/<int:pk>/",
        views.SubscriptionDetailView.as_view(),
    ),
    path(
        "subscriptions/<int:pk>/history/",
        views.PaymentHistoryView.as_view(),
    ),
    path("subscriptions/bulk/", views.SubscriptionBulkCreateView.as_view()),
    path("workspace/setup/", views.WorkspaceSetupView.as_view()),
    path("workspace/budget/", views.WorkspaceBudgetView.as_view()),
    path("invites/", views.InviteListCreateView.as_view()),
    path("invites/accept/", views.InviteAcceptView.as_view()),
    path("providers/catalog/", views.ProviderCatalogView.as_view()),
    path("rates/", views.ExchangeRatesView.as_view()),
    path("meta/app-version/", views.AppVersionView.as_view()),
    path("connectors/", views.ConnectorListView.as_view()),
    path(
        "connectors/<str:slug>/sync/",
        views.ConnectorSyncView.as_view(),
    ),
    path(
        "connectors/powens/login/",
        views.PowensLoginView.as_view(),
    ),
    path(
        "connectors/powens/callback/",
        views.PowensCallbackView.as_view(),
    ),
    path(
        "payments/<int:pk>/verdict/",
        views.PaymentApprovalView.as_view(),
    ),
    path("audit/", views.AuditLogView.as_view()),
    path("departments/", views.DepartmentListCreateView.as_view()),
    path(
        "departments/<int:pk>/",
        views.DepartmentDetailView.as_view(),
    ),
    path("budgets/", views.BudgetListCreateView.as_view()),
    path(
        "budgets/<int:pk>/", views.BudgetDetailView.as_view()
    ),
    path("treasury/", views.TreasuryView.as_view()),
    path(
        "attachments/", views.AttachmentListCreateView.as_view()
    ),
    path(
        "attachments/<int:pk>/",
        views.AttachmentDetailView.as_view(),
    ),
    path("memberships/", views.MembershipListView.as_view()),
    path(
        "memberships/<int:pk>/activate/",
        views.MembershipActivateView.as_view(),
    ),
    path("payments/", views.PendingPaymentsView.as_view()),
    path("connections/", views.ConnectionListView.as_view()),
    path(
        "connections/<int:pk>/resync/",
        views.ConnectionResyncView.as_view(),
    ),
]
