from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0005_profile_language_workspace_configured_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='subscription',
            name='due_time',
            field=models.TimeField(blank=True, null=True),
        ),
    ]
