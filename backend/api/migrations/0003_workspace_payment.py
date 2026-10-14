import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def assign_workspaces(apps, schema_editor):
    Profile = apps.get_model("api", "Profile")
    Subscription = apps.get_model("api", "Subscription")
    Workspace = apps.get_model("api", "Workspace")

    for profile in Profile.objects.select_related("user"):
        full_name = f"{profile.user.first_name} {profile.user.last_name}".strip()
        workspace = Workspace.objects.create(
            name=full_name or profile.user.email or profile.user.username
        )
        profile.workspace = workspace
        profile.save(update_fields=["workspace"])

    for subscription in Subscription.objects.select_related("owner__profile"):
        subscription.workspace = subscription.owner.profile.workspace
        subscription.save(update_fields=["workspace"])


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0002_alter_subscription_category"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Workspace",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("name", models.CharField(max_length=120)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
        ),
        migrations.AddField(
            model_name="profile",
            name="workspace",
            field=models.ForeignKey(null=True, on_delete=django.db.models.deletion.CASCADE, related_name="profiles", to="api.workspace"),
        ),
        migrations.AddField(
            model_name="subscription",
            name="workspace",
            field=models.ForeignKey(null=True, on_delete=django.db.models.deletion.CASCADE, related_name="subscriptions", to="api.workspace"),
        ),
        migrations.RunPython(assign_workspaces, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="profile",
            name="workspace",
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="profiles", to="api.workspace"),
        ),
        migrations.AlterField(
            model_name="subscription",
            name="workspace",
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="subscriptions", to="api.workspace"),
        ),
        migrations.CreateModel(
            name="Payment",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("amount", models.DecimalField(decimal_places=2, max_digits=14)),
                ("due_date", models.DateField()),
                ("paid_at", models.DateTimeField(auto_now_add=True)),
                ("recorded_by", models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="recorded_payments", to=settings.AUTH_USER_MODEL)),
                ("subscription", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="payments", to="api.subscription")),
                ("workspace", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="payments", to="api.workspace")),
            ],
            options={"ordering": ["-paid_at"]},
        ),
    ]
