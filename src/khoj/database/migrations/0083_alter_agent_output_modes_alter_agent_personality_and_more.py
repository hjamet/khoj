# Generated by Django 5.0.10 on 2025-01-24 16:23

import django.contrib.postgres.fields
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("database", "0082_merge_20250121_1842"),
    ]

    operations = [
        migrations.AlterField(
            model_name="agent",
            name="output_modes",
            field=django.contrib.postgres.fields.ArrayField(
                base_field=models.CharField(
                    choices=[("image", "Image"), ("automation", "Automation"), ("diagram", "Diagram")], max_length=200
                ),
                blank=True,
                default=list,
                null=True,
                size=None,
            ),
        ),
        migrations.AlterField(
            model_name="agent",
            name="personality",
            field=models.TextField(blank=True, default=None, null=True),
        ),
        migrations.AlterField(
            model_name="agent",
            name="style_color",
            field=models.CharField(
                choices=[
                    ("blue", "Blue"),
                    ("green", "Green"),
                    ("red", "Red"),
                    ("yellow", "Yellow"),
                    ("orange", "Orange"),
                    ("purple", "Purple"),
                    ("pink", "Pink"),
                    ("teal", "Teal"),
                    ("cyan", "Cyan"),
                    ("lime", "Lime"),
                    ("indigo", "Indigo"),
                    ("fuchsia", "Fuchsia"),
                    ("rose", "Rose"),
                    ("sky", "Sky"),
                    ("amber", "Amber"),
                    ("emerald", "Emerald"),
                ],
                default="orange",
                max_length=200,
            ),
        ),
        migrations.AlterField(
            model_name="processlock",
            name="name",
            field=models.CharField(
                choices=[
                    ("index_content", "Index Content"),
                    ("scheduled_job", "Scheduled Job"),
                    ("schedule_leader", "Schedule Leader"),
                    ("apply_migrations", "Apply Migrations"),
                ],
                max_length=200,
                unique=True,
            ),
        ),
    ]
