from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from . import views

urlpatterns = [
    path("auth/login/", views.LoginView.as_view()),
    path("auth/register/", views.RegisterView.as_view()),
    path("auth/token/refresh/", TokenRefreshView.as_view()),
    path("auth/logout/", views.LogoutView.as_view()),
    path("auth/me/", views.MeView.as_view()),
    path("auth/password/forgot/", views.ForgotPasswordView.as_view()),
    path("auth/password/reset/", views.ResetPasswordView.as_view()),
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
    path("connections/", views.ConnectionListView.as_view()),
    path(
        "connections/<int:pk>/resync/",
        views.ConnectionResyncView.as_view(),
    ),
]
