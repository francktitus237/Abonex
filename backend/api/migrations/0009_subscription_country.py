from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0008_workspace_demo_budget"),
    ]

    operations = [
        migrations.AddField(
            model_name="subscription",
            name="country",
            field=models.CharField(blank=True, default="", max_length=2),
        ),
    ]
